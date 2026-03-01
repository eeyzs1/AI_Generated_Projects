import React, { useState, useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import Login from './Login';
import Register from './Register';
import ChatRoom from './ChatRoom';

// API基础URL
export const API_BASE_URL = 'http://localhost:8000';

// 用户类型定义
export interface User {
  id: number;
  username: string;
  email: string;
  is_active: boolean;
  is_online: boolean;
  last_seen?: string;
  created_at: string;
}

// 认证上下文
interface AuthContextType {
  user: User | null;
  token: string | null;
  login: (token: string, user: User) => void;
  logout: () => void;
}

export const AuthContext = React.createContext<AuthContextType>({
  user: null,
  token: null,
  login: () => {},
  logout: () => {},
});

const App: React.FC = () => {
  const [user, setUser] = useState<User | null>(null);
  const [token, setToken] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // 从localStorage恢复登录状态
    const storedToken = localStorage.getItem('token');
    const storedUser = localStorage.getItem('user');
    
    if (storedToken && storedUser) {
      setToken(storedToken);
      setUser(JSON.parse(storedUser));
    }
    setLoading(false);
  }, []);

  const login = (newToken: string, newUser: User) => {
    localStorage.setItem('token', newToken);
    localStorage.setItem('user', JSON.stringify(newUser));
    setToken(newToken);
    setUser(newUser);
  };

  const logout = () => {
    localStorage.removeItem('token');
    localStorage.removeItem('user');
    setToken(null);
    setUser(null);
  };

  if (loading) {
    return <div style={styles.loading}>加载中...</div>;
  }

  return (
    <AuthContext.Provider value={{ user, token, login, logout }}>
      <Router>
        <Routes>
          <Route 
            path="/login" 
            element={token ? <Navigate to="/chat" /> : <Login />} 
          />
          <Route 
            path="/register" 
            element={token ? <Navigate to="/chat" /> : <Register />} 
          />
          <Route 
            path="/chat" 
            element={token ? <ChatRoom /> : <Navigate to="/login" />} 
          />
          <Route 
            path="/" 
            element={<Navigate to={token ? "/chat" : "/login"} />} 
          />
        </Routes>
      </Router>
    </AuthContext.Provider>
  );
};

const styles: { [key: string]: React.CSSProperties } = {
  loading: {
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    height: '100vh',
    fontSize: '18px',
    color: '#666',
  },
};

export default App;
