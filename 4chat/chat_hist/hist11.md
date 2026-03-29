# 对话历史 #11 - Helm Chart 部署方案 + 镜像加载优化

## 日期
2026-03-29

## 主要任务
为 4Chat 项目添加 Helm 包管理支持，优化镜像加载逻辑，增强部署脚本功能。

## 完成的工作

### 1. Helm Chart 架构设计

创建了三层 Helm Chart 结构：

**独立 Chart：**
- `helm/middleware/` - 中间件 chart（MySQL/Redis/Kafka/Nacos/ScyllaDB）
- `helm/services/` - 业务服务 chart（6个微服务 + 前端 + APISIX）

**Umbrella Chart：**
- `helm/4chat/` - 顶层 chart，依赖上述两个子 chart，一键部署全套

**设计优势：**
- 可以独立部署中间件或服务
- 可以通过 umbrella chart 一键部署全部
- 通过 `enabled: true/false` 灵活控制组件开关

---

### 2. Helm Chart 文件清单

#### helm/middleware/
- `Chart.yaml` - Chart 元数据
- `values.yaml` - 默认配置（镜像版本、存储大小、密码等）
- `templates/_helpers.tpl` - 通用标签模板
- `templates/mysql.yaml` - MySQL StatefulSet + PVC + ConfigMap
- `templates/redis.yaml` - Redis Deployment
- `templates/kafka.yaml` - Kafka + Zookeeper Deployment + ConfigMap
- `templates/nacos.yaml` - Nacos Deployment + PVC
- `templates/scylladb.yaml` - ScyllaDB StatefulSet + PVC

#### helm/services/
- `Chart.yaml`
- `values.yaml` - 镜像 registry、副本数、环境变量
- `templates/_helpers.tpl` - 镜像地址构建函数
- `templates/user-service.yaml` (+ 其他5个服务)
- `templates/frontend.yaml`
- `templates/gateway/apisix.yaml`

#### helm/4chat/
- `Chart.yaml` - 依赖 middleware + services
- `values.yaml` - 全局配置覆盖
- `templates/_helpers.tpl`

---

### 3. 镜像加载优化

**问题：**
- 每次运行 `deploy.sh` 或 `helm-deploy.sh` 都会无条件 `minikube image load`
- 即使镜像未变化，也要等待几分钟加载

**解决方案：**
实现智能镜像 ID 比对，跳过重复加载：

```bash
build_and_load() {
  docker build -t "$img" "$context"
  new_id=$(docker inspect --format='{{.Id}}' "$img")
  mk_id=$(minikube ssh -- docker inspect --format='{{.Id}}' "$img" | tr -d '\r')
  if [[ "$mk_id" == "$new_id" ]]; then
    echo "  minikube 已有最新镜像，跳过 load"
  else
    minikube image load "$img"
  fi
}
```

**关键点：**
- 用 `minikube ssh -- docker inspect` 获取 minikube 内镜像 ID
- `tr -d '\r'` 去除 Windows 换行符
- ID 一致则跳过，不一致才 load

**同步到：**
- `k8s/deploy.sh`
- `k8s/helm-deploy.sh`

---

### 4. PVC 所有权自动转换

**问题：**
- `deploy.sh` (kubectl) 和 `helm-deploy.sh` 切换时，PVC 所有权冲突
- Helm 要求 PVC 有 `app.kubernetes.io/managed-by=Helm` 标签
- kubectl 创建的 PVC 没有这些标签，导致 Helm install 失败

**解决方案：**
两个脚本启动时自动检测并转换 PVC 所有权：

**deploy.sh 启动时：**
1. 检测是否有 Helm releases，有则自动卸载
2. 移除所有 PVC 的 Helm 标签和注解

**helm-deploy.sh 启动时：**
1. 检测是否有非 Helm 管理的资源，有则清理
2. 给所有 PVC 打上 Helm 标签和注解

**用户体验：**
- 直接跑对应脚本即可，无需手动清理
- 数据不丢失（PVC 保留）

---

### 5. 部署脚本功能增强

为两个脚本都添加了 `--restart` 和 `--update` 功能：

#### --restart（滚动重启）
```bash
./k8s/deploy.sh --restart
./k8s/helm-deploy.sh --restart
```
- 重启所有 Deployment 和 StatefulSet
- 不重新构建镜像
- 用于配置变更后生效

#### --update（智能更新）
```bash
# 自动检测所有服务变更
./k8s/deploy.sh --update
./k8s/helm-deploy.sh --update

# 只更新指定服务
./k8s/deploy.sh --update user-service
./k8s/helm-deploy.sh --update frontend
```

**工作原理：**
1. 对每个服务执行 `docker build`
2. 比对构建后的镜像 ID 和 minikube 内的 ID
3. ID 不同 → 有变更 → load 镜像 + rollout restart
4. ID 相同 → 无变更 → 跳过

---

### 6. 部署脚本命令对比

| 功能 | deploy.sh | helm-deploy.sh |
|------|-----------|----------------|
| 全量部署 | `./k8s/deploy.sh` | `./k8s/helm-deploy.sh` |
| 卸载 | `./k8s/deploy.sh --uninstall` | `./k8s/helm-deploy.sh --uninstall` |
| 滚动重启 | `./k8s/deploy.sh --restart` | `./k8s/helm-deploy.sh --restart` |
| 智能更新 | `./k8s/deploy.sh --update` | `./k8s/helm-deploy.sh --update` |
| 单服务更新 | `./k8s/deploy.sh --update user-service` | `./k8s/helm-deploy.sh --update frontend` |
| Docker Hub | `--registry dockerhub --hub-user <user>` | `--registry dockerhub --hub-user <user>` |
| 云中间件 | `--cloud` | `--cloud` |

---

### 7. Helm 使用方式

**独立部署：**
```bash
# 只部署中间件
helm upgrade --install 4chat-middleware helm/middleware

# 只部署业务服务
helm upgrade --install 4chat-services helm/services

# 全量部署
helm upgrade --install 4chat helm/4chat
```

**一键脚本：**
```bash
# 本地 registry（默认）
./k8s/helm-deploy.sh

# Docker Hub
./k8s/helm-deploy.sh --registry dockerhub --hub-user myuser

# 云服务中间件
./k8s/helm-deploy.sh --cloud

# 卸载
./k8s/helm-deploy.sh --uninstall
```

---

### 8. 切换部署方式

**kubectl → Helm（数据不丢）：**
```bash
./k8s/helm-deploy.sh
# 自动清理 kubectl 资源，认领 PVC
```

**Helm → kubectl（数据不丢）：**
```bash
./k8s/deploy.sh
# 自动卸载 Helm releases，移除 PVC Helm 标记
```

---

## 关键技术点

### 1. Helm Chart 模板化
- 使用 `{{ .Values.xxx }}` 引用配置
- `{{- if .Values.xxx.enabled }}` 条件渲染
- `{{ include "services.image" (list . .Values.xxx.image) }}` 函数调用

### 2. minikube 镜像管理
- `minikube ssh -- docker inspect` 获取 VM 内镜像信息
- `tr -d '\r'` 处理 Windows 换行符
- 镜像 ID 比对避免重复加载

### 3. K8s 资源所有权
- `app.kubernetes.io/managed-by` 标签标识管理工具
- `meta.helm.sh/release-name` 注解标识 Helm release
- kubectl 和 Helm 通过标签/注解识别资源归属

### 4. Bash 脚本技巧
- `[[ -n "$var" && "$var" == "$other" ]]` 安全比对
- `kubectl get xxx -o jsonpath='{.metadata.labels.xxx}'` 提取字段
- `2>/dev/null || true` 忽略错误继续执行

---

## 遇到的问题及解决

### 问题1：minikube image inspect 不存在
**现象：** `mk_id` 永远为空，跳过逻辑不生效

**原因：** minikube 没有 `image inspect` 子命令

**解决：** 改用 `minikube ssh -- docker inspect`

---

### 问题2：ID 比对永远不相等
**现象：** 即使 ID 看起来一样，`[[ "$mk_id" == "$new_id" ]]` 返回 false

**原因：** `minikube ssh` 输出末尾有 `\r` (Windows 换行符)

**解决：** 加 `tr -d '\r'` 过滤

---

### 问题3：Helm install 报 PVC ownership 错误
**现象：**
```
invalid ownership metadata; label validation error: missing key "app.kubernetes.io/managed-by"
```

**原因：** kubectl 创建的 PVC 没有 Helm 标签

**解决：** 脚本启动时自动给 PVC 打标签

---

## 文件变更清单

### 新建文件
- `helm/middleware/Chart.yaml`
- `helm/middleware/values.yaml`
- `helm/middleware/templates/_helpers.tpl`
- `helm/middleware/templates/*.yaml` (5个中间件)
- `helm/services/Chart.yaml`
- `helm/services/values.yaml`
- `helm/services/templates/_helpers.tpl`
- `helm/services/templates/*.yaml` (7个服务 + 网关)
- `helm/4chat/Chart.yaml`
- `helm/4chat/values.yaml`
- `helm/4chat/templates/_helpers.tpl`
- `k8s/helm-deploy.sh`

### 修改文件
- `k8s/deploy.sh` - 添加镜像 ID 比对、PVC 转换、--restart、--update、--uninstall
- `k8s/helm-deploy.sh` - 同上

### 删除文件
- `k8s/adopt-pvcs.sh` - 功能已内置到两个脚本

---

## 验证结果

**Helm lint 通过：**
```bash
helm lint helm/middleware  # 0 failed
helm lint helm/services    # 0 failed
helm lint helm/4chat       # 0 failed
```

**模板渲染正常：**
```bash
helm template 4chat-test helm/4chat | grep "^kind:" | sort | uniq -c
     14 kind: Service
     12 kind: Deployment
      3 kind: PersistentVolumeClaim
      3 kind: ConfigMap
      2 kind: StatefulSet
```

**镜像加载优化生效：**
- 首次部署：正常 load 所有镜像
- 二次部署（代码未变）：全部跳过 load，节省 5+ 分钟

**PVC 自动转换生效：**
- kubectl → Helm：自动认领 PVC，数据保留
- Helm → kubectl：自动移除标签，数据保留

---

## 经验总结

1. **Helm Chart 设计原则**
   - 独立 chart 提供灵活性
   - Umbrella chart 提供便利性
   - 通过 `enabled` 开关控制组件

2. **镜像管理优化**
   - 比对 Image ID 而非名称
   - 跳过重复加载节省大量时间
   - 注意跨平台换行符问题

3. **工具切换平滑性**
   - 自动检测当前状态
   - 自动转换资源所有权
   - 保留数据避免丢失

4. **脚本功能增强**
   - `--restart` 快速重启
   - `--update` 智能增量更新
   - 减少用户操作步骤

5. **Bash 脚本健壮性**
   - 变量比对前检查非空
   - 命令失败时优雅降级
   - 提供清晰的用户提示
