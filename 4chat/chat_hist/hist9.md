# 对话记录 hist9 — WSL2 + Docker 端口访问问题排查全记录

## 问题一：Windows 浏览器无法访问 localhost:3000

### 现象
- WSL 内 `curl http://localhost:3000` 返回 200 正常
- Windows 浏览器访问 `localhost:3000` 显示 `ERR_CONNECTION_TIMED_OUT`

### 排查过程

1. **确认前端容器正常**：`docker logs im-frontend` 显示 nginx 启动了 60 个 worker，完全正常
2. **确认端口绑定正常**：`ss -tlnp | grep 3000` 显示 `0.0.0.0:3000` 在监听
3. **确认 WSL mirror 模式**：`/etc/wsl.conf` 显示 `networkingMode=Mirrored`
4. **尝试 localhostForwarding**：在 `.wslconfig` 加 `localhostForwarding=true` 后重启 WSL，无效
5. **用 WSL IP 访问**：`192.168.123.50:3000` Windows 浏览器也无法访问
6. **PowerShell 测试**：`Test-NetConnection -ComputerName 192.168.123.50 -Port 3000` 返回 `TcpTestSucceeded: False`
7. **加 Windows 防火墙规则**：`New-NetFirewallRule` 允许 3000 端口入站，仍然无效
8. **tcpdump 抓包**：发现包已经到达 WSL，DNAT 也转发到了容器，但容器回包后立刻收到 RST

### 根本原因：Hairpin NAT 问题

```
Windows 发包：源IP=192.168.123.50, 目标IP=192.168.123.50:3000
DNAT转发：    目标改为 172.18.0.16:3000
容器回包：    源IP=192.168.123.50, 目标IP=192.168.123.50
内核判断：    源IP==目标IP，异常，发送 RST 重置连接
```

WSL2 mirror 模式下，Docker 容器端口通过 iptables DNAT 转发，Windows 发来的包源 IP 和目标 IP 相同（都是 WSL 的 IP），内核认为这是异常连接并 RST。

### 尝试的修复方案（均失败）

1. `iptables -t nat -I POSTROUTING -s 192.168.123.0/24 -d 172.18.0.0/16 -j MASQUERADE`：源 IP 变成 `172.18.0.1`，但 conntrack 记录不匹配，仍然 RST
2. `iptables -t nat -I POSTROUTING -s 127.0.0.1 -d 172.18.0.0/16 -j MASQUERADE`：loopback 地址不走 POSTROUTING，无效
3. `netsh interface portproxy`：Docker 端口不是普通进程监听，WSL localhost 转发识别不了

### 最终解决方案：socat 端口转发

```bash
socat TCP-LISTEN:13000,fork,reuseaddr TCP:172.18.0.16:3000 &
```

用不同端口（原端口加 `1` 前缀）监听，把流量转到容器 IP，绕开 hairpin NAT：
- Windows 访问 `localhost:13000` → socat → 容器 `172.18.0.16:3000`
- 流量从 socat 出去时源 IP 是 `127.0.0.1`，容器回包正常

---

## 问题二：socat 绑端口失败（Address already in use）

### 现象
```
socat[xxx] E bind(5, {AF=2 0.0.0.0:8080}, 16): Address already in use
```

### 原因
Linux 内核规定：**`0.0.0.0` 绑定包含所有地址，与 `127.0.0.1` 绑同一端口会冲突**。Docker 已经绑了 `127.0.0.1:8080`，socat 无法再绑 `0.0.0.0:8080`。

### 解决方案
让 socat 监听在不同端口（原端口前加 `1`），Windows 用新端口访问：

| 服务 | Docker 绑定 | Windows 访问 |
|------|------------|-------------|
| 前端 | 3000 | localhost:13000 |
| APISIX | 8080 | localhost:18080 |
| user-service | 8001 | localhost:18001 |
| ... | ... | ... |

---

## 问题三：前端代码写死 localhost:8080

### 现象
前端所有 API 请求都写死为 `http://localhost:8080/api/...`，WebSocket 写死为 `ws://localhost:8080/ws/...`，而 Windows 实际需要通过不同端口访问。

### 根本原因
前端代码没有使用环境变量或相对路径，所有文件（App.tsx、ChatRoom.tsx、MainLayout.tsx 等）都硬编码了地址。

### 解决方案
将所有 `http://localhost:8080` 改为相对路径，nginx.conf 在同一 server block 内代理 `/api/` 和 `/ws/` 到后端服务：

```nginx
server {
    listen 3000;
    root /usr/share/nginx/html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://apisix:9080;
        ...
    }

    location /ws/ {
        proxy_pass http://apisix:9080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

这样前端和 API 都走同一端口（13000），不再依赖 8080。

---

## 问题四：APISIX 启动失败

### 错误信息
```
Error: /usr/local/apisix/conf/config.yaml does not contain 'role: data_plane'.
Deployment role must be set to 'data_plane' for standalone mode.
```

### 原因
APISIX 3.x 版本要求在 `config.yaml` 中明确声明部署角色为 `data_plane`（standalone 模式）。

### 解决方案
在 `apisix/config.yaml` 中添加：
```yaml
deployment:
  role: data_plane
  role_data_plane:
    config_provider: yaml
```

---

## 问题五：push-service / connector-service 启动失败

### push-service 错误
```
sqlalchemy.exc.ArgumentError: Could not parse SQLAlchemy URL from given URL string
```
ha_database.py 第 19 行尝试创建 SQLAlchemy engine，但 `DATABASE_URL` 环境变量未设置或格式错误。

### connector-service 错误
```
File "/usr/local/lib/python3.11/site-packages/jose.py", line 546
    print decrypt(...)
SyntaxError: Missing parentheses in call to 'print'
```
安装了错误的 `jose` 包（Python 2 时代的旧版本），应该安装 `python-jose`。

### 解决方案
- push-service：确保 `DATABASE_URL` 环境变量正确设置，或修改 ha_database.py 使其在无 DB 时跳过初始化
- connector-service：`requirements.txt` 中将 `jose` 改为 `python-jose`

---

## 总结：WSL2 mirror 模式 + 原生 Docker 的端口访问方案

```
Windows 浏览器
    ↓ localhost:13000
socat（WSL 内运行）
    ↓ 172.18.0.x:3000（容器IP）
Docker 容器
    ↓ 内部转发
后端服务
```

**关键结论：**
1. WSL2 mirror 模式下，`localhostForwarding` 对 Docker 容器端口无效
2. Docker 容器端口通过 iptables DNAT 转发，存在 hairpin NAT 问题
3. socat 用不同端口监听，直连容器 IP，是最简洁的绕过方案
4. `0.0.0.0` 和 `127.0.0.1` 绑同一端口会冲突，socat 需要用不同端口
5. 前端代码应使用相对路径 + nginx 反向代理，避免硬编码地址
