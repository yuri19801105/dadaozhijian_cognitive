#!/usr/bin/env python3
# === shifang/llm_sidecar.py ===
# 双后端选择器：在 Qwen3.5-4B-MLX（默认）/ Qwen3-4B / Phi-4-mini-3.8B 之间按配置动态切换，
# 全部本地运行（Ollama / vLLM / llama.cpp 的 OpenAI 兼容端点，MLX 优先）。
#
# 对外契约【保持不变】：经 LLM_PROMPT / LLM_REQ_FILE / 命令行参数 收 prompt，stdout 返回文本。
#   因此 Mojo 侧（sidecar.mojo / protocol.mojo）零改动——本文件是框架看到的唯一统一接口。
#
# 新增能力：
#   - 配置驱动后端切换：default_backend + failover_order + 环境变量 SIDECAR_BACKEND 强制指定。
#   - 自动健康检查：探测 {base_url}/models，结果缓存到本地 health cache 文件（跨子进程调用有效）。
#   - 故障转移：默认/强制后端不可达时，按 failover_order 依次尝试，全失败则确定性降级。
#   - 全量调用记录：ledger JSONL（含 call_id），每条输出可溯源到 ledger 记录，供阶段 B 蒸馏。
#
# 用法：
#   python3 shifang/llm_sidecar.py "phase=2 plan=[木→火] 请解释调度依据"
#   SIDECAR_BACKEND=phi-4-mini python3 shifang/llm_sidecar.py "..."   # 强制指定后端
# 兼容旧云 API（环境变量覆盖优先，单后端）：
#   LLM_API_KEY=sk-xxx LLM_BASE_URL=https://api.openai.com/v1 LLM_MODEL=gpt-4o-mini python3 ...
#
# 设计说明（Mojo 1.0.0b2 约束）：本构建无原生 HTTP，故"真实侧车"以独立 python3 子进程承接；
#   侧车用 Python 标准库（urllib）实现，零额外依赖，可直接对接本地或云端 OpenAI 兼容端点。

import os
import sys
import re
import json
import time
import uuid
import datetime
import urllib.request
import urllib.error

# ---------- 路径与配置 ----------
DEFAULT_CONFIG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sidecar_config.json")


def _cfg_path():
    # type: () -> str
    return os.environ.get("SIDECAR_CONFIG", DEFAULT_CONFIG)


def _load_config():
    # type: () -> dict
    p = _cfg_path()
    try:
        with open(p, "r", encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        # 缺配置 → 退化为"无后端"语义（仍返回非空降级文本，保证上层 ok=1）。
        return {"backends": [], "default_backend": None, "failover_order": []}


# ---------- 后端解析 ----------
def _legacy_backend_from_env():
    # type: () -> dict or None
    base = os.environ.get("LLM_BASE_URL")
    if not base:
        return None
    return {
        "name": "legacy-env",
        "type": "openai",
        "base_url": base.rstrip("/"),
        "model": os.environ.get("LLM_MODEL", "gpt-4o-mini"),
        "api_key": os.environ.get("LLM_API_KEY", ""),
        "temperature": float(os.environ.get("LLM_TEMP", "0.3")),
        "max_tokens": int(os.environ.get("LLM_MAX_TOKENS", "512")),
        "system_prompt": os.environ.get(
            "LLM_SYSTEM", "你是大道至简认知架构的执行侧车，用简体中文回答。"),
        "reasoning": False,
    }


def _resolve_backends(cfg):
    # type: (dict) -> list
    legacy = _legacy_backend_from_env()
    if legacy:
        return [legacy]
    backends = {}
    for b in cfg.get("backends", []):
        backends[b["name"]] = b
    order = []  # type: list
    default = cfg.get("default_backend")
    if default and default in backends:
        order.append(default)
    for n in cfg.get("failover_order", []):
        if n in backends and n not in order:
            order.append(n)
    for n in backends:  # 兜底：未列入 order 的后端加在末尾
        if n not in order:
            order.append(n)
    return [backends[n] for n in order]


# ---------- 健康检查缓存（跨子进程持久化） ----------
def _health_cache_path(cfg):
    # type: (dict) -> str
    p = cfg.get("health_cache_path")
    if p:
        return p
    return os.path.join(
        os.path.dirname(os.path.abspath(_cfg_path())), "ledger", ".health_cache.json")


def _read_health(cache_path):
    # type: (str) -> dict
    try:
        with open(cache_path, "r", encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def _write_health(cache_path, data):
    # type: (str, dict) -> None
    try:
        d = os.path.dirname(cache_path)
        if d:
            os.makedirs(d, exist_ok=True)
        with open(cache_path, "w", encoding="utf-8") as f:
            json.dump(data, f)
    except OSError:
        pass


def _is_cached_healthy(cache, name, ttl):
    # type: (dict, str, float) -> bool
    e = cache.get(name)
    if not isinstance(e, (int, float)):
        return False
    if e <= 0:
        return False
    return (time.time() - e) < ttl


def _mark_health(cache, name, ok, cache_path):
    # type: (dict, str, bool, str) -> None
    cache[name] = time.time() if ok else 0
    _write_health(cache_path, cache)


# ---------- 后端探测与调用（OpenAI 兼容 / Ollama 原生 双接口） ----------
def _models_url(b):
    # type: (dict) -> str
    iface = b.get("interface", "openai")
    base = b["base_url"].rstrip("/")
    if iface == "ollama":
        if base.endswith("/v1"):
            base = base[: -len("/v1")]
        return base + "/api/tags"
    return base + "/models"


def _health_probe(b, timeout):
    # type: (dict, float) -> bool
    url = _models_url(b)
    req = urllib.request.Request(
        url, method="GET",
        headers={"Authorization": "Bearer " + str(b.get("api_key", ""))})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status == 200
    except Exception:
        return False


def _call_backend(b, prompt, timeout):
    # type: (dict, str, float) -> tuple
    iface = b.get("interface", "openai")
    base = b["base_url"].rstrip("/")
    think = bool(b.get("reasoning", False))  # 渲染器默认关思考；reasoning=true 才开
    sys_p = b.get("system_prompt",
                   "你是大道至简认知架构的执行侧车，用简体中文回答。")
    if iface == "ollama":
        # Ollama 原生 /api/chat：对思考模型（如 qwen3.5:4b-mlx）think:false 才真正关思考
        if base.endswith("/v1"):
            base = base[: -len("/v1")]
        url = base + "/api/chat"
        payload = {
            "model": b["model"],
            "messages": [
                {"role": "system", "content": sys_p},
                {"role": "user", "content": prompt},
            ],
            "options": {
                "temperature": b.get("temperature", 0.3),
                "num_predict": b.get("max_tokens", 512),
            },
            "think": think,
            "stream": False,
        }
    else:
        url = base + "/chat/completions"
        payload = {
            "model": b["model"],
            "messages": [
                {"role": "system", "content": sys_p},
                {"role": "user", "content": prompt},
            ],
            "temperature": b.get("temperature", 0.3),
            "max_tokens": b.get("max_tokens", 512),
            "stream": False,
            "think": think,
        }
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url, data=data, method="POST",
        headers={
            "Content-Type": "application/json",
            "Authorization": "Bearer " + str(b.get("api_key", "")),
        })
    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = json.loads(resp.read().decode("utf-8"))
            if iface == "ollama":
                text = body.get("message", {}).get("content", "").strip()
                # Ollama 原生接口把 token 计数放在顶层
                pt = body.get("prompt_eval_count")
                ct = body.get("eval_count")
            else:
                text = body["choices"][0]["message"]["content"].strip()
                usage = body.get("usage", {}) or {}
                pt = usage.get("prompt_tokens")
                ct = usage.get("completion_tokens")
            return (text, True, int((time.time() - t0) * 1000), pt, ct)
    except urllib.error.URLError as e:
        return ("[sidecar] 后端 %s 调用失败: %s" % (b["name"], e), False,
                int((time.time() - t0) * 1000), None, None)
    except Exception as e:  # 解析/其它异常 → 标记失败，触发故障转移
        return ("[sidecar] 后端 %s 响应解析失败: %s" % (b["name"], e), False,
                int((time.time() - t0) * 1000), None, None)


# ---------- 自蒸馏后端（彻底脱离外部 LLM 端点） ----------
def _call_distilled(b, prompt, timeout):
    # type: (dict, str, float) -> tuple
    """本地自蒸馏模型后端：经 backend_shim 离线渲染符号计划，零出站 HTTP。

    复用现有 Mojo→python 子进程桥（shifang_llm_call），不依赖 Ollama/vLLM/llama.cpp
    等任何外部 LLM 端点。model_path 相对项目根目录解析（绝对路径则直接用）。
    """
    m = re.search(r"plan\s*=\s*\[([^\]]*)\]", prompt)
    plan = m.group(1).strip() if m else ""
    mp = b.get("model_path")
    t0 = time.time()
    out = ""
    try:
        import os as _os
        import sys as _sys
        # 定位 stage_b：以本脚本所在目录（shifang/）为基准，上一级即项目根，
        # 不依赖配置文件位置（配置文件可能位于临时目录）。
        proj = _os.path.normpath(
            _os.path.join(_os.path.dirname(_os.path.abspath(__file__)), ".."))
        _sb = _os.path.normpath(_os.path.join(proj, "stage_b"))
        if _sb not in _sys.path:
            _sys.path.insert(0, _sb)
        if mp:
            if not _os.path.isabs(mp):
                mp = _os.path.normpath(_os.path.join(proj, mp))
            from distilled_model import RetrievalDistiller
            out = RetrievalDistiller.load(mp).generate(plan) if plan else ""
        else:
            from config import load_config
            from backend_shim import generate as _shim_generate
            out = _shim_generate(load_config(), plan) if plan else ""
    except Exception as e:  # 加载/生成异常 -> 标记失败，触发降级/故障转移
        return ("[sidecar] distilled 后端调用失败: %s" % e, False,
                int((time.time() - t0) * 1000), None, None)
    if not out:
        # 非计划指令（如 greeting）：返回确定性离线应答，保证非空、ok=1
        out = "[自蒸馏侧车·离线] 已接收指令：" + prompt[:80]
    return (out, True, int((time.time() - t0) * 1000), None, None)


# ---------- 自蒸馏神经网络后端（自有模型「大道至简0.5b」） ----------
def _call_neural(b, prompt, timeout):
    # type: (dict, str, float) -> tuple
    """本地自蒸馏神经网络后端：加载「大道至简0.5b」自包含模型离线渲染符号计划。

    与 distilled 后端同属"零出站 HTTP"本地后端；区别是这里用真实神经网络
    （Qwen2.5-0.5B + LoRA 合并）生成，而非检索插值。需要 torch 训练栈；
    若不可用（或加载/生成失败）则标记失败，触发故障转移，绝不影响上层 ok。
    模型加载以本脚本所在目录（shifang/）为基准解析 stage_b（同 _call_distilled
    的 __file__ 基准约定，避免临时配置目录导致导入失败）。
    """
    m = re.search(r"plan\s*=\s*\[([^\]]*)\]", prompt)
    plan = m.group(1).strip() if m else ""
    mp = b.get("model_path")
    t0 = time.time()
    if not plan:
        # 非计划指令（如 greeting）：返回确定性离线应答，保证非空、ok=1
        out = "[自蒸馏侧车·离线] 已接收指令：" + prompt[:80]
        return (out, True, int((time.time() - t0) * 1000), None, None)
    try:
        import os as _os
        import sys as _sys
        proj = _os.path.normpath(
            _os.path.join(_os.path.dirname(_os.path.abspath(__file__)), ".."))
        _sb = _os.path.normpath(_os.path.join(proj, "stage_b"))
        if _sb not in _sys.path:
            _sys.path.insert(0, _sb)
        if mp and not _os.path.isabs(mp):
            mp = _os.path.normpath(_os.path.join(proj, mp))
        from dadaozhijian_model import DadaozhijianModel
        model = DadaozhijianModel(model_dir=mp or _os.path.join(_sb, "dadaozhijian_0.5b"))
        out = model.generate(plan)
    except Exception as e:  # 加载/生成异常 -> 标记失败，触发降级/故障转移
        return ("[sidecar] neural 后端调用失败: %s" % e, False,
                int((time.time() - t0) * 1000), None, None)
    if not out:
        out = "[自蒸馏侧车·离线] 已接收指令：" + prompt[:80]
    return (out, True, int((time.time() - t0) * 1000), None, None)


# ---------- 选择 + 故障转移 ----------
def _select_and_call(backends, cfg, prompt, force):
    # type: (list, dict, str, str or None) -> tuple
    cache_path = _health_cache_path(cfg)
    cache = _read_health(cache_path)
    hc = cfg.get("health_check", {})
    ttl = float(hc.get("cache_ttl_sec", 30))
    probe_timeout = float(hc.get("timeout_sec", 3.0))
    # 生成调用超时与健康探测超时分离：首次加载大模型可能需数十秒
    call_timeout = float(cfg.get("call_timeout_sec", 120.0))

    if force:
        cands = [b for b in backends if b["name"] == force] or backends
    else:
        cands = backends

    def _rank(b):
        return 0 if _is_cached_healthy(cache, b["name"], ttl) else 1
    ordered = sorted(cands, key=_rank)

    tried = []  # type: list
    for b in ordered:
        if b.get("type") == "distilled":
            # 自蒸馏后端：本地离线渲染，无健康探测、无出站 HTTP
            text, ok, lat, pt, ct = _call_distilled(b, prompt, call_timeout)
            if ok:
                return (text, b, ok, lat, pt, ct, tried + [b["name"]])
            tried.append(b["name"] + ":distilled_failed")
            continue
        if b.get("type") == "neural":
            # 自蒸馏神经网络后端：本地离线渲染（自有模型），无健康探测、无出站 HTTP
            text, ok, lat, pt, ct = _call_neural(b, prompt, call_timeout)
            if ok:
                return (text, b, ok, lat, pt, ct, tried + [b["name"]])
            tried.append(b["name"] + ":neural_failed")
            continue
        if not _is_cached_healthy(cache, b["name"], ttl):
            healthy = _health_probe(b, probe_timeout)
            _mark_health(cache, b["name"], healthy, cache_path)
            if not healthy:
                tried.append(b["name"] + ":unhealthy")
                continue
        text, ok, lat, pt, ct = _call_backend(b, prompt, call_timeout)
        if ok:
            return (text, b, ok, lat, pt, ct, tried + [b["name"]])
        _mark_health(cache, b["name"], False, cache_path)
        tried.append(b["name"] + ":call_failed")
    return (None, None, False, 0, None, None, tried)


# ---------- ledger 记录（阶段 B 蒸馏数据源） ----------
def _ledger_path(cfg):
    # type: (dict) -> str
    p = cfg.get("ledger_path")
    if p:
        return p
    return os.path.join(
        os.path.dirname(os.path.abspath(_cfg_path())), "ledger", "sidecar_calls.jsonl")


def _log_call(cfg, rec):
    # type: (dict, dict) -> None
    p = _ledger_path(cfg)
    try:
        d = os.path.dirname(p)
        if d:
            os.makedirs(d, exist_ok=True)
        with open(p, "a", encoding="utf-8") as f:
            f.write(json.dumps(rec, ensure_ascii=False) + "\n")
    except OSError:
        pass  # 日志失败不影响主响应（best-effort，亦写 stderr 供排查）


def _degrade(prompt):
    # type: (str) -> str
    return ("[sidecar] 无可用本地 LLM 后端（已排查默认与故障转移后端均不可达），"
            "返回确定性降级提示。请确认 Ollama/vLLM/llama.cpp 已启动并加载对应模型。"
            " 原始 prompt: " + prompt[:120])


def _read_prompt():
    # type: () -> str
    req_file = os.environ.get("LLM_REQ_FILE")
    if req_file:
        try:
            with open(req_file, "r", encoding="utf-8") as f:
                return f.read()
        except OSError:
            return "（读取请求文件失败）"
    if os.environ.get("LLM_PROMPT") is not None:
        return os.environ.get("LLM_PROMPT")
    return " ".join(sys.argv[1:]) if len(sys.argv) > 1 else "（空 prompt）"


def main():
    # type: () -> int
    cfg = _load_config()
    backends = _resolve_backends(cfg)
    prompt = _read_prompt()
    force = os.environ.get("SIDECAR_BACKEND")
    call_id = uuid.uuid4().hex

    if not backends:
        out = _degrade(prompt)
        sel = "none"
        btype = "none"
        model = "none"
        ok = True
        lat = 0
        pt = ct = None
        tried = ["no-backends"]
    else:
        out, b, ok_flag, lat, pt, ct, tried = _select_and_call(backends, cfg, prompt, force)
        if out is None:
            out = _degrade(prompt)
            sel = "none"
            btype = "none"
            model = "none"
            ok = False
        else:
            sel = b["name"]
            btype = b.get("type", "openai")
            model = b.get("model", "")
            ok = ok_flag

    # stdout 即框架读取的接口（契约不变）
    print(out, end="")

    # 全量记录（即便降级也记录，保证阶段 B 数据完整 + 可溯源）
    rec = {
        "call_id": call_id,
        "ts": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "backend": sel,
        "backend_type": btype,
        "model": model,
        "forced": bool(force),
        "reasoning": (b.get("reasoning", False) if b else False),
        "prompt": prompt,
        "response": out,
        "ok": 1 if ok else 0,
        "degraded": 0 if ok else 1,
        "latency_ms": lat,
        "prompt_tokens": pt,
        "completion_tokens": ct,
        "failover_path": tried,
    }
    _log_call(cfg, rec)
    return 0


if __name__ == "__main__":
    sys.exit(main())
