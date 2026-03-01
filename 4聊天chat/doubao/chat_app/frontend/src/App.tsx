import React, { useState, useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import Login from './Login';
import Register from './Register';
import ChatRoom from './ChatRoom';

interface User {
  id: number;
  username: string;
  email: string;
}

const App: React.FC = () => {
  const [token, setToken] = useState<string | null>(localStorage.getItem('token'));
  const [currentUser, setCurrentUser] = useState<User | null>(null);

  // 加载当前用户信息
  useEffect(() => {
    if (token) {
      fetch('/api/me', {
        headers: {
          'Authorization': `Bearer ${token}`
        }
      })
      .then(res => {
        if (res.ok) return res.json();
        throw new Error('认证失败');
      })
      .then(data => setCurrentUser(data))
      .catch(() => {
        localStorage.removeItem('token');
        setToken(null);
      });
    }
  }, [token]);

  // 处理登录
  const handleLogin = (newToken: string) => {
    localStorage.setItem('token', newToken);
    setToken(newToken);
  };

  // 处理登出
  const handleLogout = () => {
    localStorage.removeItem('token');
    setToken(null);
    setCurrentUser(null);
  };

  return (
    <Router>
      <div className="container">
        <h1>简易聊天应用</h1>
        {currentUser && (
          <div style={{ marginBottom: '20px', display: 'flex', justifyContent: 'space-between' }}>
            <p>当前登录：{currentUser.username}</p>
            <button onClick={handleLogout} style={{ width: '100px' }}>登出</button>
          </div>
        )}
        <Routes>
          <Route path="/login" element={token ? <Navigate to="/" /> : <Login onLogin={handleLogin} />} />
          <Route path="/register" element={token ? <Navigate to="/" /> : <Register />} />
          <Route path="/" element={token ? <ChatRoom token={token} user={currentUser!} /> : <Navigate to="/login" />} />
        </Routes>
      </div>
    </Router>
  );
};

export default App;
