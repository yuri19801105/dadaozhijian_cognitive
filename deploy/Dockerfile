# dadaozhijian_cognitive — 多阶段构建（调研最优解：静态二进制优先，容器化仅作可选分支）
#
# 关键事实（Mojo 1.0.0b2）：`mojo build` 默认产出**静态链接**二进制（官方文档 + 社区实测），
#   故部署单元是二进制本身，而非源码、也非必须容器。本 Dockerfile 仅在「多服务编排 /
#   水平扩展 / k8s」场景使用；单服务长驻进程用 deploy/systemd/ 或 supervisord 更轻。
#
# 镜像体积：朴素 `modular/mojo` 全量镜像 ~3.8–4.2GB；多阶段后 runtime 仅 ~300–500MB。
# 真正运行时依赖：编译产物二进制 + （shifang 侧车需）python3。
#
# 用法：
#   docker build -t dadaozhijian:latest --build-arg ENTRY=observability/store_demo.mojo .
#   docker run -d --name dadaozhijian -v $(pwd)/data:/data dadaozhijian:latest

# —— Stage 1: 构建（编译器仅在构建期存在，不进 runtime）——
FROM modular/mojo:latest AS builder
WORKDIR /app
# 源码（含 core/ 与各模块；-I . -I core 是当前固定包含方式）
COPY . /app/
ARG ENTRY=observability/store_demo.mojo
RUN mojo build -I . -I core "${ENTRY}" -o /app/bin/dadaozhijian

# —— Stage 2: 运行时（极简基础镜像，仅二进制 + python3）——
FROM debian:bookworm-slim AS runtime
WORKDIR /app
# shifang 真实 LLM 侧车经 system(python3 ...) 桥接，故 runtime 需 python3
RUN apt-get update && apt-get install -y --no-install-recommends python3 && rm -rf /var/lib/apt/lists/*
COPY --from=builder /app/bin/dadaozhijian /usr/local/bin/dadaozhijian
# 配置外置：挂载 config/defaults.toml，运行期免重编译（见 architecture §6#4）
COPY config/defaults.toml /etc/dadaozhijian/defaults.toml
# 探针（退出码健康检查，见 ops/healthcheck.sh）
COPY ops/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/healthcheck.sh
# 可选：Prometheus 文本指标导出（node_exporter textfile 兼容，免 HTTP 服务）
# COPY ops/metrics_exporter.mojo /opt/dadaozhijian/metrics_exporter.mojo

HEALTHCHECK --interval=30s --timeout=5s --retries=3 --start-period=10s \
  CMD ["/usr/local/bin/healthcheck.sh"]

ENTRYPOINT ["/usr/local/bin/dadaozhijian"]
