#!/bin/bash
# WSL2 mirror 模式下 Docker 端口转发脚本
# 解决 Windows 浏览器无法通过 localhost 访问 Docker 容器的问题
# 用法: ./forward-ports.sh [start|stop]

ACTION=${1:-start}

# 端口映射: "容器名:win访问端口:容器内端口:说明"
# win访问端口留空则自动在容器端口前加1（如3000→13000）
PORTS=(
  "im-frontend:13000:3000:前端"
  "im-apisix:8080:9080:APISIX网关"
  "im-nacos:18848:8848:Nacos控制台"
  "im-user-service:18001:8001:user-service"
  "im-group-service:18002:8002:group-service"
  "im-message-service:18003:8003:message-service"
  "im-connector-service:18004:8004:connector-service"
  "im-push-service:18005:8005:push-service"
  "im-storage-service:18006:8006:storage-service"
)

PIDFILE="/tmp/socat-forwards.pids"

get_container_ip() {
    docker inspect "$1" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null
}

start_forwards() {
    if [ -f "$PIDFILE" ]; then
        echo "转发已在运行，请先执行 stop"
        exit 1
    fi

    # 检查 socat 是否安装
    if ! command -v socat &>/dev/null; then
        echo "安装 socat..."
        sudo apt-get install -y socat
    fi

    echo "" > "$PIDFILE"

    for entry in "${PORTS[@]}"; do
        IFS=':' read -r container_name listen_port container_port desc <<< "$entry"

        container_ip=$(get_container_ip "$container_name")
        if [ -z "$container_ip" ]; then
            echo "⚠️  跳过 $desc ($container_name) — 容器未运行"
            continue
        fi

        win_port="${listen_port}"
        socat TCP4-LISTEN:${win_port},fork,reuseaddr TCP4:${container_ip}:${container_port} &
        echo $! >> "$PIDFILE"
        echo "✅ $desc: localhost:${win_port} → ${container_ip}:${container_port}"
    done

    echo ""
    echo "所有转发已启动，PID 保存在 $PIDFILE"
    echo "停止所有转发: ./forward-ports.sh stop"
}

stop_forwards() {
    if [ ! -f "$PIDFILE" ]; then
        echo "没有找到运行中的转发"
        exit 0
    fi

    while read -r pid; do
        [ -z "$pid" ] && continue
        if kill "$pid" 2>/dev/null; then
            echo "已停止 PID $pid"
        fi
    done < "$PIDFILE"

    rm -f "$PIDFILE"
    echo "所有转发已停止"
}

case "$ACTION" in
    start) start_forwards ;;
    stop)  stop_forwards ;;
    *)
        echo "用法: $0 [start|stop]"
        exit 1
        ;;
esac
