import React, { useState, useEffect } from 'react';
import Login from './Login';
import Register from './Register';
import ChatRoom from './ChatRoom';
import './App.css';

interface User {
  id: number;
  username: string;
  email: string;
  is_active: boolean;
  is_online: boolean;
  created_at: string;
}

function App() {
  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const [showLogin, setShowLogin] = useState(true);

  useEffect(() => {
    // Check if user is already logged in
    const token = localStorage.getItem('token');
    const userData = localStorage.getItem('user');
    
    if (token && userData) {
      try {
        const user = JSON.parse(userData);
        setCurrentUser(user);
      } catch (error) {
        // Invalid stored data, clear it
        localStorage.removeItem('token');
        localStorage.removeItem('user');
      }
    }
  }, []);

  const handleLogin = (user: User) => {
    setCurrentUser(user);
  };

  const handleLogout = () => {
    localStorage.removeItem('token');
    localStorage.removeItem('user');
    setCurrentUser(null);
  };

  if (currentUser) {
    return (
      <ChatRoom 
        currentUser={currentUser} 
        onLogout={handleLogout}
      />
    );
  }

  return (
    <div className="app">
      <header className="app-header">
        <h1>Chat Application</h1>
      </header>
      
      <main className="app-main">
        {showLogin ? (
          <Login 
            onLogin={handleLogin} 
            onSwitchToRegister={() => setShowLogin(false)} 
          />
        ) : (
          <Register 
            onRegister={handleLogin} 
            onSwitchToLogin={() => setShowLogin(true)} 
          />
        )}
      </main>
    </div>
  );
}

export default App;