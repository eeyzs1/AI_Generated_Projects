import React, { createContext, useContext, useEffect, useState, ReactNode } from 'react';
import type { WSMessage } from './types';

interface WebSocketContextType {
  ws: WebSocket | null;
  isConnected: boolean;
  onlineUsers: number[];
  sendMessage: (data: any) => void;
  onMessage: (callback: (message: WSMessage) => void) => () => void;
}

const WebSocketContext = createContext<WebSocketContextType | undefined>(undefined);

export const WebSocketProvider: React.FC<{ children: ReactNode }> = ({ children }) => {
  const [ws, setWs] = useState<WebSocket | null>(null);
  const [isConnected, setIsConnected] = useState(false);
  const [onlineUsers, setOnlineUsers] = useState<number[]>([]);
  const messageCallbacks = new Set<(message: WSMessage) => void>();

  const connect = () => {
    const token = localStorage.getItem('token');
    if (!token) return;

    const wsUrl = `ws://localhost:8000/ws/${token}`;
    const websocket = new WebSocket(wsUrl);

    websocket.onopen = () => {
      setIsConnected(true);
      console.log('WebSocket connected');
    };

    websocket.onclose = () => {
      setIsConnected(false);
      console.log('WebSocket disconnected');
      // 5秒后尝试重连
      setTimeout(connect, 5000);
    };

    websocket.onerror = (error) => {
      console.error('WebSocket error:', error);
    };

    websocket.onmessage = (event) => {
      const message: WSMessage = JSON.parse(event.data);

      // 通知所有监听器
      messageCallbacks.forEach(callback => callback(message));

      // 处理在线用户更新
      if (message.type === 'online_users') {
        setOnlineUsers(message.data.user_ids || []);
      }
    };

    setWs(websocket);
  };

  const disconnect = () => {
    if (ws) {
      ws.close();
      setWs(null);
    }
  };

  const sendMessage = (data: any) => {
    if (ws && ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify(data));
    }
  };

  const onMessage = (callback: (message: WSMessage) => void) => {
    messageCallbacks.add(callback);
    return () => {
      messageCallbacks.delete(callback);
    };
  };

  useEffect(() => {
    connect();

    return () => {
      disconnect();
    };
  }, []);

  const value: WebSocketContextType = {
    ws,
    isConnected,
    onlineUsers,
    sendMessage,
    onMessage,
  };

  return <WebSocketContext.Provider value={value}>{children}</WebSocketContext.Provider>;
};

export const useWebSocket = () => {
  const context = useContext(WebSocketContext);
  if (!context) {
    throw new Error('useWebSocket must be used within WebSocketProvider');
  }
  return context;
};
