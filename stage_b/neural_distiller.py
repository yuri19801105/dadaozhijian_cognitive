"""NeuralDistiller：真实神经网络蒸馏分支（组合蒸馏 → 自有小模型）。

设计（对照 docs/p4_neural_distillation_design.md + 本机约束）：
  - Teacher：本机 Ollama 的 phi4-mini:3.8b 与 qwen3.5:4b-mlx（黑盒 API，仅训练期）。
  - 符号骨架 + 忠实闸门：用 RetrievalDistiller 的计划符号对 teacher 回答做覆盖过滤，
    覆盖不足的计划符号 → 丢弃/降权，保证学生学到忠实计划。
  - 范式：Orca 式序列级 + 推理链蒸馏（SeqKD + rationale）。因 Ollama 黑盒无法做
    logit/隐层白盒蒸馏（MiniLLM Reverse-KL / TinyBERT 隐层对齐本机不可行，记 P5）。
  - Student：Qwen/Qwen2.5-0.5B（base，0.5B，中文强；Qwen2.5-0.5B-Instruct 为 gated 需登录，故用 open 的 base 变体，LoRA 经蒸馏数据学会指令格式；≤1B，16-bit LoRA，MPS 可跑）。
  - 框架：transformers + PEFT(LoRA) + Trainer（MPS 后端）。TRL 为可选增强。
  - 可插拔：torch 缺失时优雅回退（明确报错），绝不破坏 pure-stdlib 离线闭环。

所有 torch / transformers / peft 导入均惰性，保证模块在无训练栈时仍可 import。
"""
from __future__ import annotations

import json
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from config import StageBConfig
from utils import get_logger, ensure_dir, write_jsonl, read_jsonl
from faithfulness_eval import _plan_symbols


TEACHER_MODELS = ["phi4-mini:3.8b", "qwen3.5:4b-mlx"]
DEFAULT_STUDENT = "Qwen/Qwen2.5-0.5B"
_OLLAMA_URL = "http://localhost:11434"
_SYS_PROMPT = "你是大道至简认知架构的执行侧车，用简体中文回答。"


# --------------------------------------------------------------------------
# 1) 黑盒 teacher 调用（urllib，零额外依赖，复用项目既有 Ollama 桥约定）
# --------------------------------------------------------------------------
def call_teacher(
    model: str,
    prompt: str,
    base_url: str = _OLLAMA_URL,
    temperature: float = 0.3,
    max_tokens: int = 512,
    timeout: float = 90.0,
) -> Tuple[str, bool]:
    """调用本机 Ollama 黑盒 teacher，返回 (文本, 是否成功)。

    Args:
        model: Ollama 模型名（如 'phi4-mini:3.8b'）。
        prompt: 用户指令。
        base_url: Ollama 服务地址（默认本机 11434）。
        temperature / max_tokens / timeout: 生成参数。
    Returns:
        (文本, ok)。失败时返回 ("", False)。
    """
    url = base_url.rstrip("/") + "/api/chat"
    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": _SYS_PROMPT},
            {"role": "user", "content": prompt},
        ],
        "options": {"temperature": temperature, "num_predict": max_tokens},
        "think": False,  # 关思考（qwen3.5:4b-mlx 等思考模型需显式关闭）
        "stream": False,
    }
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url, data=data, method="POST",
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = json.loads(resp.read().decode("utf-8"))
            text = body.get("message", {}).get("content", "").strip()
            return (text, bool(text))
    except urllib.error.URLError as e:
        return ("[neural_distiller] teacher %s 调用失败: %s" % (model, e), False)
    except Exception as e:  # 解析/其它异常
        return ("[neural_distiller] teacher %s 响应解析失败: %s" % (model, e), False)


def build_instruction(plan: str) -> str:
    """为给定符号计划构造 teacher 指令（含推理链要求）。"""
    return (
        "你是大道至简认知架构的执行侧车。给定符号化调度计划 "
        "plan=[%s]，请先进行符号推演（reasoning），再给出简体中文执行解读"
        "（response）。" % plan
    )


def symbol_coverage(plan: str, text: str) -> float:
    """计算 text 对 plan 符号的覆盖率（0~1），作为忠实闸门指标。"""
    syms = _plan_symbols(plan)
    if not syms:
        return 1.0
    return sum(1 for s in syms if s in text) / len(syms)


# --------------------------------------------------------------------------
# 2) 蒸馏数据集生成（双 teacher + 忠实闸门 + 组合择优）
# --------------------------------------------------------------------------
def generate_distillation_data(
    plans: List[str],
    out_path: str,
    teachers: Optional[List[str]] = None,
    gate: float = 1.0,
    base_url: str = _OLLAMA_URL,
    temperature: float = 0.3,
    max_tokens: int = 512,
    timeout: float = 90.0,
) -> Dict[str, Any]:
    """用双 teacher 生成蒸馏数据集，经忠实闸门筛选后落 JSONL。

    对每个 plan：两 teacher 各生成一次，取"覆盖 >= gate 且覆盖率最高"的回答
    （组合蒸馏：择优组队，而非简单拼接），写入
    {"plan", "instruction", "response", "teacher", "coverage"}。

    Args:
        plans: 符号计划列表。
        out_path: 输出 JSONL 路径。
        teachers: teacher 模型名列表（默认 TEACHER_MODELS）。
        gate: 覆盖率门槛（默认 1.0，即必须包含全部计划符号）。
        base_url / temperature / max_tokens / timeout: 生成参数。
    Returns:
        统计字典 {n_total, n_kept, dropped, per_teacher}。
    """
    log = get_logger("stage_b.neural_distiller")
    teachers = teachers or list(TEACHER_MODELS)
    out: List[Dict[str, Any]] = []
    stats = {
        "n_total": len(plans),
        "n_kept": 0,
        "dropped": 0,
        "per_teacher": {t: 0 for t in teachers},
    }
    for plan in plans:
        plan = (plan or "").strip()
        if not plan:
            continue
        instr = build_instruction(plan)
        best_text: Optional[str] = None
        best_cov = -1.0
        best_key = (-1.0, 0)  # (coverage, 回答长度) 组合择优：并列取更详尽者
        best_teacher: Optional[str] = None
        for t in teachers:
            text, ok = call_teacher(t, instr, base_url, temperature, max_tokens, timeout)
            if not ok or not text.strip():
                continue
            cov = symbol_coverage(plan, text)
            stats["per_teacher"][t] += 1
            key = (cov, len(text))
            if cov >= gate and key > best_key:
                best_cov = cov
                best_key = key
                best_text = text
                best_teacher = t
        if best_text is not None:
            out.append({
                "plan": plan,
                "instruction": instr,
                "response": best_text,
                "teacher": best_teacher,
                "coverage": round(best_cov, 3),
            })
            stats["n_kept"] += 1
        else:
            stats["dropped"] += 1
            log.warning("plan=[%s] 两 teacher 均未达忠实闸门(gate=%.2f)，丢弃", plan, gate)
    write_jsonl(out_path, out)
    log.info("蒸馏数据集已写出: %s (保留 %d / 丢弃 %d)", out_path, stats["n_kept"], stats["dropped"])
    return stats


# --------------------------------------------------------------------------
# 3) NeuralDistiller：训练 / 推理 / 评估（惰性 torch）
# --------------------------------------------------------------------------
class NeuralDistiller:
    """真实神经网络蒸馏器（组合蒸馏 → 自有小模型）。

    接口与 RetrievalDistiller 对齐（train / generate / save / load / evaluate），
    真实训练依赖 transformers/peft 训练栈；torch 缺失时给出明确安装提示。
    """

    def __init__(
        self,
        base_model: str = DEFAULT_STUDENT,
        method: str = "lora",
        lora_rank: int = 16,
        max_epochs: int = 3,
        learning_rate: float = 2.0e-4,
        max_seq_length: int = 512,
        adapter_path: Optional[str] = None,
    ) -> None:
        self.base_model = base_model
        self.method = method
        self.lora_rank = lora_rank
        self.max_epochs = max_epochs
        self.learning_rate = learning_rate
        self.max_seq_length = max_seq_length
        self.adapter_path: Optional[str] = adapter_path

    # ---- 惰性训练栈 ----------------------------------------------------
    @staticmethod
    def _ensure_torch():
        """惰性导入 torch / transformers / peft；缺失则给出清晰报错。"""
        try:
            import torch  # noqa: F401
            import transformers  # noqa: F401
            import peft  # noqa: F401
        except ImportError as e:
            raise RuntimeError(
                "真实神经网络蒸馏需 transformers/peft 训练栈。请先安装：\n"
                "  pip install torch transformers peft\n"
                "（本机 MPS 用原生 PyTorch，无需 CUDA-only 的 unsloth/bitsandbytes）\n"
                "原始错误: %s" % e
            )
        import torch
        import transformers
        import peft
        return torch, transformers, peft

    # ---- 格式化 --------------------------------------------------------
    @staticmethod
    def _format_text(instruction: str, response: str, tok) -> str:
        """用基座 chat 模板拼装 (instruction, response) 训练样本。"""
        msgs = [
            {"role": "system", "content": _SYS_PROMPT},
            {"role": "user", "content": instruction},
            {"role": "assistant", "content": response},
        ]
        return tok.apply_chat_template(msgs, tokenize=False)

    # ---- 训练 ----------------------------------------------------------
    def train(self, dataset_path: str, output_dir: str) -> Path:
        """对蒸馏数据集做 LoRA SFT（MPS / 16-bit），返回 adapter 目录。

        Args:
            dataset_path: generate_distillation_data 产出的 JSONL。
            output_dir: adapter 输出目录。
        Returns:
            adapter 目录 Path。
        """
        log = get_logger("stage_b.NeuralDistiller")
        torch, transformers, peft = self._ensure_torch()
        from peft import LoraConfig, get_peft_model
        from transformers import (AutoModelForCausalLM, AutoTokenizer,
                                  Trainer, TrainingArguments,
                                  DataCollatorForLanguageModeling)

        tok = AutoTokenizer.from_pretrained(self.base_model)
        if tok.pad_token is None:
            tok.pad_token = tok.eos_token

        model = AutoModelForCausalLM.from_pretrained(
            self.base_model, torch_dtype=torch.float16
        )
        lora_cfg = LoraConfig(
            r=self.lora_rank,
            lora_alpha=self.lora_rank,
            target_modules=["q_proj", "k_proj", "v_proj", "o_proj",
                            "gate_proj", "up_proj", "down_proj"],
            lora_dropout=0.05,
            bias="none",
            task_type="CAUSAL_LM",
        )
        model = get_peft_model(model, lora_cfg)
        model.print_trainable_parameters()

        records = read_jsonl(dataset_path)
        texts = [self._format_text(r["instruction"], r["response"], tok) for r in records]
        enc = tok(
            texts, truncation=True, max_length=self.max_seq_length,
            padding="max_length",
        )
        input_ids = enc["input_ids"]
        attn = enc["attention_mask"]

        class _DS(torch.utils.data.Dataset):
            def __len__(self):
                return len(input_ids)

            def __getitem__(self, i):
                return {
                    "input_ids": torch.tensor(input_ids[i]),
                    "attention_mask": torch.tensor(attn[i]),
                    "labels": torch.tensor(input_ids[i]),
                }

        collator = DataCollatorForLanguageModeling(tok, mlm=False)
        args = TrainingArguments(
            output_dir=output_dir,
            per_device_train_batch_size=1,
            gradient_accumulation_steps=4,
            num_train_epochs=self.max_epochs,
            learning_rate=self.learning_rate,
            logging_steps=1,
            save_strategy="no",
            report_to="none",
            optim="adamw_torch",
            fp16=False,
            bf16=False,
            disable_tqdm=False,
        )
        trainer = Trainer(
            model=model, args=args, train_dataset=_DS(), data_collator=collator
        )
        log.info("开始 LoRA SFT: base=%s rank=%d epochs=%d lr=%.1e 样本=%d",
                 self.base_model, self.lora_rank, self.max_epochs, self.learning_rate, len(records))
        model = model.to("mps")
        trainer.train()
        out = ensure_dir(output_dir) / "adapter"
        model.save_pretrained(str(out))
        tok.save_pretrained(str(out))
        self.adapter_path = str(out)
        log.info("LoRA adapter 已落盘: %s", out)
        return out

    # ---- 推理 ----------------------------------------------------------
    def generate(self, plan: str, max_new_tokens: int = 256) -> str:
        """用 基座+adapter 对符号计划离线渲染（MPS）。"""
        if not self.adapter_path:
            raise RuntimeError("NeuralDistiller 未加载 adapter，无法 generate；请先 train 或 load。")
        torch, transformers, peft = self._ensure_torch()
        from transformers import AutoModelForCausalLM, AutoTokenizer
        from peft import PeftModel

        base = AutoModelForCausalLM.from_pretrained(
            self.base_model, torch_dtype=torch.float16
        ).to("mps")
        model = PeftModel.from_pretrained(base, self.adapter_path).to("mps")
        tok = AutoTokenizer.from_pretrained(self.base_model)
        prompt = self._format_text(build_instruction(plan), "", tok)
        inputs = tok(prompt, return_tensors="pt").to("mps")
        out = model.generate(
            **inputs, max_new_tokens=max_new_tokens, do_sample=False, temperature=1.0
        )
        return tok.decode(out[0][inputs["input_ids"].shape[1]:], skip_special_tokens=True)

    # ---- 持久化 --------------------------------------------------------
    def save(self, path: str) -> None:
        """固化 NeuralDistiller 元数据（adapter 已由其 train 落盘）。"""
        data = {
            "type": "NeuralDistiller",
            "base_model": self.base_model,
            "method": self.method,
            "lora_rank": self.lora_rank,
            "adapter_path": self.adapter_path,
        }
        from utils import write_text
        write_text(path, json.dumps(data, ensure_ascii=False, indent=2))

    @classmethod
    def load(cls, path: str) -> "NeuralDistiller":
        """从元数据还原 NeuralDistiller（含 adapter_path）。"""
        raw = Path(path).read_text(encoding="utf-8")
        d = json.loads(raw)
        return cls(
            base_model=d.get("base_model", DEFAULT_STUDENT),
            method=d.get("method", "lora"),
            lora_rank=d.get("lora_rank", 16),
            adapter_path=d.get("adapter_path"),
        )

    # ---- 评估（复用 faithfulness_eval 的计划符号覆盖）-----------------
    def evaluate(self, eval_pairs: List[Dict[str, str]]) -> Dict[str, float]:
        """用本模型生成输出评估对符号计划的忠实度。"""
        total = 0.0
        covered = 0
        for p in eval_pairs:
            plan = p.get("plan", "")
            out = self.generate(plan)
            syms = _plan_symbols(plan)
            if not syms:
                total += 1.0
                covered += 1
                continue
            hit = sum(1 for s in syms if s in out)
            total += hit / len(syms)
            if out.strip() and hit > 0:
                covered += 1
        n = float(len(eval_pairs)) or 1.0
        return {"faithfulness": total / n, "coverage": covered / n, "n": n}
