#!/bin/bash
# ops/healthcheck.sh — Kubernetes liveness/readiness 探针入口
# 用法：healthcheck.sh [--ready]
#   无参数   → liveness（进程存活）
#   --ready  → readiness（可服务）

set -euo pipefail

READY_MODE=false
if [[ "${1:-}" == "--ready" ]]; then
  READY_MODE=true
fi

# 统一调用 Mojo 实现的健康检查逻辑
# 假设二进制安装在 /app/dadaozhijian，且支持 --healthcheck 子命令
if $READY_MODE; then
  exec /app/dadaozhijian --healthcheck --ready
else
  exec /app/dadaozhijian --healthcheck
fi