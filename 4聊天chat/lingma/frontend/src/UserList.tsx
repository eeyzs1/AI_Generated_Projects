import React from 'react';

interface User {
  id: number;
  username: string;
  email: string;
  is_active: boolean;
  is_online: boolean;
  created_at: string;
}

interface UserListProps {
  users: User[];
  currentUser: User;
}

function UserList({ users, currentUser }: UserListProps) {
  return (
    <div className="user-list">
      <h3>Online Users</h3>
      <ul>
        {users
          .filter(user => user.id !== currentUser.id) // Exclude current user
          .map(user => (
            <li key={user.id} className="user-item">
              <span className="user-status online"></span>
              <span className="username">{user.username}</span>
            </li>
          ))}
        <li className="user-item current-user">
          <span className="user-status online"></span>
          <span className="username">{currentUser.username} (You)</span>
        </li>
      </ul>
    </div>
  );
}

export default UserList;