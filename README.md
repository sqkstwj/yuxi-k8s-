# 项目改造说明

## 1. 项目来源

本项目基于开源项目 **Yuxi** 二次改造，原始仓库为：

- Upstream: `https://github.com/xerrors/Yuxi`

当前仓库在保留 Yuxi 原有 Agent、RAG、知识图谱与前后端主体能力的基础上，重点补齐了 **面向公司 Kubernetes 环境的部署能力、镜像构建适配能力，以及全量知识库模式运行所需的中间件接入能力**。

本说明重点记录我在开源项目基础上做过的本地化修改和新增内容，不重复介绍上游项目原生功能。

## 2. 改造目标

本次改造主要围绕以下目标展开：

1. 让项目可以从原本偏本地 Docker / Compose 的运行方式，迁移到公司 Kubernetes 环境中稳定部署。
2. 支持公司私有镜像仓库、镜像拉取凭据、Ingress 暴露、持久化存储等企业部署要素。
3. 将原本的 `lite` 运行模式扩展为可在 Kubernetes 中启用的 **full mode**，补齐 Neo4j、Milvus、etcd 等中间件。
4. 让 `sandbox-provisioner` 真正适配 Kubernetes 集群内部网络，而不是只依赖 NodePort / 本地开发假设。
5. 优化镜像构建链路，使其更适合受限网络、镜像源替换和 CPU 环境部署。

## 3. 主要新增内容

### 3.1 新增整套 Kubernetes 单命名空间部署清单

新增目录：

- `deploy/k8s/single/`

该目录下新增了完整的 Kubernetes 资源文件，覆盖：

- 命名空间
- 镜像拉取 Secret
- 应用配置 ConfigMap
- 应用 Secret
- PostgreSQL / Redis / MinIO / Neo4j / etcd / Milvus 的 PVC、Service、Deployment
- `api` / `worker` / `web` / `sandbox-provisioner` 的 Deployment 与 Service
- Ingress
- `sandbox-provisioner` 所需 RBAC
- 聚合版 YAML（`90-base.yaml`、`91-middleware.yaml`、`92-app.yaml`、`99-single-stack.yaml`）

这部分改造把原项目从“能本地跑”扩展到了“能在公司集群里完整落地”。

### 3.2 新增 Full Mode 升级方案

新增文件：

- `deploy/k8s/single/FULL-MODE.md`

该文档描述了如何将当前部署从 `lite` 模式切换为 `full mode`，包括：

- 新增 Neo4j、Milvus、etcd 三类中间件
- 镜像准备要求
- 配置项变化
- 部署顺序
- 升级后的校验方式

这使项目不仅能在 K8s 中启动基础能力，也能完整启用知识库、图谱、评估等高级功能。

### 3.3 新增 K8s 部署使用文档

新增文件：

- `deploy/k8s/single/README.md`

该文档补充了：

- 单命名空间部署结构说明
- 资源拆分方式
- 配置项准备说明
- PVC 与共享存储要求
- 手动 `kubectl apply` 顺序
- 聚合 YAML 的使用方式
- 基础验证命令

这部分属于运维交付文档，降低了后续部署和接手成本。

## 4. 我对原项目做过的关键修改

### 4.1 将默认 K8s 配置切换为 Full Mode

在新增的 K8s ConfigMap 中，我显式将：

- `LITE_MODE` 设置为 `false`
- `PROVISIONER_BACKEND` 设置为 `kubernetes`
- `K8S_SERVICE_TYPE` 设置为 `ClusterIP`
- `K8S_IMAGE_PULL_SECRET`、`K8S_CLUSTER_DOMAIN` 等集群运行参数补齐

对应文件：

- `deploy/k8s/single/02-app-configmap.yaml`

这意味着部署到公司集群后，系统默认按完整功能模式运行，而不是上游默认的轻量模式。

### 4.2 新增对公司私有镜像仓库的适配

我把部署镜像统一指向公司私有镜像仓库，例如：

- `hub.uimpcloud.com/yuxi/yuxi-api:0.6.0`
- `hub.uimpcloud.com/yuxi/yuxi-web:0.6.0`
- `hub.uimpcloud.com/yuxi/yuxi-sandbox-provisioner:0.6.0`
- `hub.uimpcloud.com/yuxi/neo4j:5.26`
- `hub.uimpcloud.com/yuxi/milvus:v2.5.6`

同时增加了：

- `imagePullSecrets`
- 私有仓库认证 Secret 模板

这样项目可以直接使用公司镜像仓库中的构建产物，而不是依赖公网镜像。

### 4.3 为 sandbox-provisioner 增加 Kubernetes 集群内服务发现能力

我修改了 `docker/sandbox_provisioner/app.py`，让 Kubernetes backend 支持：

- 自定义 `K8S_SERVICE_TYPE`
- 自定义 `K8S_IMAGE_PULL_SECRET`
- 自定义 `K8S_CLUSTER_DOMAIN`
- 为动态创建的 sandbox Pod 注入 `imagePullSecrets`
- 在 `ClusterIP` 模式下生成集群内可访问的 Service 地址，而不是只依赖 `NodePort`

这项改动的意义很大：

- 上游逻辑更偏向本地 / NodePort 场景
- 公司集群内部更适合用 `ClusterIP + svc DNS`
- 动态 sandbox Pod 在私有镜像仓库下也需要拉取密钥

这部分改造直接提升了 Agent 沙箱能力在 K8s 内部的可用性。

### 4.4 新增 sandbox-provisioner 的 RBAC 资源

为了让 `sandbox-provisioner` 能在命名空间内动态创建和删除 Pod / Service，我新增了：

- ServiceAccount
- Role
- RoleBinding

对应文件：

- `deploy/k8s/single/08-sandbox-rbac.yaml`

这是从“单机开发”走向“集群调度”必须补上的权限配置。

### 4.5 新增共享存储设计

我为项目增加了面向 K8s 的持久化方案：

- PostgreSQL 数据 PVC
- Redis 数据 PVC
- MinIO 数据 PVC
- Neo4j 数据 PVC
- etcd 数据 PVC
- Milvus 数据 PVC
- 共享目录 PVC（供 `/app/saves`、线程数据、Skills 等复用）

其中共享存储是重点，因为：

- `api` 与 `worker` 都依赖 `/app/saves`
- sandbox 运行也需要访问共享工作目录
- 这比上游偏本地文件系统的假设更适合集群部署

### 4.6 新增 API NodePort 暴露方式

我额外增加了：

- `deploy/k8s/single/23-api-nodeport-service.yaml`

用于在特定场景下直接通过 NodePort 访问 API，便于调试、联调或临时暴露后端接口。

### 4.7 新增 Web Ingress 暴露方案

新增文件：

- `deploy/k8s/single/15-web-ingress.yaml`

补齐了基于 Nginx Ingress 的访问入口，并加入了：

- 请求体大小限制
- 读写超时配置

这使前端可以更符合企业网络环境地对外暴露，而不是只停留在本地端口映射模式。

## 5. 对镜像构建流程的修改

### 5.1 API 镜像构建增强

我修改了 `docker/api.Dockerfile`，主要包括：

- 增加 `UV_DEFAULT_INDEX` 构建参数
- 增加 `UV_HTTP_TIMEOUT`
- 在容器内重新执行 `uv lock` 与 `uv sync`
- 提前复制 `README.md` 和 `backend/package`

目的主要是：

- 提升受限网络环境下的依赖安装稳定性
- 允许通过自定义索引源构建镜像
- 避免直接依赖宿主机提交的 lock 结果

### 5.2 Web 镜像构建增强

我修改了 `docker/web.Dockerfile`，主要包括：

- 增加 `NPM_REGISTRY` 构建参数
- 增加 `VITE_LITE_MODE`
- 增加 `VITE_USE_RUNS_API`
- 将 `pnpm install` 的 registry 改为可配置

目的主要是：

- 适配国内 / 内网镜像源
- 允许构建不同运行模式的前端镜像
- 为后续集群环境下的前端功能开关预留空间

### 5.3 sandbox-provisioner 镜像构建增强

我修改了 `docker/sandbox_provisioner/Dockerfile`，增加：

- `PIP_INDEX_URL` 构建参数

目的是让该镜像在受限网络环境下也能通过指定 Python 包索引完成构建。

## 6. 对依赖的修改

### 6.1 将 PyTorch 调整为 CPU 版本

我修改了 `backend/package/pyproject.toml`：

- 将 `torch` 切换为 `2.8.0+cpu`
- 将 `torchvision` 切换为 `0.23.0+cpu`
- 显式增加 `pytorch-cpu` 索引源

这样做的主要原因是：

- 公司 K8s 部署场景未必具备 GPU
- CPU 版本更适合普通节点和通用镜像构建
- 能降低镜像体积和依赖复杂度

## 7. 与上游相比，新增了哪些可直接交付的成果

基于本次改造，项目相对于上游新增了以下“可落地交付物”：

1. 一套可直接部署到 Kubernetes 的 YAML 资源。
2. 一套完整的 full mode 中间件部署方案。
3. 一套适配私有镜像仓库的镜像引用方式。
4. 一套适配企业网络环境的镜像构建参数体系。
5. 一套适配 Kubernetes 内部网络的 sandbox-provisioner 运行方案。
6. 一套部署说明和升级说明文档。

## 8. 当前改造的重点价值

总结来说，这次二次开发并不是去重写 Yuxi 的业务逻辑，而是围绕“**让开源项目能够真正落地到公司 K8s 环境**”做了工程化改造，重点价值包括：

- 把项目从开发态推进到可部署态
- 把 Lite 模式推进到 Full Mode
- 把本地 Docker 假设推进到 K8s 集群假设
- 把公网镜像依赖推进到企业私有仓库依赖
- 把单机调试方式推进到标准化集群运维方式

## 9. 主要改动文件清单

### 新增目录

- `deploy/k8s/single/`

### 关键修改文件

- `backend/package/pyproject.toml`
- `docker/api.Dockerfile`
- `docker/web.Dockerfile`
- `docker/sandbox_provisioner/Dockerfile`
- `docker/sandbox_provisioner/app.py`

### 关键新增文件

- `deploy/k8s/single/02-app-configmap.yaml`
- `deploy/k8s/single/08-sandbox-rbac.yaml`
- `deploy/k8s/single/12-api-deployment.yaml`
- `deploy/k8s/single/14-sandbox-provisioner-deployment.yaml`
- `deploy/k8s/single/15-web-ingress.yaml`
- `deploy/k8s/single/23-api-nodeport-service.yaml`
- `deploy/k8s/single/29-neo4j-deployment.yaml`
- `deploy/k8s/single/31-etcd-deployment.yaml`
- `deploy/k8s/single/33-milvus-deployment.yaml`
- `deploy/k8s/single/FULL-MODE.md`
- `deploy/k8s/single/README.md`

## 10. 备注

由于本仓库包含 Kubernetes 部署模板与企业环境适配内容，后续如果继续演进，建议将“上游同步”和“企业本地化改造”分开管理：

- 上游功能跟进保持最小侵入
- 企业部署相关改造尽量集中在 `deploy/`、Dockerfile 和配置适配层

这样后续继续升级上游版本时，冲突会更少，维护成本也更低。
