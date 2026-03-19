import React, { useState, useEffect, useCallback } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import Login from './Login';
import Register from './Register';
import MainLayout from './MainLayout';

import UserProfile from './UserProfile';
import VerifyEmail from './VerifyEmail';
import PasswordResetRequest from './PasswordResetRequest';
import PasswordReset from './PasswordReset';
import Contacts from './Contacts';
import ContactProfile from './ContactProfile';

interface User {
  id: number;
  username: string;
  displayname: string;
  email: string;
  avatar: string | null;
  created_at: string;
  is_active: boolean;
}

const App: React.FC = () => {
  const [user, setUser] = useState<User | null>(null);
  const [token, setToken] = useState<string | null>(localStorage.getItem('token'));
  const [isRefreshing, setIsRefreshing] = useState(false);
  
  // 刷新token的函数
  const refreshToken = useCallback(async () => {
    if (isRefreshing) return;
    
    setIsRefreshing(true);
    try {
      const response = await fetch('http://localhost:8080/api/user/refresh-token', {
        method: 'POST',
        credentials: 'include' // 包含cookie
      });
      
      if (response.ok) {
        const data = await response.json();
        setToken(data.access_token);
        return data.access_token;
      } else {
        // 刷新失败，需要重新登录
        setToken(null);
        setUser(null);
        return null;
      }
    } catch (error) {
      console.error('Error refreshing token:', error);
      setToken(null);
      setUser(null);
      return null;
    } finally {
      setIsRefreshing(false);
    }
  }, [isRefreshing]);
  
  // 带token刷新的fetch函数
  const authenticatedFetch = useCallback(async (url: string, options: RequestInit = {}) => {
    if (!token) {
      throw new Error('No token available');
    }
    
    const headers = {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`,
      ...options.headers,
    };
    
    const response = await fetch(url, {
      ...options,
      headers,
    });
    
    // 如果token过期，尝试刷新
    if (response.status === 401) {
      const newToken = await refreshToken();
      if (newToken) {
        // 用新token重新请求
        const updatedHeaders = {
          ...headers,
          'Authorization': `Bearer ${newToken}`,
        };
        return fetch(url, {
          ...options,
          headers: updatedHeaders,
        });
      } else {
        // 刷新失败，返回原始响应
        return response;
      }
    }
    
    return response;
  }, [token, refreshToken]);
  
  // 验证token并获取用户信息
  useEffect(() => {
    if (token) {
      authenticatedFetch('http://localhost:8080/api/user/me')
        .then(response => response.json())
        .then(data => setUser(data))
        .catch(() => {
          setToken(null);
          setUser(null);
        });
    }
  }, [token, authenticatedFetch]);
  
  const handleLogin = (newToken: string) => {
    setToken(newToken);
    localStorage.setItem('token', newToken);
  };
  
  const handleLogout = async () => {
    // 调用登出接口（如果有）
    try {
      await fetch('http://localhost:8080/api/user/logout', {
        method: 'POST',
        credentials: 'include'
      });
    } catch (error) {
      console.error('Error during logout:', error);
    }
    setToken(null);
    setUser(null);
    localStorage.removeItem('token');
  };
  
  const handleUserUpdate = (updatedUser: User) => {
    setUser(updatedUser);
  };
  
  // 提供authenticatedFetch给子组件
  const contextValue = {
    token,
    user,
    handleLogin,
    handleLogout,
    handleUserUpdate,
    authenticatedFetch
  };
  
  return (
    <Router>
      <div className="app">
        <Routes>
          <Route path="/login" element={token ? <Navigate to="/" /> : <Login onLogin={handleLogin} />} />
          <Route path="/register" element={token ? <Navigate to="/" /> : <Register />} />
          <Route path="/" element={token ? (user ? <MainLayout user={user} onLogout={handleLogout} authenticatedFetch={authenticatedFetch} /> : <div>Loading...</div>) : <Navigate to="/login" />} />

          <Route path="/profile" element={token ? (user ? <UserProfile user={user} onLogout={handleLogout} onUserUpdate={handleUserUpdate} authenticatedFetch={authenticatedFetch} /> : <div>Loading...</div>) : <Navigate to="/login" />} />
          <Route path="/contacts" element={token ? (user ? <Contacts user={user} onLogout={handleLogout} authenticatedFetch={authenticatedFetch} /> : <div>Loading...</div>) : <Navigate to="/login" />} />
          <Route path="/contact/:contactId" element={token ? (user ? <ContactProfile user={user} onLogout={handleLogout} authenticatedFetch={authenticatedFetch} /> : <div>Loading...</div>) : <Navigate to="/login" />} />
          <Route path="/verify-email" element={<VerifyEmail />} />
          <Route path="/reset-password-request" element={token ? <Navigate to="/" /> : <PasswordResetRequest />} />
          <Route path="/reset-password" element={token ? <Navigate to="/" /> : <PasswordReset />} />
        </Routes>
      </div>
    </Router>
  );
};

export default App;