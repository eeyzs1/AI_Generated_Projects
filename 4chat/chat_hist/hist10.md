# 对话历史 #10 - Kubernetes (minikube) 部署问题排查与修复

## 日期
2026-03-28

## 主要任务
在 minikube 环境下部署 4Chat 项目，遇到多个中间件启动失败问题，逐一排查并修复。

## 遇到的问题及解决方案

### 1. Kafka 启动失败 - `port is deprecated` 错误

**现象：**
- Kafka pod 反复 CrashLoopBackOff
- 日志只显示 `port is deprecated. Please use KAFKA_ADVERTISED_LISTENERS instead.` 后立即退出

**根本原因：**
- Kubernetes 自动为同 namespace 的 pod 注入环境变量
- 因为存在名为 `kafka` 的 Service，K8s 自动注入了 `KAFKA_PORT=tcp://10.99.220.148:9092`
- Confluent Kafka 镜像的启动脚本检测到 `KAFKA_PORT` 环境变量，认为使用了废弃配置，直接 `exit 1`

**解决方案：**
在 `k8s/middleware/kafka.yaml` 的 Deployment spec 中添加：
```yaml
spec:
  template:
    spec:
      enableServiceLinks: false  # 禁用自动注入服务环境变量
```

**额外修复：**
- 添加 `securityContext.runAsUser: 0` 解决日志文件权限问题
- 使用 `confluentinc/cp-zookeeper` 镜像作为 init container 替代 busybox（避免额外拉取）
- 添加 ConfigMap 提供自定义 log4j 配置

---

### 2. Nacos v3 启动失败

**现象：**
- Nacos pod CrashLoopBackOff
- 日志显示 `env NACOS_AUTH_TOKEN must be set with Base64 String.`

**根本原因：**
- Nacos v3.1.1 强制要求设置 `NACOS_AUTH_TOKEN` 环境变量
- 必须是 Base64 编码的字符串

**解决方案：**
在 `k8s/middleware/nacos.yaml` 中添加环境变量：
```yaml
env:
  - name: NACOS_AUTH_ENABLE
    value: "false"
  - name: NACOS_AUTH_TOKEN
    value: "U2VjcmV0S2V5MDEyMzQ1Njc4OTAxMjM0NTY3ODkwMTIzNDU2Nzg5MDEyMzQ1Njc4OTAxMjM0NTY3ODkwMTIzNDU2Nzg5"
```

**Readiness Probe 修复：**
- Nacos v3 的健康检查路径已变更
- 原路径 `/nacos/v1/console/health/readiness` 返回 410 Gone
- 改用 tcpSocket 检查 8848 端口：
```yaml
readinessProbe:
  tcpSocket:
    port: 8848
  initialDelaySeconds: 30
```

---

### 3. message-service 启动失败 - ScyllaDB 未部署

**现象：**
- message-service pod Error 状态
- 日志显示 `cassandra.UnresolvableContactPoints: {}`

**根本原因：**
- deploy.sh 脚本遗漏了 ScyllaDB 的部署步骤
- message-service 依赖 ScyllaDB 存储消息

**解决方案：**
在 `k8s/deploy.sh` 中添加：
```bash
kubectl apply -f "$ROOT_DIR/k8s/middleware/scylladb.yaml"
kubectl wait --for=condition=ready pod -l app=scylladb --timeout=180s
```

---

### 4. APISIX 启动失败 - 配置错误

**现象：**
- apisix pod CrashLoopBackOff
- 日志显示 `role must be set to 'data_plane' for standalone mode`

**根本原因：**
- APISIX 3.x 在 standalone 模式下要求显式声明 `role: data_plane`
- 原配置使用了 `role: traditional`

**解决方案：**
修改 `k8s/gateway/apisix.yaml` 的 ConfigMap：
```yaml
deployment:
  role: data_plane
  role_data_plane:
    config_provider: yaml
```

---

### 5. 镜像拉取失败 - minikube 网络问题

**现象：**
- 多个 pod ImagePullBackOff
- 错误信息：`context deadline exceeded` 或 `net/http: request canceled`

**根本原因：**
- minikube 是独立的虚拟机，有自己的网络栈
- 即使 WSL 配置了代理，minikube 也无法访问
- minikube 无法直接访问 Docker Hub

**解决方案：**
更新 `k8s/deploy.sh`，实现智能镜像加载：
```bash
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
```

**中间件镜像预加载：**
```bash
MIDDLEWARE_IMAGES=(
  "mysql:8.4"
  "redis:8-alpine"
  "confluentinc/cp-zookeeper:7.9.6"
  "confluentinc/cp-kafka:7.9.6"
  "nacos/nacos-server:v3.1.1-slim"
  "scylladb/scylla:6.2"
  "apache/apisix:3.15.0-ubuntu"
)
```

---

### 6. frontend 和业务服务 imagePullPolicy 问题

**现象：**
- 镜像已经 load 到 minikube，但 pod 还是 ImagePullBackOff
- K8s 尝试从 `localhost:5000` registry 拉取

**根本原因：**
- yaml 文件中设置了 `imagePullPolicy: Never`
- 但 deployment 实际运行时是 `Always`
- 说明之前的 `kubectl apply` 没有生效

**解决方案：**
使用 `kubectl patch` 强制更新：
```bash
kubectl patch deployment frontend -p '{"spec":{"template":{"spec":{"containers":[{"name":"frontend","imagePullPolicy":"Never"}]}}}}'
```

---

### 7. WSL 环境下 Windows 浏览器无法访问

**现象：**
- minikube 服务正常运行
- WSL 内可以访问
- Windows 浏览器无法访问 `minikube ip` 或 `localhost`

**根本原因：**
- minikube 运行在 Docker 容器内，网络与 Windows 隔离
- NodePort 方式需要访问 minikube VM 的 IP，Windows 无法直接路由

**解决方案：**
创建 `k8s/forward-ports.sh` 使用 `kubectl port-forward`：
```bash
kubectl port-forward service/frontend 13000:3000 --address=0.0.0.0 &
kubectl port-forward service/apisix 8080:9080 --address=0.0.0.0 &
```

Windows 浏览器访问 `http://localhost:13000`

---

## 最终修改的文件

### 1. k8s/deploy.sh
- 镜像名改为 `localhost:5000/` 与 yaml 匹配
- 新增 `load_image_if_needed()` 函数
- 新增中间件镜像预加载
- 新增 ScyllaDB 部署
- 新增 apisix 就绪等待
- 部署完成后提示端口转发命令

### 2. k8s/middleware/kafka.yaml
- 添加 `enableServiceLinks: false`
- 添加 `securityContext.runAsUser: 0`
- 添加 log4j ConfigMap
- init container 改用 cp-zookeeper 镜像

### 3. k8s/middleware/nacos.yaml
- 添加 `NACOS_AUTH_TOKEN` 环境变量
- readiness probe 改为 tcpSocket

### 4. k8s/gateway/apisix.yaml
- `role: traditional` 改为 `role: data_plane`

### 5. k8s/forward-ports.sh（新建）
- minikube 专用端口转发脚本
- 支持 start/stop 操作

### 6. README.md
- 新增 K8s 常见问题章节
- 记录所有问题和解决方案

---

## 关键经验总结

1. **K8s 环境变量注入机制**
   - Service 会自动注入 `<SERVICE_NAME>_PORT` 等环境变量
   - 可能与应用启动脚本冲突
   - 使用 `enableServiceLinks: false` 禁用

2. **minikube 镜像管理**
   - minikube 有独立的 Docker daemon
   - 宿主机镜像需要显式 load
   - 优先尝试 pull，失败再 load

3. **中间件版本升级注意事项**
   - Nacos v3 强制要求认证配置
   - APISIX 3.x 要求显式声明 deployment role
   - 升级前需查阅 breaking changes

4. **WSL + minikube 网络**
   - minikube 网络与 Windows 隔离
   - 使用 `kubectl port-forward` 暴露服务
   - `--address=0.0.0.0` 允许 Windows 访问

5. **K8s 部署调试技巧**
   - `kubectl describe pod` 查看事件
   - `kubectl logs --previous` 查看崩溃前日志
   - `kubectl exec` 进入容器调试
   - `minikube ssh` 检查 VM 内部状态

---

## 部署验证

最终所有服务成功运行：
```
NAME                                READY   STATUS    RESTARTS   AGE
kafka-676b58fc78-h98qz              1/1     Running   0          3h26m
mysql-0                             1/1     Running   0          8h
nacos-75d6cf6db4-qntrm              1/1     Running   0          5m20s
redis-6c5b9785cf-vw27t              1/1     Running   0          8h
scylladb-0                          1/1     Running   0          85s
zookeeper-65d947dd4b-9sg5c          1/1     Running   0          6h32m
apisix-9ddb97fcf-q7x6p              1/1     Running   0          10m
connector-service-bbf9b8675-56zdn   1/1     Running   0          23m
frontend-798f5b4d6b-ltkhw           1/1     Running   0          10s
group-service-55445fcdd4-x4x72      1/1     Running   0          23m
message-service-6dc6bd4d6-cxvr7     1/1     Running   0          2m
push-service-559b775bcd-zj4fc       1/1     Running   0          23m
storage-service-68745bc779-98t7v    1/1     Running   0          23m
user-service-565476949b-zf6d5       1/1     Running   0          23m
```

Windows 浏览器成功访问 `http://localhost:13000`
