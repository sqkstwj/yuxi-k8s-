# Yuxi K8s Single-Namespace Deployment

这套清单用于第一阶段把项目在公司 Kubernetes 中跑通，目标是先跑通：

- `web`
- `api`
- `worker`
- `sandbox-provisioner`
- `postgres`
- `redis`
- `minio`

当前清单默认：

- 命名空间：`yuxi`
- 镜像仓库：`hub.uimpcloud.com/yuxi/*`
- 运行模式：`LITE_MODE=true`
- `sandbox-provisioner` 使用 Kubernetes backend
- sandbox Service 使用 `ClusterIP`

## 文件放在哪里

所有文件都放在这个目录里：

- `deploy/k8s/single/`

你现在需要创建或编辑的文件就是：

- `deploy/k8s/single/00-namespace.yaml`
- `deploy/k8s/single/01-image-pull-secret.yaml`
- `deploy/k8s/single/02-app-configmap.yaml`
- `deploy/k8s/single/03-app-secret.yaml`
- `deploy/k8s/single/04-postgres-pvc.yaml`
- `deploy/k8s/single/05-redis-pvc.yaml`
- `deploy/k8s/single/06-minio-pvc.yaml`
- `deploy/k8s/single/07-shared-pvc.yaml`
- `deploy/k8s/single/08-sandbox-rbac.yaml`
- `deploy/k8s/single/10-web-deployment.yaml`
- `deploy/k8s/single/11-web-service.yaml`
- `deploy/k8s/single/12-api-deployment.yaml`
- `deploy/k8s/single/13-worker-deployment.yaml`
- `deploy/k8s/single/14-sandbox-provisioner-deployment.yaml`
- `deploy/k8s/single/15-web-ingress.yaml`
- `deploy/k8s/single/16-api-service.yaml`
- `deploy/k8s/single/17-sandbox-provisioner-service.yaml`
- `deploy/k8s/single/18-postgres-deployment.yaml`
- `deploy/k8s/single/19-postgres-service.yaml`
- `deploy/k8s/single/20-redis-service.yaml`
- `deploy/k8s/single/21-redis-deployment.yaml`
- `deploy/k8s/single/22-minio-service.yaml`
- `deploy/k8s/single/24-minio-deployment.yaml`

## 先改这几个地方

在应用前，先手工修改下面这些值：

- `01-image-pull-secret.yaml`
  - 把仓库用户名、密码、`auth` 替换成真实值
- `03-app-secret.yaml`
  - `SILICONFLOW_API_KEY`

说明：

- `POSTGRES_PASSWORD`、`POSTGRES_URL`、`MINIO_SECRET_KEY` 已经生成并写入，可直接用
- `15-web-ingress.yaml` 已改成不要求固定 host，可先直接用
- 现在还必须确认的只有两项：
  - `01-image-pull-secret.yaml` 里的仓库凭证是否已真实保存到文件
  - `03-app-secret.yaml` 里的 `SILICONFLOW_API_KEY` 是否替换成真实模型 Key

## 存储要求

这里最关键的是：

- `07-shared-pvc.yaml` 必须能提供 `ReadWriteMany`

因为：

- `api` 和 `worker` 都要挂载 `/app/saves`
- `sandbox-provisioner` 动态创建的 sandbox Pod 也要挂同一个 PVC
- 线程文件、workspace、skills 都依赖同一套共享目录

如果你们集群默认存储类不支持 `ReadWriteMany`，这个 PVC 会一直 `Pending`，需要换成支持 `RWX` 的存储类。

## 应用顺序

按下面顺序执行最稳：

```bash
kubectl apply -f deploy/k8s/single/00-namespace.yaml
kubectl apply -f deploy/k8s/single/01-image-pull-secret.yaml
kubectl apply -f deploy/k8s/single/02-app-configmap.yaml
kubectl apply -f deploy/k8s/single/03-app-secret.yaml
kubectl apply -f deploy/k8s/single/04-postgres-pvc.yaml
kubectl apply -f deploy/k8s/single/05-redis-pvc.yaml
kubectl apply -f deploy/k8s/single/06-minio-pvc.yaml
kubectl apply -f deploy/k8s/single/07-shared-pvc.yaml
kubectl apply -f deploy/k8s/single/08-sandbox-rbac.yaml
kubectl apply -f deploy/k8s/single/19-postgres-service.yaml
kubectl apply -f deploy/k8s/single/18-postgres-deployment.yaml
kubectl apply -f deploy/k8s/single/20-redis-service.yaml
kubectl apply -f deploy/k8s/single/21-redis-deployment.yaml
kubectl apply -f deploy/k8s/single/22-minio-service.yaml
kubectl apply -f deploy/k8s/single/24-minio-deployment.yaml
kubectl apply -f deploy/k8s/single/17-sandbox-provisioner-service.yaml
kubectl apply -f deploy/k8s/single/14-sandbox-provisioner-deployment.yaml
kubectl apply -f deploy/k8s/single/16-api-service.yaml
kubectl apply -f deploy/k8s/single/12-api-deployment.yaml
kubectl apply -f deploy/k8s/single/13-worker-deployment.yaml
kubectl apply -f deploy/k8s/single/11-web-service.yaml
kubectl apply -f deploy/k8s/single/10-web-deployment.yaml
kubectl apply -f deploy/k8s/single/15-web-ingress.yaml
```

如果你是在 KubeSphere 控制台终端里操作，不方便一次性导入很大的 YAML，可以直接用这 3 个分组文件：

- `deploy/k8s/single/90-base.yaml`
- `deploy/k8s/single/91-middleware.yaml`
- `deploy/k8s/single/92-app.yaml`

顺序如下：

```bash
kubectl apply -f 90-base.yaml
kubectl apply -f 91-middleware.yaml
kubectl apply -f 92-app.yaml
```

如果控制台终端看不到你本地仓库文件，就在终端里分别执行：

```bash
cat > /tmp/90-base.yaml <<'EOF'
这里粘贴 90-base.yaml 的全部内容
EOF
kubectl apply -f /tmp/90-base.yaml

cat > /tmp/91-middleware.yaml <<'EOF'
这里粘贴 91-middleware.yaml 的全部内容
EOF
kubectl apply -f /tmp/91-middleware.yaml

cat > /tmp/92-app.yaml <<'EOF'
这里粘贴 92-app.yaml 的全部内容
EOF
kubectl apply -f /tmp/92-app.yaml
```

## 检查顺序

先看 Pod：

```bash
kubectl get pods -n yuxi
```

再看 Service：

```bash
kubectl get svc -n yuxi
```

再看 PVC：

```bash
kubectl get pvc -n yuxi
```

如果 `api` 启动正常，可以先检查健康接口：

```bash
kubectl port-forward -n yuxi svc/api 5050:5050
curl http://127.0.0.1:5050/api/system/health
```

## 首次初始化管理员

这个项目第一次启动后，不是靠环境变量自动创建管理员，而是调用接口初始化。

先检查是否首次运行：

```bash
curl http://127.0.0.1:5050/api/auth/check-first-run
```

如果返回 `first_run=true`，再初始化管理员：

```bash
curl -X POST http://127.0.0.1:5050/api/auth/initialize \
  -H "Content-Type: application/json" \
  -d "{\"user_id\":\"admin\",\"password\":\"ChangeMe123\"}"
```

## 这套清单的边界

这套清单是第一阶段最小可运行版本，默认只解决：

- 登录
- 基础聊天
- worker 任务消费
- sandbox 动态创建

它现在没有包含：

- `neo4j`
- `milvus`
- `etcd`
- OCR / GPU 相关组件

后续如果你要把知识库、图谱、OCR 也补上，再继续扩展 `deploy/k8s/single/` 即可。

## 已知注意点

- `yuxi-web:0.6.0` 如果不是按 `VITE_LITE_MODE=true` 重新构建，前端界面可能还会显示知识库或图谱入口，但不影响第一阶段跑通。
- `minio` 当前只做了集群内 `ClusterIP` 暴露。如果后面你要直接在浏览器里访问 MinIO 对象 URL，还需要单独给 MinIO 做外部访问方案，并同步调整 `HOST_IP`。
- 这套方案依赖你上传的 `yuxi-sandbox-provisioner:0.6.0` 已经包含当前本地代码里的 `K8S_IMAGE_PULL_SECRET` 和 `K8S_SERVICE_TYPE` 支持。
