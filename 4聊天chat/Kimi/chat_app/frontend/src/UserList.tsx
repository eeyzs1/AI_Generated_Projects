import React, { useEffect, useState } from 'react';
import axios from 'axios';
import { API_BASE_URL } from './App';

interface User {
  id: number;
  username: string;
  is_online: boolean;
}

interface UserListProps {
  token: string;
  onlineUserIds: number[];
  onSelectUser: (user: User) => void;
  selectedUserId?: number;
}

const UserList: React.FC<UserListProps> = ({ 
  token, 
  onlineUserIds, 
  onSelectUser, 
  selectedUserId 
}) => {
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchUsers();
  }, [token]);

  // 当在线用户列表变化时更新用户状态
  useEffect(() => {
    setUsers(prevUsers => 
      prevUsers.map(user => ({
        ...user,
        is_online: onlineUserIds.includes(user.id)
      }))
    );
  }, [onlineUserIds]);

  const fetchUsers = async () => {
    try {
      const response = await axios.get(`${API_BASE_URL}/api/users`, {
        headers: { Authorization: `Bearer ${token}` }
      });
      setUsers(response.data);
    } catch (error) {
      console.error('获取用户列表失败:', error);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return <div style={styles.loading}>加载中...</div>;
  }

  // 按在线状态排序
  const sortedUsers = [...users].sort((a, b) => {
    if (a.is_online === b.is_online) return 0;
    return a.is_online ? -1 : 1;
  });

  return (
    <div style={styles.container}>
      <h3 style={styles.title}>用户列表</h3>
      <div style={styles.list}>
        {sortedUsers.map(user => (
          <div
            key={user.id}
            style={{
              ...styles.userItem,
              ...(selectedUserId === user.id ? styles.userItemSelected : {}),
            }}
            onClick={() => onSelectUser(user)}
          >
            <div style={styles.avatar}>
              {user.username.charAt(0).toUpperCase()}
            </div>
            <div style={styles.userInfo}>
              <span style={styles.username}>{user.username}</span>
              <span style={{
                ...styles.status,
                ...(user.is_online ? styles.statusOnline : styles.statusOffline),
              }}>
                {user.is_online ? '在线' : '离线'}
              </span>
            </div>
            {user.is_online && <div style={styles.onlineIndicator} />}
          </div>
        ))}
      </div>
    </div>
  );
};

const styles: { [key: string]: React.CSSProperties } = {
  container: {
    backgroundColor: '#fff',
    borderRadius: '8px',
    boxShadow: '0 2px 8px rgba(0, 0, 0, 0.1)',
    overflow: 'hidden',
  },
  title: {
    padding: '16px',
    margin: 0,
    fontSize: '16px',
    fontWeight: '600',
    color: '#333',
    borderBottom: '1px solid #eee',
  },
  list: {
    maxHeight: '400px',
    overflowY: 'auto',
  },
  loading: {
    padding: '20px',
    textAlign: 'center',
    color: '#666',
  },
  userItem: {
    display: 'flex',
    alignItems: 'center',
    padding: '12px 16px',
    cursor: 'pointer',
    transition: 'background-color 0.2s',
    borderBottom: '1px solid #f5f5f5',
    ':hover': {
      backgroundColor: '#f5f5f5',
    },
  },
  userItemSelected: {
    backgroundColor: '#e6f7ed',
  },
  avatar: {
    width: '40px',
    height: '40px',
    borderRadius: '50%',
    backgroundColor: '#07c160',
    color: '#fff',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    fontSize: '16px',
    fontWeight: 'bold',
    marginRight: '12px',
  },
  userInfo: {
    flex: 1,
    display: 'flex',
    flexDirection: 'column',
  },
  username: {
    fontSize: '14px',
    fontWeight: '500',
    color: '#333',
  },
  status: {
    fontSize: '12px',
    marginTop: '2px',
  },
  statusOnline: {
    color: '#07c160',
  },
  statusOffline: {
    color: '#999',
  },
  onlineIndicator: {
    width: '8px',
    height: '8px',
    borderRadius: '50%',
    backgroundColor: '#07c160',
  },
};

export default UserList;
