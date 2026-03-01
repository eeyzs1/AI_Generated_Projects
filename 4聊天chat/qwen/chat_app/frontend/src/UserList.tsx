import React, { useState, useEffect } from 'react';

interface UserListProps {
  currentUser: any;
  onLogout: () => void;
}

const UserList: React.FC<UserListProps> = ({ currentUser, onLogout }) => {
  const [rooms, setRooms] = useState<any[]>([]);
  const [newRoomName, setNewRoomName] = useState('');
  const [loading, setLoading] = useState(false);

  // Fetch rooms
  useEffect(() => {
    const fetchRooms = async () => {
      try {
        const response = await fetch('http://localhost:8000/rooms', {
          headers: {
            'Authorization': `Bearer ${localStorage.getItem('token')}`
          }
        });
        if (response.ok) {
          const data = await response.json();
          setRooms(data);
        }
      } catch (err) {
        console.error('Failed to fetch rooms:', err);
      }
    };

    fetchRooms();
  }, []);

  const handleCreateRoom = async () => {
    if (!newRoomName.trim()) return;

    setLoading(true);
    try {
      const response = await fetch('http://localhost:8000/rooms', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${localStorage.getItem('token')}`
        },
        body: JSON.stringify({ name: newRoomName })
      });

      if (response.ok) {
        const newRoom = await response.json();
        setRooms([...rooms, newRoom]);
        setNewRoomName('');
      } else {
        const errorData = await response.json();
        alert(errorData.detail || 'Failed to create room');
      }
    } catch (err) {
      console.error('Failed to create room:', err);
      alert('Failed to create room');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="user-list">
      <div className="user-info">
        <h3>Welcome, {currentUser.username}!</h3>
        <button onClick={onLogout} className="logout-btn">
          <i className="fas fa-sign-out-alt"></i> Logout
        </button>
      </div>
      
      <div className="rooms-section">
        <h4>Your Rooms</h4>
        <div className="create-room">
          <input
            type="text"
            value={newRoomName}
            onChange={(e) => setNewRoomName(e.target.value)}
            placeholder="New room name"
            className="room-input"
          />
          <button onClick={handleCreateRoom} disabled={loading} className="create-room-btn">
            {loading ? 'Creating...' : 'Create'}
          </button>
        </div>
        <ul className="rooms-list">
          {rooms.map(room => (
            <li key={room.id} className="room-item">
              <i className="fas fa-comments"></i> {room.name}
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
};

export default UserList;
