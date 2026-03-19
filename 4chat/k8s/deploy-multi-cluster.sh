#!/bin/bash
set -e

# 4Chat 多集群 K8s 部署脚本（Istio 服务网格）
#
# 用法:
#   ./k8s/deploy-multi-cluster.sh \
#     --context-a <cluster-a-context> \
#     --context-b <cluster-b-context> \
#     --registry dockerhub \
#     --hub-user <dockerhub-username>
#
# 示例:
#   ./k8s/deploy-multi-cluster.sh \
#     --context-a k8s-region-a \
#     --context-b k8s-region-b \
#     --registry dockerhub \
#     --hub-user myuser
#
# 前置要求:
#   - 两个 K8s 集群已配置好 kubeconfig context
#   - istioctl 已安装 (https://istio.io/latest/docs/setup/getting-started/)
#   - 两个集群网络互通（East-West Gateway 端口 15443 可达）

CONTEXT_A=""
CONTEXT_B=""
REGISTRY_TYPE="local"
HUB_USER=""
SERVICES=("user-service" "group-service" "message-service" "connector-service" "push-service" "storage-service")
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# 解析参数
while [[ $# -gt 0 ]]; do
  case $1 in
    --context-a) CONTEXT_A="$2"; shift 2 ;;
    --context-b) CONTEXT_B="$2"; shift 2 ;;
    --registry)  REGISTRY_TYPE="$2"; shift 2 ;;
    --hub-user)  HUB_USER="$2"; shift 2 ;;
    *) echo "未知参数: $1"; exit 1 ;;
  esac
done

if [[ -z "$CONTEXT_A" || -z "$CONTEXT_B" ]]; then
  echo "错误: 必须指定 --context-a 和 --context-b"
  echo "查看可用 context: kubectl config get-contexts"
  exit 1
fi

if [[ "$REGISTRY_TYPE" == "dockerhub" && -z "$HUB_USER" ]]; then
  echo "错误: 使用 Docker Hub 时需要指定 --hub-user"
  exit 1
fi

REGISTRY="localhost:5000"
if [[ "$REGISTRY_TYPE" == "dockerhub" ]]; then
  REGISTRY="$HUB_USER"
  echo "==> 登录 Docker Hub..."
  docker login
fi

# ── Step 1: 构建并推送镜像 ────────────────────────────────────
echo "==> 构建并推送镜像到 $REGISTRY ..."
for svc in "${SERVICES[@]}"; do
  echo "  构建 $svc ..."
  docker build -t "$REGISTRY/$svc:latest" "$ROOT_DIR/services/$svc"
  docker push "$REGISTRY/$svc:latest"
done
docker build -t "$REGISTRY/frontend:latest" "$ROOT_DIR/frontend"
docker push "$REGISTRY/frontend:latest"

# ── Step 2: 安装 Istio ────────────────────────────────────────
echo "==> 在集群A 安装 Istio..."
istioctl install --context="$CONTEXT_A" \
  --set profile=default \
  --set values.pilot.env.EXTERNAL_ISTIOD=false \
  -y

echo "==> 在集群B 安装 Istio..."
istioctl install --context="$CONTEXT_B" \
  --set profile=default \
  -y

# ── Step 3: 部署 East-West Gateway ───────────────────────────
echo "==> 部署 East-West Gateway..."
istioctl install --context="$CONTEXT_A" \
  -f "$ROOT_DIR/k8s/istio/east-west-gateway.yaml" -y
istioctl install --context="$CONTEXT_B" \
  -f "$ROOT_DIR/k8s/istio/east-west-gateway.yaml" -y

echo "==> 等待 East-West Gateway 获取外部 IP..."
kubectl --context="$CONTEXT_A" wait --for=condition=available \
  deployment/istio-eastwestgateway -n istio-system --timeout=120s
kubectl --context="$CONTEXT_B" wait --for=condition=available \
  deployment/istio-eastwestgateway -n istio-system --timeout=120s

CLUSTER_A_IP=$(kubectl --context="$CONTEXT_A" get svc istio-eastwestgateway \
  -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
CLUSTER_B_IP=$(kubectl --context="$CONTEXT_B" get svc istio-eastwestgateway \
  -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "  集群A East-West IP: $CLUSTER_A_IP"
echo "  集群B East-West IP: $CLUSTER_B_IP"

# 替换 service-entries.yaml 中的占位符
sed -e "s/<CLUSTER_A_EASTWEST_IP>/$CLUSTER_A_IP/g" \
    -e "s/<CLUSTER_B_EASTWEST_IP>/$CLUSTER_B_IP/g" \
    "$ROOT_DIR/k8s/istio/service-entries.yaml" > /tmp/service-entries-rendered.yaml

# ── Step 4: 部署中间件（两个集群都需要）─────────────────────
echo "==> 部署中间件到集群A..."
kubectl --context="$CONTEXT_A" apply -f "$ROOT_DIR/k8s/middleware/"
echo "==> 部署中间件到集群B..."
kubectl --context="$CONTEXT_B" apply -f "$ROOT_DIR/k8s/middleware/"

echo "==> 等待中间件就绪..."
kubectl --context="$CONTEXT_A" wait --for=condition=ready pod -l app=mysql --timeout=180s
kubectl --context="$CONTEXT_A" wait --for=condition=ready pod -l app=kafka --timeout=180s
kubectl --context="$CONTEXT_B" wait --for=condition=ready pod -l app=redis --timeout=60s
kubectl --context="$CONTEXT_B" wait --for=condition=ready pod -l app=kafka --timeout=180s

# ── Step 5: 部署业务服务 ──────────────────────────────────────
echo "==> 部署业务服务到集群A（user/group/message）..."
for svc in user-service group-service message-service; do
  sed "s|localhost:5000/$svc:latest|$REGISTRY/$svc:latest|g" \
    "$ROOT_DIR/k8s/services/$svc.yaml" | kubectl --context="$CONTEXT_A" apply -f -
done
kubectl --context="$CONTEXT_A" apply -f "$ROOT_DIR/k8s/gateway/apisix.yaml"
kubectl --context="$CONTEXT_A" apply -f "$ROOT_DIR/k8s/services/frontend.yaml"

echo "==> 部署业务服务到集群B（connector/push/storage）..."
for svc in connector-service push-service storage-service; do
  sed "s|localhost:5000/$svc:latest|$REGISTRY/$svc:latest|g" \
    "$ROOT_DIR/k8s/services/$svc.yaml" | kubectl --context="$CONTEXT_B" apply -f -
done

# ── Step 6: 应用 Istio 流量规则 ──────────────────────────────
echo "==> 应用 Istio 流量规则..."
kubectl --context="$CONTEXT_A" apply -f "$ROOT_DIR/k8s/istio/destination-rules.yaml"
kubectl --context="$CONTEXT_A" apply -f "$ROOT_DIR/k8s/istio/virtual-services.yaml"
kubectl --context="$CONTEXT_A" apply -f "$ROOT_DIR/k8s/istio/peer-authentication.yaml"
kubectl --context="$CONTEXT_A" apply -f /tmp/service-entries-rendered.yaml

kubectl --context="$CONTEXT_B" apply -f "$ROOT_DIR/k8s/istio/destination-rules.yaml"
kubectl --context="$CONTEXT_B" apply -f "$ROOT_DIR/k8s/istio/virtual-services.yaml"
kubectl --context="$CONTEXT_B" apply -f "$ROOT_DIR/k8s/istio/peer-authentication.yaml"
kubectl --context="$CONTEXT_B" apply -f /tmp/service-entries-rendered.yaml

# ── Step 7: 等待服务就绪 ──────────────────────────────────────
echo "==> 等待集群A 服务就绪..."
for svc in user-service group-service message-service; do
  kubectl --context="$CONTEXT_A" wait --for=condition=ready pod -l app="$svc" --timeout=120s
done

echo "==> 等待集群B 服务就绪..."
for svc in connector-service push-service storage-service; do
  kubectl --context="$CONTEXT_B" wait --for=condition=ready pod -l app="$svc" --timeout=120s
done

echo ""
echo "✅ 多集群部署完成！"
echo ""
echo "  集群A 前端:  通过集群A 的 Ingress/LoadBalancer 访问"
echo "  集群A 网关:  NodePort 30080 或 LoadBalancer"
echo ""
echo "查看集群A Pod: kubectl --context=$CONTEXT_A get pods"
echo "查看集群B Pod: kubectl --context=$CONTEXT_B get pods"
echo ""
echo "验证 Istio 服务网格:"
echo "  istioctl --context=$CONTEXT_A proxy-status"
echo "  istioctl --context=$CONTEXT_B proxy-status"
