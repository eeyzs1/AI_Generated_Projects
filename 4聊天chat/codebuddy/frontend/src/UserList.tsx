import React, { useEffect, useState } from 'react';
import type { User } from './types';
import { userAPI } from './api';

interface UserListProps {
  currentUser: User;
  onAddToRoom: (userId: number) => void;
  currentRoomId: number | null;
}

const UserList: React.FC<UserListProps> = ({ currentUser, onAddToRoom, currentRoomId }) => {
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadUsers();
  }, []);

  const loadUsers = async () => {
    try {
      const response = await userAPI.getAll();
      setUsers(response.data);
    } catch (error) {
      console.error('Failed to load users:', error);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return <div style={styles.container}>加载中...</div>;
  }

  return (
    <div style={styles.container}>
      <h3 style={styles.title}>用户列表</h3>
      <div style={styles.userList}>
        {users.map((user) => (
          <div key={user.id} style={styles.userItem}>
            <div style={styles.userInfo}>
              <div style={styles.username}>{user.username}</div>
              <div style={styles.status}>
                {user.is_online ? (
                  <span style={styles.online}>在线</span>
                ) : (
                  <span style={styles.offline}>离线</span>
                )}
              </div>
            </div>
            {user.id !== currentUser.id && currentRoomId && (
              <button
                style={styles.addButton}
                onClick={() => onAddToRoom(user.id)}
              >
                邀请
              </button>
            )}
          </div>
        ))}
      </div>
    </div>
  );
};

const styles: { [key: string]: React.CSSProperties } = {
  container: {
    backgroundColor: '#f8f9fa',
    borderLeft: '1px solid #e0e0e0',
    padding: '1rem',
  },
  title: {
    margin: '0 0 1rem 0',
    fontSize: '1.1rem',
    color: '#333',
  },
  userList: {
    display: 'flex',
    flexDirection: 'column',
    gap: '0.5rem',
  },
  userItem: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: '0.75rem',
    backgroundColor: 'white',
    borderRadius: '4px',
    border: '1px solid #e0e0e0',
  },
  userInfo: {
    display: 'flex',
    flexDirection: 'column',
  },
  username: {
    fontWeight: '500',
    color: '#333',
  },
  status: {
    fontSize: '0.85rem',
    marginTop: '0.25rem',
  },
  online: {
    color: '#28a745',
  },
  offline: {
    color: '#6c757d',
  },
  addButton: {
    padding: '0.5rem 1rem',
    backgroundColor: '#007bff',
    color: 'white',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    fontSize: '0.9rem',
  },
};

export default UserList;
