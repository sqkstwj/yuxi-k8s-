# Yuxi Kubernetes 改造说明

> 基于开源项目 [xerrors/Yuxi](https://github.com/xerrors/Yuxi) 的企业化部署改造版本。

## 项目定位

本仓库不是对 Yuxi 核心业务逻辑的大规模重写，而是在保留其原有 Agent、RAG、知识图谱、前后端主体能力的基础上，重点补齐了以下内容：

- 面向公司 Kubernetes 环境的部署能力
- 面向私有镜像仓库的镜像构建与拉取适配
- 从 `lite` 模式升级到 `full mode` 所需的中间件接入
- `sandbox-provisioner` 在 Kubernetes 集群内的运行适配
- 更适合企业网络和 CPU 节点环境的构建参数与依赖配置

## 改造目标

本次改造主要解决了开源项目在企业集群落地时的几个关键问题：

1. 将项目从本地 Docker / Compose 运行方式迁移到公司 Kubernetes 环境。
2. 支持私有镜像仓库、镜像拉取凭据、Ingress、PVC、共享存储等企业部署要素。
3. 支持在 K8s 中启用 `full mode`，补齐 Neo4j、Milvus、etcd 等中间件。
4. 让 `sandbox-provisioner` 适配 Kubernetes 集群内部网络，而不是依赖本地 NodePort 假设。
5. 优化镜像构建链路，适配受限网络环境和 CPU 节点部署。

## 改动总览

| 模块 | 改造内容 | 价值 |
| --- | --- | --- |
| Kubernetes 部署 | 新增 `deploy/k8s/single/` 全套 YAML | 可以直接在公司 K8s 环境部署 |
| Full Mode | 新增 Neo4j / Milvus / etcd 资源与升级说明 | 补齐知识库、图谱、评估能力 |
| 私有镜像仓库 | 统一改为公司私有镜像地址，并增加 `imagePullSecrets` | 适配企业镜像分发方式 |
| Sandbox | `sandbox-provisioner` 支持 `ClusterIP`、集群域名、镜像拉取密钥 | 提升 Agent 沙箱在 K8s 内部可用性 |
| 存储 | 新增数据库、中间件和共享目录 PVC | 满足集群持久化与共享文件需求 |
| 网络 | 增加 Web Ingress 与 API NodePort 方案 | 便于对外访问与调试 |
| 构建链路 | Dockerfile 支持可配置镜像源、索引源和功能开关 | 更适合企业网络与 CI |
| 依赖 | 将 PyTorch 调整为 CPU 版本 | 降低镜像体积与节点要求 |

## 主要新增内容

### 1. 新增整套 Kubernetes 单命名空间部署清单

新增目录：

- `deploy/k8s/single/`

该目录下新增了完整的 Kubernetes 资源文件，覆盖：

- Namespace
- 镜像拉取 Secret
- 应用 ConfigMap / Secret
- PostgreSQL / Redis / MinIO / Neo4j / etcd / Milvus 的 PVC、Service、Deployment
- `web` / `api` / `worker` / `sandbox-provisioner` 的 Deployment 与 Service
- Ingress
- `sandbox-provisioner` 所需 RBAC
- 聚合版 YAML：`90-base.yaml`、`91-middleware.yaml`、`92-app.yaml`、`99-single-stack.yaml`

这部分改造把项目从“本地可运行”推进到了“集群可交付”。

### 2. 新增 Full Mode 升级方案

新增文件：

- `deploy/k8s/single/FULL-MODE.md`

该文档描述了从 `lite` 模式切换到 `full mode` 的完整流程，包括：

- Neo4j、Milvus、etcd 的镜像准备
- 配置项变化
- 部署顺序
- 升级后的校验方式

### 3. 新增 K8s 部署使用文档

新增文件：

- `deploy/k8s/single/README.md`

该文档补充了：

- 单命名空间部署结构说明
- 配置准备方式
- PVC 与共享存储要求
- 手动 `kubectl apply` 顺序
- 聚合 YAML 的使用方式
- 部署后的基础验证方法

## 关键改造点

### 1. 默认 K8s 配置切换为 Full Mode

在 K8s 配置中显式设置：

- `LITE_MODE=false`
- `PROVISIONER_BACKEND=kubernetes`
- `K8S_SERVICE_TYPE=ClusterIP`
- `K8S_IMAGE_PULL_SECRET`
- `K8S_CLUSTER_DOMAIN`

对应文件：

- `deploy/k8s/single/02-app-configmap.yaml`

这意味着项目部署到公司集群后，默认按完整能力模式运行，而不是沿用上游偏轻量的默认假设。

### 2. 适配公司私有镜像仓库

部署镜像统一改为公司私有镜像仓库，例如：

- `hub.uimpcloud.com/yuxi/yuxi-api:0.6.0`
- `hub.uimpcloud.com/yuxi/yuxi-web:0.6.0`
- `hub.uimpcloud.com/yuxi/yuxi-sandbox-provisioner:0.6.0`
- `hub.uimpcloud.com/yuxi/neo4j:5.26`
- `hub.uimpcloud.com/yuxi/milvus:v2.5.6`

并配套增加：

- `imagePullSecrets`
- 私有仓库认证 Secret 模板

这样项目可以直接使用企业内部镜像，而不是依赖公网镜像源。

### 3. 改造 sandbox-provisioner 的 Kubernetes 运行方式

修改文件：

- `docker/sandbox_provisioner/app.py`

新增支持：

- `K8S_SERVICE_TYPE`
- `K8S_IMAGE_PULL_SECRET`
- `K8S_CLUSTER_DOMAIN`
- 为动态创建的 sandbox Pod 注入 `imagePullSecrets`
- 在 `ClusterIP` 模式下生成集群内可访问的 Service 地址

这部分改造解决了上游实现更偏向本地 / NodePort 的限制，使 Agent 沙箱能力可以更自然地运行在 K8s 集群内部。

### 4. 增加 sandbox-provisioner 所需 RBAC

新增文件：

- `deploy/k8s/single/08-sandbox-rbac.yaml`

新增资源：

- ServiceAccount
- Role
- RoleBinding

用于支持 `sandbox-provisioner` 在命名空间内动态创建、查询和删除 Pod / Service。

### 5. 新增共享存储与中间件持久化设计

新增 PVC 覆盖：

- PostgreSQL
- Redis
- MinIO
- Neo4j
- etcd
- Milvus
- 共享目录 PVC

其中共享目录 PVC 用于支撑：

- `/app/saves`
- 线程数据
- Skills
- 沙箱共享工作目录

这使项目更符合集群部署场景下的持久化与共享文件需求。

### 6. 增加 Web Ingress 与 API NodePort

新增文件：

- `deploy/k8s/single/15-web-ingress.yaml`
- `deploy/k8s/single/23-api-nodeport-service.yaml`

分别用于：

- 通过 Nginx Ingress 对外暴露 Web
- 在需要时通过 NodePort 直接访问 API，便于调试或联调

## 对镜像构建流程的修改

### API 镜像

修改文件：

- `docker/api.Dockerfile`

主要改动：

- 增加 `UV_DEFAULT_INDEX`
- 增加 `UV_HTTP_TIMEOUT`
- 在容器内重新执行 `uv lock` 与 `uv sync`
- 提前复制 `README.md` 和 `backend/package`

目的：

- 提升受限网络环境下的依赖安装稳定性
- 支持通过自定义 Python 索引源构建镜像
- 减少对宿主机 lock 结果的强依赖

### Web 镜像

修改文件：

- `docker/web.Dockerfile`

主要改动：

- 增加 `NPM_REGISTRY`
- 增加 `VITE_LITE_MODE`
- 增加 `VITE_USE_RUNS_API`
- `pnpm install` 改为可配置 registry

目的：

- 适配企业内网 / 国内镜像源
- 支持构建不同运行模式的前端镜像
- 为后续前端功能开关预留参数入口

### sandbox-provisioner 镜像

修改文件：

- `docker/sandbox_provisioner/Dockerfile`

主要改动：

- 增加 `PIP_INDEX_URL`

目的：

- 支持在受限网络环境下通过指定包索引完成镜像构建

## 对依赖的修改

### PyTorch 调整为 CPU 版本

修改文件：

- `backend/package/pyproject.toml`

主要改动：

- `torch` 调整为 `2.8.0+cpu`
- `torchvision` 调整为 `0.23.0+cpu`
- 增加 `pytorch-cpu` 索引源

目的：

- 更适配普通 Kubernetes 节点
- 降低镜像体积和依赖复杂度
- 避免默认依赖 GPU 环境

## 相对上游新增的可交付成果

基于本次改造，本仓库相对上游新增了以下可以直接落地的内容：

1. 一套可直接部署到 Kubernetes 的 YAML 资源。
2. 一套从 `lite` 升级到 `full mode` 的中间件部署方案。
3. 一套适配私有镜像仓库的镜像引用方式。
4. 一套适配企业网络环境的镜像构建参数体系。
5. 一套适配 Kubernetes 内部网络的 sandbox-provisioner 运行方案。
6. 一套可交付给运维或后续维护者的部署与升级文档。

## 关键文件

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

## 当前版本的核心价值

这次二次开发的重点，不是重写 Yuxi 的业务能力，而是围绕以下方向完成工程化落地：

- 从开发态推进到可部署态
- 从 Lite 模式推进到 Full Mode
- 从本地 Docker 假设推进到 Kubernetes 集群假设
- 从公网镜像依赖推进到企业私有仓库依赖
- 从单机调试方式推进到标准化集群运维方式

## 后续维护建议

建议后续继续保持以下边界：

- 上游功能同步保持最小侵入
- 企业部署相关内容集中在 `deploy/`、Dockerfile 和配置适配层
- Secret 与真实环境配置不要直接写入公开仓库

这样后续升级上游版本时，冲突更少，维护成本也更低。
