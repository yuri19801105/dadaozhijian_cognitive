#!/bin/bash
# ops/drill_restore.sh
# 用途：从持久化快照恢复 TaijiState，验证数据完整性
# 前提：已部署 dadaozhijian，且 Persistence 已写入共享卷/PVC

set -euo pipefail

NAMESPACE="${NAMESPACE:-dadaozhijian}"
POD_SELECTOR="app=dadaozhijian"
SNAPSHOT_DIR="/var/lib/dadaozhijian/state"
REMOTE_SNAPSHOT_URL="${REMOTE_SNAPSHOT_URL:-}"  # 可选：远程对象存储 URL

# 颜色
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

log() { echo -e "${GREEN}[$(date +%H:%M:%S)]${NC} $*"; }
warn() { echo -e "${YELLOW}[$(date +%H:%M:%S)]${NC} $*"; }
err() { echo -e "${RED}[$(date +%H:%M:%S)]${NC} $*" >&2; }

get_pod() {
  kubectl get pods -n "$NAMESPACE" -l "$POD_SELECTOR" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

check_prereqs() {
  command -v kubectl >/dev/null || { err "kubectl 未安装"; exit 1; }
  kubectl auth can-i get pods -n "$NAMESPACE" >/dev/null || { err "无权限访问 namespace $NAMESPACE"; exit 1; }
}

download_snapshot() {
  if [[ -n "$REMOTE_SNAPSHOT_URL" ]]; then
    log "从远程下载快照: $REMOTE_SNAPSHOT_URL"
    kubectl exec -n "$NAMESPACE" "$(get_pod)" -- \
      sh -c "curl -fsSL '$REMOTE_SNAPSHOT_URL' -o $SNAPSHOT_DIR/taiji_state.bin"
  else
    log "使用本地快照 (假设 PVC 已挂载到 $SNAPSHOT_DIR)"
  fi
}

trigger_restore() {
  log "触发 TaijiState 恢复..."
  # 方式 1：向运行中的进程发送信号/调用内部恢复 API（需二进制支持 --restore）
  # 方式 2：删除 Pod 让 K8s 重建，启动时自动 load()
  warn "当前版本通过重建 Pod 实现恢复演练"
  kubectl delete pod -n "$NAMESPACE" -l "$POD_SELECTOR" --wait=false
  log "Pod 已删除，等待重建..."
  kubectl wait --for=condition=Ready pod -l "$POD_SELECTOR" -n "$NAMESPACE" --timeout=120s
}

verify_state() {
  log "验证恢复后的状态..."
  POD=$(get_pod)
  if [[ -z "$POD" ]]; then
    err "未找到就绪 Pod"
    exit 1
  fi

  # 通过 healthcheck --ready 验证运行时状态
  if kubectl exec -n "$NAMESPACE" "$POD" -- /app/ops/healthcheck.sh --ready; then
    log "✅ Readiness 检查通过"
  else
    err "❌ Readiness 检查失败"
    exit 1
  fi

  # 可选：调用自定义验证端点（如 /debug/taiji_state）
  # kubectl exec -n "$NAMESPACE" "$POD" -- /app/dadaozhijian --dump-state | jq '.round >= 10'
}

main() {
  log "=== Dadaozhijian 灾难恢复演练 ==="
  check_prereqs
  download_snapshot
  trigger_restore
  verify_state
  log "=== 演练完成 ✅ ==="
}

main "$@"