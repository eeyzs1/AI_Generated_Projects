#!/bin/bash
set -e

# 4Chat K8s 部署脚本
# 用法:
#   本地 registry（默认）:  ./k8s/deploy.sh
#   Docker Hub:            ./k8s/deploy.sh --registry dockerhub --hub-user <your-dockerhub-username>
#   云服务中间件:           ./k8s/deploy.sh --cloud
#   组合使用:              ./k8s/deploy.sh --registry dockerhub --hub-user myuser --cloud

REGISTRY_TYPE="local"
HUB_USER=""
CLOUD_MIDDLEWARE=false
SERVICES=("user-service" "group-service" "message-service" "connector-service" "push-service" "storage-service")
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# 解析参数
while [[ $# -gt 0 ]]; do
  case $1 in
    --registry) REGISTRY_TYPE="$2"; shift 2 ;;
    --hub-user) HUB_USER="$2"; shift 2 ;;
    --cloud) CLOUD_MIDDLEWARE=true; shift ;;
    *) echo "未知参数: $1"; exit 1 ;;
  esac
done

# 确定镜像前缀
if [[ "$REGISTRY_TYPE" == "dockerhub" ]]; then
  if [[ -z "$HUB_USER" ]]; then
    echo "错误: 使用 Docker Hub 时需要指定 --hub-user <username>"
    exit 1
  fi
  REGISTRY="$HUB_USER"
  echo "==> 使用 Docker Hub registry: $REGISTRY"
else
  REGISTRY="localhost:5000"
  echo "==> 使用本地 registry: $REGISTRY"
fi

# 检查 minikube
echo "==> 检查 minikube 状态..."
if ! minikube status | grep -q "Running"; then
  echo "minikube 未运行，正在启动..."
  minikube start
fi

# 启动本地 registry（仅本地模式）
if [[ "$REGISTRY_TYPE" == "local" ]]; then
  echo "==> 启动本地镜像 registry..."
  docker run -d -p 5000:5000 --name registry registry:2 2>/dev/null || echo "registry 已在运行"
fi

# 登录 Docker Hub（仅 dockerhub 模式）
if [[ "$REGISTRY_TYPE" == "dockerhub" ]]; then
  echo "==> 登录 Docker Hub..."
  docker login
fi

# 构建并推送镜像
echo "==> 构建并推送镜像..."
for svc in "${SERVICES[@]}"; do
  echo "  构建 $svc ..."
  docker build -t "$REGISTRY/$svc:latest" "$ROOT_DIR/services/$svc"
  docker push "$REGISTRY/$svc:latest"
done

echo "  构建 frontend ..."
docker build -t "$REGISTRY/frontend:latest" "$ROOT_DIR/frontend"
docker push "$REGISTRY/frontend:latest"

# 替换 YAML 中的镜像地址
echo "==> 更新 K8s 镜像地址..."
OVERLAY_DIR="$ROOT_DIR/k8s/overlays/local"
if [[ "$CLOUD_MIDDLEWARE" == true ]]; then
  OVERLAY_DIR="$ROOT_DIR/k8s/overlays/cloud"
fi

# 部署中间件（仅本地模式）
if [[ "$CLOUD_MIDDLEWARE" == false ]]; then
  echo "==> 部署中间件..."
  kubectl apply -f "$ROOT_DIR/k8s/middleware/mysql.yaml"
  kubectl apply -f "$ROOT_DIR/k8s/middleware/redis.yaml"
  kubectl apply -f "$ROOT_DIR/k8s/middleware/kafka.yaml"
  kubectl apply -f "$ROOT_DIR/k8s/middleware/nacos.yaml"

  echo "==> 等待中间件就绪..."
  kubectl wait --for=condition=ready pod -l app=mysql --timeout=180s
  kubectl wait --for=condition=ready pod -l app=redis --timeout=60s
  kubectl wait --for=condition=ready pod -l app=kafka --timeout=180s
  kubectl wait --for=condition=ready pod -l app=nacos --timeout=180s
else
  echo "==> 云服务中间件模式，跳过中间件部署"
  echo "    请确保 k8s/overlays/cloud/cloud-env.yaml 中已填写正确的连接信息"
fi

# 部署网关
echo "==> 部署网关..."
kubectl apply -f "$ROOT_DIR/k8s/gateway/apisix.yaml"

# 部署业务服务
echo "==> 部署业务服务..."
if [[ "$CLOUD_MIDDLEWARE" == true ]]; then
  kubectl apply -k "$ROOT_DIR/k8s/overlays/cloud"
else
  # 替换镜像地址后部署
  for svc in "${SERVICES[@]}"; do
    sed "s|localhost:5000/$svc:latest|$REGISTRY/$svc:latest|g" \
      "$ROOT_DIR/k8s/services/$svc.yaml" | kubectl apply -f -
  done
  sed "s|localhost:5000/frontend:latest|$REGISTRY/frontend:latest|g" \
    "$ROOT_DIR/k8s/services/frontend.yaml" | kubectl apply -f -
fi

# 等待服务就绪
echo "==> 等待业务服务就绪..."
for svc in "${SERVICES[@]}"; do
  kubectl wait --for=condition=ready pod -l app="$svc" --timeout=120s
done
kubectl wait --for=condition=ready pod -l app=frontend --timeout=60s

echo ""
echo "✅ 部署完成！"
MINIKUBE_IP=$(minikube ip)
echo ""
echo "  前端地址:  http://$MINIKUBE_IP:30000"
echo "  API 网关:  http://$MINIKUBE_IP:30080"
echo ""
echo "查看所有 Pod 状态: kubectl get pods"
