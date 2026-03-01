import React from 'react';

interface UserListProps {
  onlineUserIds: number[];
  currentUserId: number;
  users: { [key: number]: { id: number; username: string } };
}

const UserList: React.FC<UserListProps> = ({ onlineUserIds, currentUserId, users }) => {
  return (
    <div className="user-list">
      <h3>在线用户</h3>
      <hr />
      {onlineUserIds.length === 0 ? (
        <p>暂无在线用户</p>
      ) : (
        onlineUserIds.map(userId => (
          <div key={userId} style={{ padding: '8px', margin: '5px 0', borderRadius: '4px', background: userId === currentUserId ? '#e3f2fd' : '#f8f9fa' }}>
            {users[userId]?.username || `用户${userId}`}
            {userId === currentUserId && <span style={{ color: '#007bff', fontSize: '12px' }}> (我)</span>}
          </div>
        ))
      )}
    </div>
  );
};

export default UserList;
