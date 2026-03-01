import React, { useState, useEffect } from 'react';
import Login from './Login';
import Register from './Register';
import ChatRoom from './ChatRoom';
import UserList from './UserList';
import './App.css';

const App: React.FC = () => {
  const [currentUser, setCurrentUser] = useState<any>(null);
  const [activeView, setActiveView] = useState<'login' | 'register' | 'chat'>('login');
  const [token, setToken] = useState<string | null>(localStorage.getItem('token'));

  // Check if user is already logged in
  useEffect(() => {
    const savedToken = localStorage.getItem('token');
    if (savedToken) {
      // Validate token by fetching user info
      fetch('http://localhost:8000/users/me', {
        headers: {
          'Authorization': `Bearer ${savedToken}`
        }
      })
      .then(response => {
        if (response.ok) {
          return response.json();
        }
        throw new Error('Token invalid');
      })
      .then(userData => {
        setCurrentUser(userData);
        setActiveView('chat');
      })
      .catch(() => {
        localStorage.removeItem('token');
        setToken(null);
      });
    }
  }, []);

  const handleLogin = (userData: any, accessToken: string) => {
    setCurrentUser(userData);
    setToken(accessToken);
    localStorage.setItem('token', accessToken);
    setActiveView('chat');
  };

  const handleLogout = () => {
    setCurrentUser(null);
    setToken(null);
    localStorage.removeItem('token');
    setActiveView('login');
  };

  return (
    <div className="app">
      {activeView === 'login' && (
        <Login onLogin={handleLogin} onSwitchToRegister={() => setActiveView('register')} />
      )}
      {activeView === 'register' && (
        <Register onRegister={handleLogin} onSwitchToLogin={() => setActiveView('login')} />
      )}
      {activeView === 'chat' && currentUser && (
        <div className="chat-container">
          <UserList currentUser={currentUser} onLogout={handleLogout} />
          <ChatRoom currentUser={currentUser} token={token!} />
        </div>
      )}
    </div>
  );
};

export default App;
