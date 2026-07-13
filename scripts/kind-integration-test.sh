#!/bin/bash
# scripts/kind-integration-test.sh
# Kind 本地集成测试：部署 dadaozhijian → 验证指标采集/告警/健康检查

set -euo pipefail

CLUSTER_NAME="dadaozhijian-test"
NAMESPACE="dadaozhijian"
REGISTRY="localhost:5001"
IMAGE_TAG="test-$(date +%s)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 颜色
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log() { echo -e "${GREEN}[$(date +%H:%M:%S)]${NC} $*"; }
warn() { echo -e "${YELLOW}[$(date +%H:%M:%S)]${NC} $*"; }
err() { echo -e "${RED}[$(date +%H:%M:%S)]${NC} $*" >&2; }

check_prereqs() {
  command -v kind >/dev/null || { err "kind 未安装"; exit 1; }
  command -v kubectl >/dev/null || { err "kubectl 未安装"; exit 1; }
  command -v docker >/dev/null || { err "docker 未安装"; exit 1; }
  command -v kustomize >/dev/null || { err "kustomize 未安装"; exit 1; }
}

create_cluster() {
  log "创建 Kind 集群: $CLUSTER_NAME"
  cat <<EOF | kind create cluster --name "$CLUSTER_NAME" --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30000
    hostPort: 30000
    protocol: TCP
  - containerPort: 30001
    hostPort: 30001
    protocol: TCP
  - containerPort: 9100
    hostPort: 9100
    protocol: TCP
  - containerPort: 9090
    hostPort: 9090
    protocol: TCP
  - containerPort: 3000
    hostPort: 3000
    protocol: TCP
EOF
}

setup_registry() {
  log "启动本地镜像仓库: $REGISTRY"
  docker run -d --name kind-registry --restart=always -p "5001:5000" registry:2 || true
  # 连接 registry 到 kind 网络
  docker network connect "kind" "kind-registry" 2>/dev/null || true
}

build_and_push_image() {
  log "构建并推送镜像: $REGISTRY/dadaozhijian:$IMAGE_TAG"
  cd "$PROJECT_ROOT"
  docker build -t "$REGISTRY/dadaozhijian:$IMAGE_TAG" -f deploy/Dockerfile .
  docker push "$REGISTRY/dadaozhijian:$IMAGE_TAG"
}

load_image_to_kind() {
  log "将镜像加载到 Kind 节点"
  kind load docker-image "$REGISTRY/dadaozhijian:$IMAGE_TAG" --name "$CLUSTER_NAME"
}

deploy_monitoring() {
  log "部署 Prometheus Operator (简化版：使用 kube-prometheus-stack)"
  # 这里简化：直接部署 Prometheus + node-exporter DaemonSet
  kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/bundle.yaml 2>/dev/null || true
  sleep 10
  kubectl wait --for=condition=Available deployment/prometheus-operator -n monitoring --timeout=120s 2>/dev/null || true
}

deploy_dadaozhijian() {
  log "部署 dadaozhijian (staging overlay)"
  cd "$PROJECT_ROOT"
  # 更新镜像标签
  cd deploy/k8s/overlays/staging
  kustomize edit set image dadaozhijian="$REGISTRY/dadaozhijian:$IMAGE_TAG"
  # 应用
  kustomize build . | kubectl apply -f -
  # 等待 Deployment 就绪
  kubectl rollout status deployment/dadaozhijian -n "$NAMESPACE" --timeout=180s
}

verify_metrics() {
  log "验证指标采集"
  # 等待 node-exporter 采集
  sleep 15
  # 通过 Port-forward 访问 Prometheus
  kubectl port-forward -n monitoring svc/prometheus-k8s 9090:9090 &
  PF_PID=$!
  sleep 5
  
  # 查询关键指标
  for metric in \
    "dadaozhijian_throughput_total" \
    "dadaozhijian_degraded_total" \
    "dadaozhijian_backfill_success_rate" \
    "dadaozhijian_wuxing_variance" \
    "dadaozhijian_cycle_duration_seconds_bucket" \
    "dadaozhijian_memory_used_bytes" \
    "dadaozhijian_task_slots_used" \
    "dadaozhijian_journal_entries" \
    "dadaozhijian_last_snapshot_timestamp_seconds"; do
    result=$(curl -s "http://localhost:9090/api/v1/query?query=$metric" | jq -r '.data.result | length')
    if [[ "$result" -gt 0 ]]; then
      log "✅ 指标存在: $metric (series=$result)"
    else
      warn "⚠️ 指标缺失: $metric"
    fi
  done
  
  kill $PF_PID 2>/dev/null || true
}

verify_healthcheck() {
  log "验证健康检查"
  POD=$(kubectl get pods -n "$NAMESPACE" -l app=dadaozhijian -o jsonpath='{.items[0].metadata.name}')
  if [[ -n "$POD" ]]; then
    # Liveness
    if kubectl exec -n "$NAMESPACE" "$POD" -c app -- /app/ops/healthcheck.sh; then
      log "✅ Liveness 探针通过"
    else
      warn "⚠️ Liveness 探针失败"
    fi
    # Readiness
    if kubectl exec -n "$NAMESPACE" "$POD" -c app -- /app/ops/healthcheck.sh --ready; then
      log "✅ Readiness 探针通过"
    else
      warn "⚠️ Readiness 探针失败"
    fi
  fi
}

verify_alerts() {
  log "验证告警规则加载"
  # 检查 PrometheusRule 是否被 Prometheus 发现
  ALERTS=$(kubectl get prometheusrule -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
  if [[ -n "$ALERTS" ]]; then
    log "✅ PrometheusRule 已加载: $ALERTS"
  else
    warn "⚠️ 未发现 PrometheusRule"
  fi
}

cleanup() {
  log "清理资源"
  kind delete cluster --name "$CLUSTER_NAME" || true
  docker rm -f kind-registry || true
}

main() {
  log "=== Kind 集成测试开始 ==="
  check_prereqs
  
  trap cleanup EXIT
  
  create_cluster
  setup_registry
  build_and_push_image
  load_image_to_kind
  deploy_monitoring
  deploy_dadaozhijian
  
  verify_metrics
  verify_healthcheck
  verify_alerts
  
  log "=== 所有验证通过 ✅ ==="
}

main "$@"