#!/bin/bash
set -e

# 4Chat K8s 部署脚本
# 用法:
#   minikube 直接构建（默认）: ./k8s/deploy.sh
#   Docker Hub:               ./k8s/deploy.sh --registry dockerhub --hub-user <your-dockerhub-username>
#   云服务中间件:              ./k8s/deploy.sh --cloud
#   滚动重启所有服务:          ./k8s/deploy.sh --restart
#   智能更新（检测变更）:      ./k8s/deploy.sh --update [service-name]
#   卸载:                     ./k8s/deploy.sh --uninstall
#   组合使用:                 ./k8s/deploy.sh --registry dockerhub --hub-user myuser --cloud

REGISTRY_TYPE="local"
HUB_USER=""
CLOUD_MIDDLEWARE=false
UNINSTALL=false
RESTART=false
UPDATE=false
UPDATE_TARGET=""
SERVICES=("user-service" "group-service" "message-service" "connector-service" "push-service" "storage-service")
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# 解析参数
while [[ $# -gt 0 ]]; do
  case $1 in
    --registry) REGISTRY_TYPE="$2"; shift 2 ;;
    --hub-user) HUB_USER="$2"; shift 2 ;;
    --cloud) CLOUD_MIDDLEWARE=true; shift ;;
    --uninstall) UNINSTALL=true; shift ;;
    --restart) RESTART=true; shift ;;
    --update) UPDATE=true; UPDATE_TARGET="${2:-}"; [[ -n "$UPDATE_TARGET" ]] && shift 2 || shift ;;
    *) echo "未知参数: $1"; exit 1 ;;
  esac
done

# ---------- 卸载 ----------
if [[ "$UNINSTALL" == true ]]; then
  echo "==> 卸载 kubectl 部署的资源..."
  kubectl delete all --all 2>/dev/null || true
  kubectl delete configmap --all 2>/dev/null || true
  echo "✅ 卸载完成"
  echo ""
  echo "注意: PVC 数据卷不会自动删除（防止数据丢失）"
  echo "直接运行 ./k8s/helm-deploy.sh 即可切换到 Helm 模式，数据不丢失"
  exit 0
fi

# ---------- 滚动重启 ----------
if [[ "$RESTART" == true ]]; then
  echo "==> 滚动重启所有服务..."
  DEPLOYMENTS=$(kubectl get deploy --no-headers -o custom-columns=NAME:.metadata.name 2>/dev/null || true)
  STATEFULSETS=$(kubectl get statefulset --no-headers -o custom-columns=NAME:.metadata.name 2>/dev/null || true)
  for deploy in $DEPLOYMENTS; do
    echo "  重启 deployment/$deploy"
    kubectl rollout restart deployment/"$deploy"
  done
  for sts in $STATEFULSETS; do
    echo "  重启 statefulset/$sts"
    kubectl rollout restart statefulset/"$sts"
  done
  echo "✅ 重启完成"
  exit 0
fi

# ---------- 智能更新 ----------
if [[ "$UPDATE" == true ]]; then
  REGISTRY="localhost:5000"
  SERVICES_LIST=(user-service group-service message-service connector-service push-service storage-service frontend)

  if [[ -n "$UPDATE_TARGET" ]]; then
    # 更新指定服务
    if [[ "$UPDATE_TARGET" == "frontend" ]]; then
      context="$ROOT_DIR/frontend"
    else
      context="$ROOT_DIR/services/$UPDATE_TARGET"
    fi
    if [[ ! -d "$context" ]]; then
      echo "错误: 服务 $UPDATE_TARGET 不存在"
      exit 1
    fi
    echo "==> 更新 $UPDATE_TARGET..."
    docker build -t "$REGISTRY/$UPDATE_TARGET:latest" "$context"
    minikube image load "$REGISTRY/$UPDATE_TARGET:latest"
    kubectl rollout restart deployment/"$UPDATE_TARGET" 2>/dev/null || kubectl rollout restart statefulset/"$UPDATE_TARGET" 2>/dev/null
    echo "✅ $UPDATE_TARGET 更新完成"
  else
    # 检测所有服务变更
    echo "==> 检测服务代码变更..."
    for svc in "${SERVICES_LIST[@]}"; do
      [[ "$svc" == "frontend" ]] && context="$ROOT_DIR/frontend" || context="$ROOT_DIR/services/$svc"
      old_id=$(minikube ssh -- docker inspect --format='{{.Id}}' "$REGISTRY/$svc:latest" 2>/dev/null | tr -d '\r' || true)
      docker build -q -t "$REGISTRY/$svc:latest" "$context" >/dev/null
      new_id=$(docker inspect --format='{{.Id}}' "$REGISTRY/$svc:latest" 2>/dev/null || true)
      if [[ "$old_id" != "$new_id" ]]; then
        echo "  检测到变更: $svc，重新加载镜像..."
        minikube image load "$REGISTRY/$svc:latest"
        kubectl rollout restart deployment/"$svc" 2>/dev/null || kubectl rollout restart statefulset/"$svc" 2>/dev/null
      else
        echo "  无变更: $svc"
      fi
    done
    echo "✅ 更新完成"
  fi
  exit 0
fi

# 将所有 PVC 的所有权移交给 kubectl（移除 Helm 标记）
adopt_pvcs_to_kubectl() {
  local pvcs
  pvcs=$(kubectl get pvc --no-headers -o custom-columns=NAME:.metadata.name 2>/dev/null || true)
  [[ -z "$pvcs" ]] && return 0
  local needs_adopt=false
  for pvc in $pvcs; do
    local manager
    manager=$(kubectl get pvc "$pvc" -o jsonpath='{.metadata.labels.app\.kubernetes\.io/managed-by}' 2>/dev/null || true)
    if [[ "$manager" == "Helm" ]]; then
      needs_adopt=true
      break
    fi
  done
  [[ "$needs_adopt" == false ]] && return 0
  echo "==> 检测到 Helm 管理的 PVC，自动移交所有权给 kubectl..."
  for pvc in $pvcs; do
    kubectl label pvc "$pvc" app.kubernetes.io/managed-by- helm.sh/chart- 2>/dev/null || true
    kubectl annotate pvc "$pvc" meta.helm.sh/release-name- meta.helm.sh/release-namespace- 2>/dev/null || true
    echo "  ✓ $pvc"
  done
}

# 卸载 Helm releases（如果存在）
teardown_helm() {
  local has_helm=false
  for release in 4chat 4chat-middleware 4chat-services; do
    if helm status "$release" &>/dev/null; then
      has_helm=true
      break
    fi
  done
  [[ "$has_helm" == false ]] && return 0
  echo "==> 检测到 Helm releases，自动卸载后切换到 kubectl 模式..."
  helm uninstall 4chat 2>/dev/null || true
  helm uninstall 4chat-middleware 2>/dev/null || true
  helm uninstall 4chat-services 2>/dev/null || true
}

teardown_helm
adopt_pvcs_to_kubectl

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
  # 宿主机构建 + 按需 load 进 minikube（ID 一致则跳过）
  build_and_load() {
    local img="$1"
    local context="$2"
    echo "  构建 $img ..."
    docker build -t "$img" "$context"
    local new_id mk_id
    new_id=$(docker inspect --format='{{.Id}}' "$img" 2>/dev/null || true)
    mk_id=$(minikube ssh -- docker inspect --format='{{.Id}}' "$img" 2>/dev/null | tr -d '\r' || true)
    if [[ -n "$mk_id" && "$mk_id" == "$new_id" ]]; then
      echo "  minikube 已有最新镜像，跳过 load: $img"
    else
      echo "  加载到 minikube: $img ..."
      minikube image load "$img"
    fi
  }
  for svc in "${SERVICES[@]}"; do
    build_and_load "$REGISTRY/$svc:latest" "$ROOT_DIR/services/$svc"
  done
  build_and_load "$REGISTRY/frontend:latest" "$ROOT_DIR/frontend"
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
