# 运维手册（Operations Runbook）— dadaozhijian_cognitive

> 对应 `architecture-modular-plan.md` §6 横切关注点 与 §7 Phase 6（生产硬化）。
> 本文给出**可立即落地、不依赖外部基建**的部分；需你提供环境的项单列于文末「阻塞项」。

## 0. 核心原则（调研结论）

1. **部署单元 = 编译后的静态二进制**，不是源码、也不是必须容器。
   `mojo build -I . -I core <ENTRY>.mojo -o bin/dadaozhijian` 在 Mojo 1.0.0b2 默认产出静态链接二进制。
2. **容器化是可选分支，不是默认**。仅在「多服务编排 / 水平扩展 / k8s」才用 `deploy/Dockerfile`；
   单服务长驻用 `deploy/systemd/` 或 `deploy/supervisord.conf` 更轻。
3. **可观测性解耦**：Mojo 无原生 HTTP 服务，指标走 **文本文件 + node_exporter textfile** 模式
   （`ops/metrics_exporter.mojo`），日志走结构化 `observability/logging` → journald/stdout，溯源走
   `observability/store` 的 JSON-Lines ledger（跨进程串联回灌↔溯源）。

## 1. 构建（一次性）

```bash
# 选定入口（当前可用：observability/store_demo.mojo 跑通回灌+ledger 全链路）
ENTRY=observability/store_demo.mojo
mojo build -I . -I core "$ENTRY" -o /usr/local/bin/dadaozhijian
```

## 2. 部署方式（三选一，按场景）

### A. 裸机/VM 单服务（推荐，最轻）— systemd
```bash
sudo cp deploy/systemd/dadaozhijian.service /etc/systemd/system/
sudo mkdir -p /etc/dadaozhijian && sudo cp config/defaults.toml /etc/dadaozhijian/
sudo systemctl daemon-reload && sudo systemctl enable --now dadaozhijian
journalctl -u dadaozhijian -f        # 看结构化日志
```

### B. 容器/边缘（PID 1 = supervisord）
```bash
supervisord -c deploy/supervisord.conf
supervisorctl -c deploy/supervisord.conf status
```

### C. 多服务编排 / k8s — Docker 多阶段
```bash
docker build -t dadaozhijian:latest \
  --build-arg ENTRY=observability/store_demo.mojo .
docker run -d --name dadaozhijian -v $(pwd)/data:/data dadaozhijian:latest
# 镜像体积：朴素 modular 全量 ~4GB → 多阶段后 ~300–500MB
```

## 3. 配置外置（运行期免重编译）

所有阈值/策略入 `config/defaults.toml`；改配置无需重编译，重启进程即生效。
通过环境变量 `CONFIG_PATH` 指路径（systemd/supervisord 已设）。

## 4. 健康检查

`ops/healthcheck.sh` 以**退出码**表达健康（0 健康 / 1 进程不在或指标陈旧 / 2 侧车依赖缺失），
已接入 Dockerfile `HEALTHCHECK`。裸机可配 cron 或外部探针周期调用。

## 5. 指标采集（免 HTTP）

```bash
# 周期导出文本指标（node_exporter textfile 兼容，已接入真实 observability.Metrics）
mojo run -I . -I core ops/metrics_exporter.mojo \
  /var/lib/node_exporter/dadaozhijian.prom <throughput> <ok> <degraded> <sample_latency_ms>

# 也可在运行服务主循环内直接调用 metrics.to_prometheus() 写同一路径（免 CLI 中转）。
# node_exporter 启动加 --collector.textfile.directory=/var/lib/node_exporter
# Prometheus 抓取 node_exporter 即可获得 dadaozhijian_* 系列指标
#   counter: request_total / ok_total / degraded_total
#   gauge:   latency_p50_ms / latency_p95_ms / robustness_degradation_ratio / five_element_variance
```
> 已落地（v1.7）：`metrics_exporter.mojo` 直接复用 `observability.Metrics.to_prometheus()`，导出 3 counter + 4 gauge（含五行均衡方差，未置均衡度时自动省略）。

## 6. 回滚

生克表 / 调度策略 / 配置均版本化（`config/defaults.toml` + git 历史）。回滚 = 切回旧 `defaults.toml`
或旧二进制后重启；策略回归可一键复跑对应模块测试套件验证。

## 7. 故障排查

| 现象 | 可能原因 | 处置 |
|---|---|---|
| 进程反复重启 | 内存超 `MemoryMax` / 启动即崩 | `journalctl -u dadaozhijian` 看栈；降负载或放宽护栏 |
| 侧车无回复 | `LLM_API_KEY` 缺失→降级（预期）；或 python3 不在 PATH | 查 healthcheck 退出码 2；确认 python3 |
| 指标陈旧 | 导出任务未跑 / textfile 目录权限 | 跑 healthcheck 看指标新鲜度；检查 `/var/lib/node_exporter` 可写 |
| 回灌被门控熔断 | `backfill_success_rate` < 50% 触发 | 查 `runtime` 健康度；必要时放宽 `defaults.toml` 阈值 |

## 8. 阻塞项（需你提供环境，非「不可能」）

- **k8s / 容器编排集群**：需集群与镜像仓库，才能跑 C 方案。
- **Prometheus + Grafana 栈**：需部署采集/存储/看板，指标才有可视化告警。
- **CI/CD Docker runner**：需在 CI 中跑 `docker build`，当前仓库无 CI 配置。
- **真实 LLM 网关凭证**：`LLM_API_KEY` 由你提供，缺失时侧车确定性降级（不影响主体）。

> 以上均属「环境供给」问题，不在代码会话闭环范围；脚手架已就位，环境就绪即可启用。
