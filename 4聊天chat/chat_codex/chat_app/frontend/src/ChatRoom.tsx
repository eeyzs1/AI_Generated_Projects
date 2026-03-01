import { FormEvent, useEffect, useRef, useState } from "react";

import { Message, Room, UserSummary } from "./types";

const API_BASE = import.meta.env.VITE_API_BASE_URL ?? "http://localhost:8000";
const WS_BASE = API_BASE.replace("http", "ws");

interface ChatRoomProps {
  room: Room;
  token: string;
  messages: Message[];
  onMessages: (items: Message[]) => void;
  onMessage: (message: Message) => void;
  onUsers: (users: UserSummary[]) => void;
}

const ChatRoom = ({ room, token, messages, onMessages, onMessage, onUsers }: ChatRoomProps) => {
  const [input, setInput] = useState("");
  const [connected, setConnected] = useState(false);
  const socketRef = useRef<WebSocket | null>(null);
  const endRef = useRef<HTMLDivElement | null>(null);

  const messagesHandler = useRef(onMessages);
  const messageHandler = useRef(onMessage);
  const usersHandler = useRef(onUsers);

  useEffect(() => {
    messagesHandler.current = onMessages;
  }, [onMessages]);

  useEffect(() => {
    messageHandler.current = onMessage;
  }, [onMessage]);

  useEffect(() => {
    usersHandler.current = onUsers;
  }, [onUsers]);

  useEffect(() => {
    if (!room?.id || !token) {
      return;
    }
    const ws = new WebSocket(`${WS_BASE}/ws/rooms/${room.id}?token=${token}`);
    socketRef.current = ws;
    ws.onopen = () => setConnected(true);
    ws.onmessage = (event) => {
      const payload = JSON.parse(event.data);
      switch (payload.event) {
        case "history":
          messagesHandler.current(payload.data ?? []);
          break;
        case "message":
          messageHandler.current(payload.data);
          break;
        case "users":
          usersHandler.current(payload.data ?? []);
          break;
        default:
          break;
      }
    };
    ws.onclose = () => setConnected(false);
    return () => {
      ws.close();
      socketRef.current = null;
      setConnected(false);
    };
  }, [room.id, token]);

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  const sendMessage = (event: FormEvent) => {
    event.preventDefault();
    const content = input.trim();
    if (!content || !socketRef.current || socketRef.current.readyState !== WebSocket.OPEN) {
      return;
    }
    socketRef.current.send(JSON.stringify({ content }));
    setInput("");
  };

  return (
    <div className="card" style={{ flex: 1, display: "flex", flexDirection: "column" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <div>
          <h2 style={{ margin: 0 }}>{room.name}</h2>
          <small>{connected ? "已连接" : "未连接"}</small>
        </div>
      </div>
      <div
        style={{
          flex: 1,
          overflowY: "auto",
          margin: "1rem 0",
          padding: "1rem",
          background: "#f0f4f8",
          borderRadius: "6px",
        }}
      >
        {messages.map((message) => (
          <div key={message.id} style={{ marginBottom: "0.75rem" }}>
            <strong>{message.sender.username}</strong>
            <span style={{ fontSize: "0.8rem", color: "#616e7c", marginLeft: "0.5rem" }}>
              {message.created_at ? new Date(message.created_at).toLocaleTimeString() : "刚刚"}
            </span>
            <div>{message.content}</div>
          </div>
        ))}
        <div ref={endRef} />
      </div>
      <form onSubmit={sendMessage} style={{ display: "flex", gap: "0.5rem" }}>
        <input
          style={{ flex: 1 }}
          placeholder="输入消息"
          value={input}
          onChange={(e) => setInput(e.target.value)}
        />
        <button type="submit" disabled={!connected}>
          发送
        </button>
      </form>
    </div>
  );
};

export default ChatRoom;
