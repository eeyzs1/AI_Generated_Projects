import React, { useState, useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import Login from './Login';
import Register from './Register';
import ChatRoom from './ChatRoom';
import UserList from './UserList';
import axios from 'axios';

// 类型定义
interface User {
  id: number;
  username: string;
  email: string;
  is_active: boolean;
}

interface Room {
  id: number;
  name: string;
  creator_id: number;
  members: RoomMember[];
}

interface RoomMember {
  id: number;
  user_id: number;
  joined_at: string;
  is_admin: boolean;
  user: User;
}

interface Message {
  id: number;
  sender_id: number;
  room_id: number;
  content: string;
  created_at: string;
  is_read: boolean;
  sender?: User;
}

// API基础URL
const API_BASE_URL = 'http://localhost:8000/api';
const WS_BASE_URL = 'ws://localhost:8000/ws';

// 创建axios实例
const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// 请求拦截器，添加认证token
api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('token');
    if (token) {
      config.headers['Authorization'] = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// 响应拦截器，处理认证错误
api.interceptors.response.use(
  (response) => {
    return response;
  },
  (error) => {
    if (error.response && error.response.status === 401) {
      // 清除token并跳转到登录页
      localStorage.removeItem('token');
      localStorage.removeItem('user');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

function App() {
  const [user, setUser] = useState<User | null>(null);
  const [rooms, setRooms] = useState<Room[]>([]);
  const [loading, setLoading] = useState(true);

  // 初始化应用
  useEffect(() => {
    // 检查是否有token
    const token = localStorage.getItem('token');
    if (token) {
      // 获取当前用户信息
      api.get('/auth/me')
        .then((response) => {
          setUser(response.data);
          localStorage.setItem('user', JSON.stringify(response.data));
          // 获取用户的聊天室列表
          return api.get('/rooms');
        })
        .then((response) => {
          setRooms(response.data);
        })
        .catch((error) => {
          console.error('Error initializing app:', error);
          localStorage.removeItem('token');
          localStorage.removeItem('user');
        })
        .finally(() => {
          setLoading(false);
        });
    } else {
      setLoading(false);
    }
  }, []);

  // 登录处理
  const handleLogin = async (username: string, password: string) => {
    try {
      const response = await api.post('/auth/login', {
        username,
        password,
      });
      
      // 保存token和用户信息
      localStorage.setItem('token', response.data.access_token);
      
      // 获取用户信息
      const userResponse = await api.get('/auth/me');
      setUser(userResponse.data);
      localStorage.setItem('user', JSON.stringify(userResponse.data));
      
      // 获取用户的聊天室列表
      const roomsResponse = await api.get('/rooms');
      setRooms(roomsResponse.data);
      
      return { success: true };
    } catch (error: any) {
      return { 
        success: false, 
        error: error.response?.data?.detail || 'Login failed' 
      };
    }
  };

  // 注册处理
  const handleRegister = async (username: string, email: string, password: string) => {
    try {
      await api.post('/auth/register', {
        username,
        email,
        password,
      });
      
      // 自动登录
      return await handleLogin(username, password);
    } catch (error: any) {
      return { 
        success: false, 
        error: error.response?.data?.detail || 'Registration failed' 
      };
    }
  };

  // 登出处理
  const handleLogout = () => {
    localStorage.removeItem('token');
    localStorage.removeItem('user');
    setUser(null);
    setRooms([]);
  };

  // 创建聊天室
  const handleCreateRoom = async (name: string) => {
    try {
      const response = await api.post('/rooms', { name });
      setRooms([...rooms, response.data]);
      return { success: true };
    } catch (error: any) {
      return { 
        success: false, 
        error: error.response?.data?.detail || 'Failed to create room' 
      };
    }
  };

  // 加入聊天室
  const handleJoinRoom = async (roomId: number) => {
    try {
      await api.post(`/rooms/${roomId}/join`);
      // 重新获取聊天室列表
      const response = await api.get('/rooms');
      setRooms(response.data);
      return { success: true };
    } catch (error: any) {
      return { 
        success: false, 
        error: error.response?.data?.detail || 'Failed to join room' 
      };
    }
  };

  // 离开聊天室
  const handleLeaveRoom = async (roomId: number) => {
    try {
      await api.delete(`/rooms/${roomId}/leave`);
      // 从列表中移除聊天室
      setRooms(rooms.filter(room => room.id !== roomId));
      return { success: true };
    } catch (error: any) {
      return { 
        success: false, 
        error: error.response?.data?.detail || 'Failed to leave room' 
      };
    }
  };

  // 邀请用户加入聊天室
  const handleInviteUser = async (roomId: number, userId: number) => {
    try {
      await api.post(`/rooms/${roomId}/invite`, { user_id: userId });
      return { success: true };
    } catch (error: any) {
      return { 
        success: false, 
        error: error.response?.data?.detail || 'Failed to invite user' 
      };
    }
  };

  // 发送消息
  const handleSendMessage = async (roomId: number, content: string) => {
    try {
      const response = await api.post(`/rooms/${roomId}/messages`, { content });
      return { success: true, message: response.data };
    } catch (error: any) {
      return { 
        success: false, 
        error: error.response?.data?.detail || 'Failed to send message' 
      };
    }
  };

  // 获取聊天记录
  const handleGetMessages = async (roomId: number) => {
    try {
      const response = await api.get(`/rooms/${roomId}/messages`);
      return { success: true, messages: response.data };
    } catch (error: any) {
      return { 
        success: false, 
        error: error.response?.data?.detail || 'Failed to get messages' 
      };
    }
  };

  if (loading) {
    return <div className="loading">Loading...</div>;
  }

  return (
    <Router>
      <div className="app">
        <Routes>
          <Route path="/login" element={<Login onLogin={handleLogin} />} />
          <Route path="/register" element={<Register onRegister={handleRegister} />} />
          <Route 
            path="/chat/:roomId" 
            element={
              user ? (
                <ChatRoom 
                  user={user}
                  api={api}
                  wsBaseUrl={WS_BASE_URL}
                  onSendMessage={handleSendMessage}
                  onGetMessages={handleGetMessages}
                />
              ) : (
                <Navigate to="/login" />
              )
            } 
          />
          <Route 
            path="/users" 
            element={
              user ? (
                <UserList 
                  user={user}
                  wsBaseUrl={WS_BASE_URL}
                />
              ) : (
                <Navigate to="/login" />
              )
            } 
          />
          <Route 
            path="/" 
            element={
              user ? (
                <div className="home">
                  <h1>Welcome, {user.username}!</h1>
                  <button onClick={handleLogout}>Logout</button>
                  
                  <div className="rooms">
                    <h2>Your Chat Rooms</h2>
                    <ul>
                      {rooms.map((room) => (
                        <li key={room.id}>
                          <a href={`/chat/${room.id}`}>{room.name}</a>
                          <button onClick={() => handleLeaveRoom(room.id)}>Leave</button>
                        </li>
                      ))}
                    </ul>
                    
                    <div className="create-room">
                      <h3>Create New Room</h3>
                      <CreateRoomForm onCreate={handleCreateRoom} />
                    </div>
                  </div>
                </div>
              ) : (
                <Navigate to="/login" />
              )
            } 
          />
        </Routes>
      </div>
    </Router>
  );
}

// 创建聊天室表单组件
interface CreateRoomFormProps {
  onCreate: (name: string) => Promise<{ success: boolean; error?: string }>;
}

const CreateRoomForm: React.FC<CreateRoomFormProps> = ({ onCreate }) => {
  const [name, setName] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    
    if (!name.trim()) {
      setError('Room name is required');
      return;
    }
    
    setLoading(true);
    const result = await onCreate(name);
    setLoading(false);
    
    if (result.success) {
      setName('');
    } else {
      setError(result.error || 'Failed to create room');
    }
  };

  return (
    <form onSubmit={handleSubmit}>
      <input
        type="text"
        placeholder="Room name"
        value={name}
        onChange={(e) => setName(e.target.value)}
        disabled={loading}
      />
      <button type="submit" disabled={loading}>
        {loading ? 'Creating...' : 'Create Room'}
      </button>
      {error && <div className="error">{error}</div>}
    </form>
  );
};

export default App;