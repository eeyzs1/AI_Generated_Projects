import React, { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import axios from 'axios';

interface User {
  id: number;
  username: string;
  email: string;
  is_active: boolean;
}

interface UserListProps {
  user: User;
  wsBaseUrl: string;
}

const UserList: React.FC<UserListProps> = ({ user, wsBaseUrl }) => {
  const navigate = useNavigate();
  const [onlineUsers, setOnlineUsers] = useState<Set<number>>(new Set());
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const wsRef = useRef<WebSocket | null>(null);

  // 获取所有用户
  useEffect(() => {
    const fetchUsers = async () => {
      try {
        // 在实际应用中，应该有一个获取所有用户的API端点
        // 这里我们模拟获取用户列表
        // const response = await api.get('/users');
        // setUsers(response.data);
        
        // 模拟数据
        setUsers([
          { id: 1, username: 'user1', email: 'user1@example.com', is_active: true },
          { id: 2, username: 'user2', email: 'user2@example.com', is_active: true },
          { id: 3, username: 'user3', email: 'user3@example.com', is_active: true },
          { id: user.id, username: user.username, email: user.email, is_active: true },
        ]);
        
        setLoading(false);
      } catch (error) {
        console.error('Error fetching users:', error);
        setError('Failed to load users');
        setLoading(false);
      }
    };

    fetchUsers();
  }, [user]);

  // 建立WebSocket连接
  useEffect(() => {
    if (!user) return;

    const token = localStorage.getItem('token');
    if (!token) {
      navigate('/login');
      return;
    }

    // 建立WebSocket连接
    const ws = new WebSocket(`${wsBaseUrl}/users?token=${token}`);
    
    ws.onopen = () => {
      console.log('WebSocket connected for user list');
    };

    ws.onmessage = (event) => {
      const data = JSON.parse(event.data);
      
      if (data.type === 'online_users') {
        // 更新在线用户列表
        setOnlineUsers(new Set(data.data.user_ids));
      }
    };

    ws.onclose = () => {
      console.log('WebSocket disconnected for user list');
    };

    ws.onerror = (error) => {
      console.error('WebSocket error:', error);
    };

    wsRef.current = ws;

    return () => {
      ws.close();
    };
  }, [user, wsBaseUrl, navigate]);

  if (loading) {
    return <div className="loading">Loading...</div>;
  }

  if (error) {
    return <div className="error">{error}</div>;
  }

  return (
    <div className="user-list-container">
      <div className="user-list-header">
        <h2>Online Users</h2>
        <button onClick={() => navigate('/')}>Back to Home</button>
      </div>
      
      <div className="user-list">
        {users.map((u) => (
          <div 
            key={u.id} 
            className={`user-item ${onlineUsers.has(u.id) ? 'online' : 'offline'} ${u.id === user.id ? 'current-user' : ''}`}
          >
            <div className="user-status">
              <div className={`status-dot ${onlineUsers.has(u.id) ? 'online' : 'offline'}`}></div>
            </div>
            <div className="user-info">
              <div className="user-name">{u.username} {u.id === user.id && '(You)'}</div>
              <div className="user-email">{u.email}</div>
            </div>
          </div>
        ))}
      </div>
      
      <style jsx>{`
        .user-list-container {
          display: flex;
          flex-direction: column;
          height: 100vh;
          max-width: 800px;
          margin: 0 auto;
          background-color: #fff;
        }
        
        .user-list-header {
          display: flex;
          justify-content: space-between;
          align-items: center;
          padding: 1rem;
          background-color: #007bff;
          color: white;
        }
        
        .user-list-header h2 {
          margin: 0;
        }
        
        .user-list-header button {
          padding: 0.5rem 1rem;
          background-color: transparent;
          color: white;
          border: 1px solid white;
          border-radius: 4px;
          cursor: pointer;
        }
        
        .user-list-header button:hover {
          background-color: rgba(255, 255, 255, 0.1);
        }
        
        .user-list {
          flex: 1;
          overflow-y: auto;
          padding: 1rem;
        }
        
        .user-item {
          display: flex;
          align-items: center;
          padding: 1rem;
          border-bottom: 1px solid #e9ecef;
        }
        
        .user-item:last-child {
          border-bottom: none;
        }
        
        .user-item.current-user {
          background-color: #f8f9fa;
        }
        
        .user-status {
          margin-right: 1rem;
        }
        
        .status-dot {
          width: 12px;
          height: 12px;
          border-radius: 50%;
        }
        
        .status-dot.online {
          background-color: #28a745;
        }
        
        .status-dot.offline {
          background-color: #6c757d;
        }
        
        .user-info {
          flex: 1;
        }
        
        .user-name {
          font-weight: 500;
          margin-bottom: 0.25rem;
        }
        
        .user-email {
          color: #6c757d;
          font-size: 0.875rem;
        }
        
        .loading {
          display: flex;
          justify-content: center;
          align-items: center;
          height: 100vh;
          font-size: 1.25rem;
          color: #6c757d;
        }
        
        .error {
          display: flex;
          justify-content: center;
          align-items: center;
          height: 100vh;
          font-size: 1.25rem;
          color: #dc3545;
        }
      `}</style>
    </div>
  );
};

export default UserList;