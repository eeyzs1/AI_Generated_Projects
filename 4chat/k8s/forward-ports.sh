#!/bin/bash
# Kubernetes (minikube) 端口转发脚本
# WSL 环境下让 Windows 浏览器访问 K8s 服务
# 用法: ./k8s/forward-ports.sh [start|stop]

ACTION=${1:-start}
PIDFILE="/tmp/k8s-port-forwards.pids"

start_forwards() {
    if [ -f "$PIDFILE" ]; then
        echo "转发已在运行，请先执行 stop"
        exit 1
    fi

    echo "" > "$PIDFILE"

    # 前端
    kubectl port-forward service/frontend 13000:3000 --address=0.0.0.0 &
    echo $! >> "$PIDFILE"
    echo "✅ 前端: http://localhost:13000"

    # API 网关
    kubectl port-forward service/apisix 8080:9080 --address=0.0.0.0 &
    echo $! >> "$PIDFILE"
    echo "✅ API 网关: http://localhost:8080"

    # Nacos 控制台（可选）
    kubectl port-forward service/nacos 18848:8848 --address=0.0.0.0 &
    echo $! >> "$PIDFILE"
    echo "✅ Nacos: http://localhost:18848/nacos"

    echo ""
    echo "所有转发已启动，PID 保存在 $PIDFILE"
    echo "停止所有转发: ./k8s/forward-ports.sh stop"
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
