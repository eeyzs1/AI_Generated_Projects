import axios from "axios";
import { FormEvent, useCallback, useEffect, useMemo, useState } from "react";

import ChatRoom from "./ChatRoom";
import Login from "./Login";
import Register from "./Register";
import UserList from "./UserList";
import { Message, Room, UserSummary } from "./types";

const API_BASE = import.meta.env.VITE_API_BASE_URL ?? "http://localhost:8000";

const App = () => {
  const [token, setToken] = useState<string | null>(() => localStorage.getItem("chat_token"));
  const [currentUser, setCurrentUser] = useState<UserSummary | null>(null);
  const [rooms, setRooms] = useState<Room[]>([]);
  const [selectedRoomId, setSelectedRoomId] = useState<number | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [onlineUsers, setOnlineUsers] = useState<UserSummary[]>([]);
  const [authView, setAuthView] = useState<"login" | "register">("login");
  const [loading, setLoading] = useState(false);
  const [alert, setAlert] = useState<string | null>(null);
  const [newRoomName, setNewRoomName] = useState("");

  const authHeaders = useMemo(() => (token ? { Authorization: `Bearer ${token}` } : {}), [token]);

  useEffect(() => {
    if (token) {
      localStorage.setItem("chat_token", token);
    } else {
      localStorage.removeItem("chat_token");
    }
  }, [token]);

  useEffect(() => {
    if (!token) return;
    const bootstrap = async () => {
      try {
        const [meResponse, roomsResponse, onlineResponse] = await Promise.all([
          axios.get<UserSummary>(`${API_BASE}/users/me`, { headers: authHeaders }),
          axios.get<Room[]>(`${API_BASE}/rooms`, { headers: authHeaders }),
          axios.get<UserSummary[]>(`${API_BASE}/users/online`),
        ]);
        setCurrentUser(meResponse.data);
        setRooms(roomsResponse.data);
        setOnlineUsers(onlineResponse.data);
        if (roomsResponse.data.length) {
          setSelectedRoomId((prev) => prev ?? roomsResponse.data[0].id);
        }
      } catch (error) {
        setAlert("初始化失败，请重新登录");
        setToken(null);
      }
    };
    bootstrap();
  }, [token, authHeaders]);

  useEffect(() => {
    if (!token || !selectedRoomId) return;
    const loadMessages = async () => {
      const { data } = await axios.get<Message[]>(`${API_BASE}/rooms/${selectedRoomId}/messages`, {
        headers: authHeaders,
      });
      setMessages(data);
    };
    loadMessages();
  }, [token, selectedRoomId, authHeaders]);

  const handleLogin = async ({ username, password }: { username: string; password: string }) => {
    setLoading(true);
    try {
      const { data } = await axios.post(`${API_BASE}/auth/login`, { username, password });
      setToken(data.access_token);
      setAlert(null);
    } catch (error) {
      setAlert("登录失败，请检查账号或密码");
    } finally {
      setLoading(false);
    }
  };

  const handleRegister = async ({
    username,
    email,
    password,
  }: {
    username: string;
    email: string;
    password: string;
  }) => {
    setLoading(true);
    try {
      await axios.post(`${API_BASE}/auth/register`, { username, email, password });
      setAuthView("login");
      await handleLogin({ username, password });
    } catch (error) {
      setAlert("注册失败，请重试");
    } finally {
      setLoading(false);
    }
  };

  const handleLogout = () => {
    setToken(null);
    setCurrentUser(null);
    setRooms([]);
    setMessages([]);
    setSelectedRoomId(null);
  };

  const handleCreateRoom = async (event: FormEvent) => {
    event.preventDefault();
    if (!newRoomName.trim() || !token) return;
    try {
      const { data } = await axios.post<Room>(
        `${API_BASE}/rooms`,
        { name: newRoomName.trim() },
        { headers: authHeaders },
      );
      setRooms((prev) => [data, ...prev]);
      setSelectedRoomId(data.id);
      setNewRoomName("");
    } catch (error) {
      setAlert("创建房间失败");
    }
  };

  const selectedRoom = rooms.find((room) => room.id === selectedRoomId) ?? null;

  const handleHistory = useCallback((items: Message[]) => {
    setMessages(items);
  }, []);

  const handleIncomingMessage = useCallback((message: Message) => {
    setMessages((prev) => {
      const exists = prev.some((item) => item.id === message.id);
      return exists ? prev : [...prev, message];
    });
  }, []);

  const handleOnlineUsers = useCallback((users: UserSummary[]) => {
    setOnlineUsers(users);
  }, []);

  if (!token || !currentUser) {
    return (
      <div className="container" style={{ maxWidth: "480px" }}>
        {alert && (
          <div className="card" style={{ background: "#fde8e8" }}>
            <strong>提示：</strong> {alert}
          </div>
        )}
        {authView === "login" ? (
          <Login onSubmit={handleLogin} switchToRegister={() => setAuthView("register")} isLoading={loading} />
        ) : (
          <Register onSubmit={handleRegister} switchToLogin={() => setAuthView("login")} isLoading={loading} />
        )}
      </div>
    );
  }

  return (
    <div className="container" style={{ display: "flex", flexDirection: "column", gap: "1rem" }}>
      <header style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <div>
          <h1 style={{ marginBottom: 0 }}>Chat Codex</h1>
          <small>你好，{currentUser.username}</small>
        </div>
        <button onClick={handleLogout}>退出登录</button>
      </header>
      {alert && (
        <div className="card" style={{ background: "#fde8e8" }}>
          <strong>提示：</strong> {alert}
        </div>
      )}
      <section style={{ display: "flex", gap: "1rem", flexWrap: "wrap" }}>
        <div className="card" style={{ flex: "0 0 250px" }}>
          <h3>房间列表</h3>
          <ul style={{ listStyle: "none", padding: 0 }}>
            {rooms.map((room) => (
              <li key={room.id}>
                <button
                  type="button"
                  style={{
                    width: "100%",
                    textAlign: "left",
                    background: room.id === selectedRoomId ? "#d4f1f4" : "transparent",
                    border: "none",
                    padding: "0.5rem",
                  }}
                  onClick={() => setSelectedRoomId(room.id)}
                >
                  {room.name}
                </button>
              </li>
            ))}
            {!rooms.length && <li>暂无房间</li>}
          </ul>
          <form onSubmit={handleCreateRoom} style={{ marginTop: "1rem" }}>
            <input
              placeholder="新房间名称"
              value={newRoomName}
              onChange={(event) => setNewRoomName(event.target.value)}
              required
            />
            <button style={{ marginTop: "0.5rem" }}>创建</button>
          </form>
        </div>
        {selectedRoom && token ? (
          <ChatRoom
            room={selectedRoom}
            token={token}
            messages={messages}
            onMessages={handleHistory}
            onMessage={handleIncomingMessage}
            onUsers={handleOnlineUsers}
          />
        ) : (
          <div className="card" style={{ flex: 1 }}>请选择一个聊天室</div>
        )}
        <UserList users={onlineUsers} />
      </section>
    </div>
  );
};

export default App;
