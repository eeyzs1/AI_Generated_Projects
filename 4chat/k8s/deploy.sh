#!/bin/bash
set -e

# 4Chat K8s 部署脚本
# 用法:
#   minikube 直接构建（默认）: ./k8s/deploy.sh
#   Docker Hub:               ./k8s/deploy.sh --registry dockerhub --hub-user <your-dockerhub-username>
#   云服务中间件:              ./k8s/deploy.sh --cloud
#   组合使用:                 ./k8s/deploy.sh --registry dockerhub --hub-user myuser --cloud

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

# 检查 minikube
echo "==> 检查 minikube 状态..."
if ! minikube status | grep -q "Running"; then
  echo "minikube 未运行，正在启动..."
  minikube start
fi

# 确定镜像前缀和构建方式
if [[ "$REGISTRY_TYPE" == "dockerhub" ]]; then
  if [[ -z "$HUB_USER" ]]; then
    echo "错误: 使用 Docker Hub 时需要指定 --hub-user <username>"
    exit 1
  fi
  REGISTRY="$HUB_USER"
  echo "==> 使用 Docker Hub registry: $REGISTRY"
  echo "==> 登录 Docker Hub..."
  docker login
else
  # 本地模式：用宿主机 Docker 构建，再 load 进 minikube
  REGISTRY="localhost:5000"
  echo "==> 本地模式：使用宿主机 Docker 构建后 load 进 minikube"
fi

# 尝试拉取镜像，失败则从宿主机 load
load_image_if_needed() {
  local img="$1"
  if minikube image ls 2>/dev/null | grep -qF "$img"; then
    echo "  镜像已存在: $img"
    return 0
  fi
  echo "  尝试拉取: $img ..."
  if minikube image pull "$img" 2>/dev/null; then
    echo "  拉取成功: $img"
  else
    echo "  拉取失败，从宿主机 load: $img ..."
    minikube image load "$img"
  fi
}

# 构建镜像
echo "==> 构建镜像..."
if [[ "$REGISTRY_TYPE" == "dockerhub" ]]; then
  for svc in "${SERVICES[@]}"; do
    echo "  构建 $svc ..."
    docker build -t "$REGISTRY/$svc:latest" "$ROOT_DIR/services/$svc"
  done
  echo "  构建 frontend ..."
  docker build -t "$REGISTRY/frontend:latest" "$ROOT_DIR/frontend"

  echo "==> 推送镜像到 Docker Hub..."
  for svc in "${SERVICES[@]}"; do
    docker push "$REGISTRY/$svc:latest"
  done
  docker push "$REGISTRY/frontend:latest"
else
  # 宿主机构建 + load 进 minikube
  for svc in "${SERVICES[@]}"; do
    echo "  构建 $svc ..."
    docker build -t "$REGISTRY/$svc:latest" "$ROOT_DIR/services/$svc"
    echo "  加载 $svc 到 minikube ..."
    minikube image load "$REGISTRY/$svc:latest"
  done
  echo "  构建 frontend ..."
  docker build -t "$REGISTRY/frontend:latest" "$ROOT_DIR/frontend"
  echo "  加载 frontend 到 minikube ..."
  minikube image load "$REGISTRY/frontend:latest"
fi

# 部署中间件（仅本地模式）
if [[ "$CLOUD_MIDDLEWARE" == false ]]; then
  # 预加载中间件镜像（pull 失败则从宿主机 load）
  echo "==> 预加载中间件镜像..."
  MIDDLEWARE_IMAGES=(
    "mysql:8.4"
    "redis:8-alpine"
    "confluentinc/cp-zookeeper:7.9.6"
    "confluentinc/cp-kafka:7.9.6"
    "nacos/nacos-server:v3.1.1-slim"
    "scylladb/scylla:6.2"
    "apache/apisix:3.15.0-ubuntu"
  )
  for img in "${MIDDLEWARE_IMAGES[@]}"; do
    load_image_if_needed "$img"
  done

  echo "==> 部署中间件..."
  kubectl apply -f "$ROOT_DIR/k8s/middleware/mysql.yaml"
  kubectl apply -f "$ROOT_DIR/k8s/middleware/redis.yaml"
  kubectl apply -f "$ROOT_DIR/k8s/middleware/kafka.yaml"
  kubectl apply -f "$ROOT_DIR/k8s/middleware/nacos.yaml"
  kubectl apply -f "$ROOT_DIR/k8s/middleware/scylladb.yaml"

  echo "==> 等待中间件就绪..."
  kubectl wait --for=condition=ready pod -l app=mysql --timeout=300s
  kubectl wait --for=condition=ready pod -l app=redis --timeout=60s
  kubectl wait --for=condition=ready pod -l app=kafka --timeout=300s
  kubectl wait --for=condition=ready pod -l app=nacos --timeout=300s
  kubectl wait --for=condition=ready pod -l app=scylladb --timeout=180s
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
  kubectl wait --for=condition=ready pod -l app="$svc" --timeout=180s
done
kubectl wait --for=condition=ready pod -l app=frontend --timeout=120s
kubectl wait --for=condition=ready pod -l app=apisix --timeout=120s

echo ""
echo "✅ 部署完成！"
MINIKUBE_IP=$(minikube ip)
echo ""
echo "  前端地址:  http://$MINIKUBE_IP:30000"
echo "  API 网关:  http://$MINIKUBE_IP:30080"
echo ""
echo "如需在 Windows 浏览器访问（WSL 环境），运行："
echo "  kubectl port-forward service/frontend 13000:3000 --address=0.0.0.0 &"
echo "  kubectl port-forward service/apisix 8080:9080 --address=0.0.0.0 &"
echo "  然后访问 http://localhost:13000"
echo ""
echo "查看所有 Pod 状态: kubectl get pods"
