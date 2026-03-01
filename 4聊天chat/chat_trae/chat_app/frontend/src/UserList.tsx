import React, { useState, useEffect } from 'react';

interface User {
  id: number;
  username: string;
  email: string;
  created_at: string;
  is_active: number;
}

interface UserListProps {
  user: User;
  onLogout: () => void;
}

const UserList: React.FC<UserListProps> = ({ user, onLogout }) => {
  const [users, setUsers] = useState<User[]>([]);
  const [selectedRoom, setSelectedRoom] = useState<number | null>(null);
  const [inviteUserId, setInviteUserId] = useState<number | null>(null);
  
  // 加载用户列表
  useEffect(() => {
    // 这里应该有一个获取所有用户的API端点
    // 暂时使用模拟数据
    const mockUsers = [
      { id: 1, username: 'user1', email: 'user1@example.com', created_at: new Date().toISOString(), is_active: 1 },
      { id: 2, username: 'user2', email: 'user2@example.com', created_at: new Date().toISOString(), is_active: 1 },
      { id: 3, username: 'user3', email: 'user3@example.com', created_at: new Date().toISOString(), is_active: 1 },
    ];
    setUsers(mockUsers);
  }, []);
  
  // 邀请用户到聊天室
  const handleInvite = () => {
    if (!selectedRoom || !inviteUserId) return;
    
    fetch(`http://localhost:8000/rooms/${selectedRoom}/add/${inviteUserId}`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${localStorage.getItem('token')}`
      }
    })
    .then(response => {
      if (response.ok) {
        alert('User invited successfully');
      } else {
        alert('Failed to invite user');
      }
    });
  };
  
  return (
    <div className="user-list-container">
      <div className="header">
        <h2>User List</h2>
        <button onClick={onLogout}>Logout</button>
      </div>
      
      <div className="invite-section">
        <h3>Invite User to Room</h3>
        <div className="form-group">
          <label htmlFor="room-id">Room ID</label>
          <input
            type="number"
            id="room-id"
            value={selectedRoom || ''}
            onChange={(e) => setSelectedRoom(Number(e.target.value))}
          />
        </div>
        <div className="form-group">
          <label htmlFor="user-id">User ID</label>
          <input
            type="number"
            id="user-id"
            value={inviteUserId || ''}
            onChange={(e) => setInviteUserId(Number(e.target.value))}
          />
        </div>
        <button onClick={handleInvite}>Invite</button>
      </div>
      
      <div className="users">
        <h3>All Users</h3>
        <div className="user-grid">
          {users.map(user => (
            <div key={user.id} className="user-card">
              <h4>{user.username}</h4>
              <p>{user.email}</p>
              <p>ID: {user.id}</p>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

export default UserList;