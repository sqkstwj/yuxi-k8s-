# Yuxi Full Mode Upgrade

This directory now contains the Kubernetes resources required to upgrade the current `lite` deployment to full mode.

## Extra Images

Push these images to the private registry before applying the new YAML files:

- `hub.uimpcloud.com/yuxi/neo4j:5.26`
- `hub.uimpcloud.com/yuxi/etcd:v3.5.5`
- `hub.uimpcloud.com/yuxi/milvus:v2.5.6`

Suggested source images:

- `neo4j:5.26`
- `quay.io/coreos/etcd:v3.5.5`
- `milvusdb/milvus:v2.5.6`

## What Changed

- `LITE_MODE` is now `false`
- API and worker will load knowledge, graph, evaluation and mindmap routers
- New in-cluster middleware has been added:
  - `neo4j`
  - `etcd`
  - `milvus`

## New Files

- `25-neo4j-pvc.yaml`
- `26-etcd-pvc.yaml`
- `27-milvus-pvc.yaml`
- `28-neo4j-service.yaml`
- `29-neo4j-deployment.yaml`
- `30-etcd-service.yaml`
- `31-etcd-deployment.yaml`
- `32-milvus-service.yaml`
- `33-milvus-deployment.yaml`

## Apply Order

If you create resources one by one:

```bash
kubectl apply -f deploy/k8s/single/25-neo4j-pvc.yaml
kubectl apply -f deploy/k8s/single/26-etcd-pvc.yaml
kubectl apply -f deploy/k8s/single/27-milvus-pvc.yaml
kubectl apply -f deploy/k8s/single/28-neo4j-service.yaml
kubectl apply -f deploy/k8s/single/29-neo4j-deployment.yaml
kubectl apply -f deploy/k8s/single/30-etcd-service.yaml
kubectl apply -f deploy/k8s/single/31-etcd-deployment.yaml
kubectl apply -f deploy/k8s/single/32-milvus-service.yaml
kubectl apply -f deploy/k8s/single/33-milvus-deployment.yaml
kubectl apply -f deploy/k8s/single/02-app-configmap.yaml
kubectl apply -f deploy/k8s/single/03-app-secret.yaml
kubectl rollout restart deployment/api -n yuxi
kubectl rollout restart deployment/worker -n yuxi
kubectl rollout restart deployment/web -n yuxi
```

If you use grouped manifests:

```bash
kubectl apply -f deploy/k8s/single/90-base.yaml
kubectl apply -f deploy/k8s/single/91-middleware.yaml
kubectl apply -f deploy/k8s/single/92-app.yaml
kubectl rollout restart deployment/api -n yuxi
kubectl rollout restart deployment/worker -n yuxi
```

## Verification

```bash
kubectl get pods -n yuxi
kubectl get svc -n yuxi
kubectl logs deploy/api -n yuxi --tail=200
```

Expected new services:

- `neo4j` on `7474/7687`
- `etcd` on `2379`
- `milvus` on `19530/9091`

## Notes

- `api` and `worker` must be restarted after the ConfigMap / Secret update, otherwise the running pods will keep the old `LITE_MODE` environment.
- The current `web` image should be built for full mode. If it was previously rebuilt with `VITE_LITE_MODE=true`, rebuild and push it again without that build arg.
- `HOST_IP` is still empty. This is fine for the first full-mode rollout. Only set it later if you need browser-direct MinIO object URLs.
- The new Neo4j password is stored in `03-app-secret.yaml`. Rotate it after the environment is stable.
