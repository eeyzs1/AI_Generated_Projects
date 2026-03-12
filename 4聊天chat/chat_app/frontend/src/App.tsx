import React, { useState, useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import Login from './Login';
import Register from './Register';
import ChatRoom from './ChatRoom';
import UserList from './UserList';
import UserProfile from './UserProfile';
import VerifyEmail from './VerifyEmail';
import PasswordResetRequest from './PasswordResetRequest';
import PasswordReset from './PasswordReset';

interface User {
  id: number;
  username: string;
  email: string;
  created_at: string;
  is_active: boolean;
}

const App: React.FC = () => {
  const [user, setUser] = useState<User | null>(null);
  const [token, setToken] = useState<string | null>(localStorage.getItem('token'));
  
  useEffect(() => {
    if (token) {
      // 验证token并获取用户信息
      fetch('http://localhost:8000/users/me', {
        headers: {
          'Authorization': `Bearer ${token}`
        }
      })
      .then(response => response.json())
      .then(data => setUser(data))
      .catch(() => {
        localStorage.removeItem('token');
        setToken(null);
        setUser(null);
      });
    }
  }, [token]);
  
  const handleLogin = (newToken: string) => {
    localStorage.setItem('token', newToken);
    setToken(newToken);
  };
  
  const handleLogout = () => {
    localStorage.removeItem('token');
    setToken(null);
    setUser(null);
  };
  
  const handleUserUpdate = (updatedUser: User) => {
    setUser(updatedUser);
  };
  
  return (
    <Router>
      <div className="app">
        <Routes>
          <Route path="/login" element={token ? <Navigate to="/" /> : <Login onLogin={handleLogin} />} />
          <Route path="/register" element={token ? <Navigate to="/" /> : <Register />} />
          <Route path="/" element={token ? (user ? <ChatRoom user={user} onLogout={handleLogout} /> : <div>Loading...</div>) : <Navigate to="/login" />} />
          <Route path="/users" element={token ? (user ? <UserList user={user} onLogout={handleLogout} /> : <div>Loading...</div>) : <Navigate to="/login" />} />
          <Route path="/profile" element={token ? (user ? <UserProfile user={user} onLogout={handleLogout} onUserUpdate={handleUserUpdate} /> : <div>Loading...</div>) : <Navigate to="/login" />} />
          <Route path="/verify-email" element={<VerifyEmail />} />
          <Route path="/reset-password-request" element={token ? <Navigate to="/" /> : <PasswordResetRequest />} />
          <Route path="/reset-password" element={token ? <Navigate to="/" /> : <PasswordReset />} />
        </Routes>
      </div>
    </Router>
  );
};

export default App;