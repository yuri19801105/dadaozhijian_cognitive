#!/usr/bin/env python3
# scripts/seal_secrets.py
# 使用 kubeseal 将明文 secrets.toml 加密为 SealedSecret（GitOps 安全）
# 前置：kubectl + kubeseal 已安装，集群已安装 SealedSecrets Controller

import subprocess, sys, os, base64, yaml, json

SECRETS_FILE = "config/secrets.toml"
SEALED_NAME = "dadaozhijian-secrets"
NAMESPACE = "dadaozhijian"
OUTPUT_FILE = "deploy/k8s/sealed-secrets.yaml"

def run(cmd, input_data=None, check=True):
    print(f"$ {' '.join(cmd)}")
    result = subprocess.run(cmd, input=input_data, capture_output=True, text=True)
    if check and result.returncode != 0:
        print(f"❌ Command failed: {result.stderr}")
        sys.exit(result.returncode)
    return result

def main():
    if not os.path.exists(SECRETS_FILE):
        print(f"❌ {SECRETS_FILE} 不存在，请先按 config/secrets.toml.template 创建")
        sys.exit(1)

    # 读取明文 secrets.toml
    with open(SECRETS_FILE) as f:
        toml_content = f.read()

    # 构造 Secret 清单（不写文件，直接管道传给 kubeseal）
    secret_manifest = {
        "apiVersion": "v1",
        "kind": "Secret",
        "metadata": {
            "name": SEALED_NAME,
            "namespace": NAMESPACE
        },
        "type": "Opaque",
        "stringData": {
            "secrets.toml": toml_content
        }
    }

    # kubeseal --format=yaml --name=<name> --namespace=<ns>
    result = run(
        ["kubeseal", "--format=yaml", f"--name={SEALED_NAME}", f"--namespace={NAMESPACE}"],
        input_data=yaml.dump(secret_manifest),
        check=False
    )

    if result.returncode != 0:
        print("❌ kubeseal 失败，请确认：")
        print("  1. kubeseal 已安装")
        print("  2. 集群已部署 SealedSecrets Controller (kubectl get crd sealedsecrets.bitnami.com)")
        print("  3. 当前 kubeconfig 指向正确集群")
        sys.exit(1)

    # 写入输出文件
    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
    with open(OUTPUT_FILE, "w") as f:
        f.write(result.stdout)

    print(f"✅ SealedSecret 已生成: {OUTPUT_FILE}")
    print("   提交该文件到 Git，Controller 会自动解密为 Secret。")

if __name__ == "__main__":
    main()