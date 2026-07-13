#!/bin/bash
# ops/rotate_llm_key.sh
# 用途：定期轮换 LLM_API_KEY，零停机重载
# 依赖：kubectl, 外部密钥管理（Vault/AWS Secrets Manager/1Password CLI 等）

set -euo pipefail

NAMESPACE="${NAMESPACE:-dadaozhijian}"
SECRET_NAME="${SECRET_NAME:-dadaozhijian-secrets}"
KEY_NAME="${KEY_NAME:-LLM_API_KEY}"

# 1. 从外部密钥源获取新 Key（示例：Vault KV v2）
# NEW_KEY=$(vault kv get -field=api_key secret/dadaozhijian/llm)
# 或者从 AWS Secrets Manager：
# NEW_KEY=$(aws secretsmanager get-secret-value --secret-id dadaozhijian/llm --query SecretString --output text | jq -r .api_key)
# 或者从 1Password CLI：
# NEW_KEY=$(op read "op://Dadaozhijian/LLM/API Key")

# 演示：从环境变量读取（CI/CD 注入）
NEW_KEY="${NEW_LLM_API_KEY:-}"
if [[ -z "$NEW_KEY" ]]; then
  echo "❌ NEW_LLM_API_KEY 环境变量未设置"
  exit 1
fi

# 2. 更新 Secret（kubectl create secret --dry-run -o yaml | kubectl apply -f -）
kubectl create secret generic "$SECRET_NAME" \
  --namespace="$NAMESPACE" \
  --from-literal="$KEY_NAME=$NEW_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Secret $SECRET_NAME 已更新"

# 3. 滚动重启 Deployment（触发 readiness 检查重新加载配置）
# 利用 annotation 变更触发 rolling restart，保证零停机
kubectl patch deployment dadaozhijian \
  -n "$NAMESPACE" \
  -p "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"llm-key-rotated\":\"$(date +%s)\"}}}}"

echo "✅ Deployment 已触发滚动重启"

# 4. 等待 rollout 完成
kubectl rollout status deployment/dadaozhijian -n "$NAMESPACE" --timeout=5m

echo "✅ LLM API Key 轮换完成"