#!/bin/bash
set -e

# 4Chat Helm 部署脚本
# 用法:
#   全量部署（umbrella chart）:   ./k8s/helm-deploy.sh
#   仅中间件:                     ./k8s/helm-deploy.sh --only middleware
#   仅业务服务:                   ./k8s/helm-deploy.sh --only services
#   Docker Hub 镜像:              ./k8s/helm-deploy.sh --registry dockerhub --hub-user <username>
#   云服务中间件（跳过本地中间件）:./k8s/helm-deploy.sh --cloud
#   滚动重启所有服务:              ./k8s/helm-deploy.sh --restart
#   智能更新（检测变更）:          ./k8s/helm-deploy.sh --update [service-name]
#   卸载:                         ./k8s/helm-deploy.sh --uninstall
#   组合使用:                     ./k8s/helm-deploy.sh --registry dockerhub --hub-user myuser --cloud

REGISTRY_TYPE="local"
HUB_USER=""
CLOUD_MIDDLEWARE=false
ONLY=""
UNINSTALL=false
RESTART=false
UPDATE=false
UPDATE_TARGET=""
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HELM_DIR="$ROOT_DIR/helm"

RELEASE_MIDDLEWARE="4chat-middleware"
RELEASE_SERVICES="4chat-services"
RELEASE_ALL="4chat"

# 解析参数
while [[ $# -gt 0 ]]; do
  case $1 in
    --registry)   REGISTRY_TYPE="$2"; shift 2 ;;
    --hub-user)   HUB_USER="$2"; shift 2 ;;
    --cloud)      CLOUD_MIDDLEWARE=true; shift ;;
    --only)       ONLY="$2"; shift 2 ;;
    --uninstall)  UNINSTALL=true; shift ;;
    --restart)    RESTART=true; shift ;;
    --update)     UPDATE=true; UPDATE_TARGET="${2:-}"; [[ -n "$UPDATE_TARGET" ]] && shift 2 || shift ;;
    *) echo "未知参数: $1"; exit 1 ;;
  esac
done

# ---------- 卸载 ----------
if [[ "$UNINSTALL" == true ]]; then
  echo "==> 卸载 Helm releases..."
  helm uninstall "$RELEASE_ALL"       2>/dev/null && echo "  已卸载 $RELEASE_ALL"       || true
  helm uninstall "$RELEASE_MIDDLEWARE" 2>/dev/null && echo "  已卸载 $RELEASE_MIDDLEWARE" || true
  helm uninstall "$RELEASE_SERVICES"  2>/dev/null && echo "  已卸载 $RELEASE_SERVICES"  || true
  echo "✅ 卸载完成"
  echo ""
  echo "注意: PVC 数据卷不会自动删除（防止数据丢失）"
  echo "直接运行 ./k8s/deploy.sh 即可切换到 kubectl 模式，数据不丢失"
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

# ---------- 检查依赖 ----------
if ! command -v helm &>/dev/null; then
  echo "错误: 未找到 helm，请先安装 helm v3: https://helm.sh/docs/intro/install/"
  exit 1
fi

echo "==> 检查 minikube 状态..."
if ! minikube status | grep -q "Running"; then
  echo "minikube 未运行，正在启动..."
  minikube start
fi

# ---------- 确定镜像 registry ----------
if [[ "$REGISTRY_TYPE" == "dockerhub" ]]; then
  if [[ -z "$HUB_USER" ]]; then
    echo "错误: 使用 Docker Hub 时需要指定 --hub-user <username>"
    exit 1
  fi
  REGISTRY="$HUB_USER"
  echo "==> 使用 Docker Hub registry: $REGISTRY"
else
  REGISTRY="localhost:5000"
  echo "==> 本地模式: registry=$REGISTRY"
fi

# ---------- 构建镜像 ----------
SERVICES_LIST=(user-service group-service message-service connector-service push-service storage-service)

build_and_load() {
  local img="$1"
  local context="$2"

  echo "  构建 $img ..."
  docker build -t "$img" "$context"

  if [[ "$REGISTRY_TYPE" == "dockerhub" ]]; then
    docker push "$img"
  else
    local new_id mk_id
    new_id=$(docker inspect --format='{{.Id}}' "$img" 2>/dev/null || true)
    mk_id=$(minikube ssh -- docker inspect --format='{{.Id}}' "$img" 2>/dev/null | tr -d '\r' || true)
    if [[ -n "$mk_id" && "$mk_id" == "$new_id" ]]; then
      echo "  minikube 已有最新镜像，跳过 load: $img"
    else
      echo "  加载到 minikube: $img ..."
      minikube image load "$img"
    fi
  fi
}

build_images() {
  echo "==> 构建应用镜像..."
  if [[ "$REGISTRY_TYPE" == "dockerhub" ]]; then
    docker login
  fi

  for svc in "${SERVICES_LIST[@]}"; do
    build_and_load "$REGISTRY/$svc:latest" "$ROOT_DIR/services/$svc"
  done
  build_and_load "$REGISTRY/frontend:latest" "$ROOT_DIR/frontend"
}

# ---------- 自动认领 kubectl 管理的 PVC ----------
adopt_pvcs_to_helm() {
  local pvcs
  pvcs=$(kubectl get pvc --no-headers -o custom-columns=NAME:.metadata.name 2>/dev/null || true)
  [[ -z "$pvcs" ]] && return 0
  local needs_adopt=false
  for pvc in $pvcs; do
    local manager
    manager=$(kubectl get pvc "$pvc" -o jsonpath='{.metadata.labels.app\.kubernetes\.io/managed-by}' 2>/dev/null || true)
    if [[ "$manager" != "Helm" ]]; then
      needs_adopt=true
      break
    fi
  done
  [[ "$needs_adopt" == false ]] && return 0
  echo "==> 检测到非 Helm 管理的 PVC，自动移交所有权给 Helm (release: $RELEASE_ALL)..."
  for pvc in $pvcs; do
    kubectl label pvc "$pvc" app.kubernetes.io/managed-by=Helm --overwrite
    kubectl annotate pvc "$pvc" \
      meta.helm.sh/release-name="$RELEASE_ALL" \
      meta.helm.sh/release-namespace=default \
      --overwrite
    echo "  ✓ $pvc"
  done
}

# ---------- 清理残留的非 Helm kubectl 资源 ----------
teardown_kubectl() {
  # 检查是否有非 Helm 管理的 deployment/statefulset
  local unmanaged
  unmanaged=$(kubectl get deploy,statefulset --no-headers \
    -o custom-columns=NAME:.metadata.name,MANAGER:.metadata.labels."app\.kubernetes\.io/managed-by" \
    2>/dev/null | grep -v "Helm" | grep -v "^$" | awk '{print $1}' || true)
  [[ -z "$unmanaged" ]] && return 0
  echo "==> 检测到 kubectl 部署的资源，自动清理后切换到 Helm 模式..."
  kubectl delete all --all 2>/dev/null || true
  kubectl delete configmap --all 2>/dev/null || true
}

teardown_kubectl
adopt_pvcs_to_helm

# ---------- 仅当需要部署 services 时才构建 ----------
if [[ -z "$ONLY" || "$ONLY" == "services" ]]; then
  build_images
fi

# ---------- 更新 umbrella chart 依赖 ----------
update_deps() {
  echo "==> 更新 umbrella chart 依赖..."
  helm dependency update "$HELM_DIR/4chat"
}

# ---------- 部署函数 ----------
deploy_middleware() {
  echo "==> 部署中间件 (helm upgrade --install $RELEASE_MIDDLEWARE)..."
  helm upgrade --install "$RELEASE_MIDDLEWARE" "$HELM_DIR/middleware" \
    --wait --timeout 10m \
    --set mysql.rootPassword=root123
  echo "  中间件部署完成"
}

deploy_services() {
  echo "==> 部署业务服务 (helm upgrade --install $RELEASE_SERVICES)..."
  helm upgrade --install "$RELEASE_SERVICES" "$HELM_DIR/services" \
    --wait --timeout 5m \
    --set global.registry="$REGISTRY"

  if [[ "$CLOUD_MIDDLEWARE" == true ]]; then
    echo "    云服务中间件模式：请确保 values 中中间件连接信息正确"
  fi
  echo "  业务服务部署完成"
}

deploy_all() {
  update_deps
  echo "==> 全量部署 (helm upgrade --install $RELEASE_ALL)..."

  EXTRA_SETS=""
  if [[ "$CLOUD_MIDDLEWARE" == true ]]; then
    # 云模式：禁用所有本地中间件
    EXTRA_SETS="$EXTRA_SETS \
      --set middleware.mysql.enabled=false \
      --set middleware.redis.enabled=false \
      --set middleware.kafka.enabled=false \
      --set middleware.nacos.enabled=false \
      --set middleware.scylladb.enabled=false"
    echo "  云服务中间件模式：本地中间件已禁用"
    echo "  请在 helm/4chat/values.yaml 中配置云服务连接信息"
  fi

  helm upgrade --install "$RELEASE_ALL" "$HELM_DIR/4chat" \
    --wait --timeout 15m \
    --set services.global.registry="$REGISTRY" \
    $EXTRA_SETS

  echo "  全量部署完成"
}

# ---------- 执行部署 ----------
case "$ONLY" in
  middleware)
    deploy_middleware
    ;;
  services)
    deploy_services
    ;;
  "")
    deploy_all
    ;;
  *)
    echo "错误: --only 参数只支持 middleware 或 services"
    exit 1
    ;;
esac

# ---------- 输出访问信息 ----------
echo ""
echo "✅ Helm 部署完成！"
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
echo "查看 Helm releases:  helm list"
echo "查看所有 Pod 状态:   kubectl get pods"
echo ""
echo "常用命令："
echo "  helm upgrade $RELEASE_ALL $HELM_DIR/4chat --reuse-values   # 升级"
echo "  ./k8s/helm-deploy.sh --uninstall                           # 卸载"
