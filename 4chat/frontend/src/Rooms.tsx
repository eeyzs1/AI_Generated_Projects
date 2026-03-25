import React, { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';

interface User {
  id: number;
  username: string;
  displayname: string;
  email: string;
  avatar: string | null;
  created_at: string;
  is_active: boolean;
}

interface Room {
  id: number;
  name: string;
  creator_id: number;
  created_at: string;
  members: User[];
}

interface Invitation {
  id: number;
  room_id: number;
  room_name: string;
  inviter_id: number;
  inviter_name: string;
  status: string;
  created_at: string;
}

interface RoomsProps {
  user: User;
  onLogout: () => void;
  authenticatedFetch: (url: string, options?: RequestInit) => Promise<Response>;
}

const Rooms: React.FC<RoomsProps> = ({ user, onLogout, authenticatedFetch }) => {
  const navigate = useNavigate();
  const [rooms, setRooms] = useState<Room[]>([]);
  const [newRoomName, setNewRoomName] = useState('');
  const [invitations, setInvitations] = useState<Invitation[]>([]);
  const [showInvitations, setShowInvitations] = useState(false);
  const [ws, setWs] = useState<WebSocket | null>(null);
  
  // 加载聊天室列表
  useEffect(() => {
    authenticatedFetch('/api/group/rooms')
    .then(response => response.json())
    .then(data => setRooms(Array.isArray(data) ? data : []));
  }, [authenticatedFetch]);
  
  // 加载邀请列表
  useEffect(() => {
    authenticatedFetch('/api/group/invitations')
    .then(response => response.json())
    .then(data => setInvitations(Array.isArray(data) ? data : []));
  }, [authenticatedFetch]);
  
  // 初始化WebSocket连接
  useEffect(() => {
    let socket: WebSocket | null = null;
    let isMounted = true;
    let isConnected = false;
    
    try {
      const token = localStorage.getItem('token');
      socket = new WebSocket(`/ws/connect?token=${token}&user_id=${user.id}`);
      
      socket.onopen = () => {
        if (isMounted) {
          isConnected = true;
          console.log('WebSocket connected');
        }
      };
      
      socket.onclose = () => {
        if (isMounted) {
          isConnected = false;
          console.log('WebSocket disconnected');
        }
      };
      
      socket.onerror = (error) => {
        if (isMounted) {
          console.error('WebSocket error:', error);
        }
      };
      
      if (isMounted) {
        setWs(socket);
      }
    } catch (error) {
      console.error('Error creating WebSocket:', error);
    }
    
    return () => {
      isMounted = false;
      if (socket) {
        try {
          if (isConnected || socket.readyState === WebSocket.OPEN || socket.readyState === WebSocket.CONNECTING) {
            socket.close();
          }
        } catch (error) {
          console.log('WebSocket close error (ignored):', error);
        }
      }
    };
  }, [user.id]);
  
  // 进入聊天室
  const handleRoomSelect = (room: Room) => {
    navigate(`/chatroom/${room.id}`, { state: { room } });
  };
  
  // 创建聊天室
  const handleCreateRoom = () => {
    if (!newRoomName) return;
    
    authenticatedFetch('/rooms', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ name: newRoomName })
    })
    .then(response => response.json())
    .then(data => {
      setRooms(prev => [...(Array.isArray(prev) ? prev : []), data]);
      setNewRoomName('');
    });
  };
  
  // 处理邀请
  const handleInvitationAction = (invitationId: number, action: string) => {
    authenticatedFetch(`/api/group/invitations/${invitationId}/action`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ action })
    })
    .then(response => response.json())
    .then(data => {
      // 更新邀请列表
      setInvitations(prev => (Array.isArray(prev) ? prev : []).filter(inv => inv.id !== invitationId));
      // 如果接受邀请，重新加载聊天室列表
      if (action === 'accepted') {
        authenticatedFetch('/api/group/rooms')
        .then(response => response.json())
        .then(data => setRooms(Array.isArray(data) ? data : []));
      }
    });
  };
  
  return (
    <div style={{ height: '100vh', backgroundColor: '#f5f5f5', display: 'flex', flexDirection: 'column' }}>
      <div style={{ padding: '20px', borderBottom: '1px solid #e0e0e0', backgroundColor: '#f8f9fa' }}>
        <h2 style={{ margin: 0, color: '#333' }}>Chat App</h2>
        <div style={{ display: 'flex', gap: '10px', marginTop: '15px', flexWrap: 'wrap' }}>
          <button 
            onClick={() => setShowInvitations(!showInvitations)}
            style={{
              padding: '8px 12px',
              border: '1px solid #ddd',
              borderRadius: '4px',
              backgroundColor: 'white',
              color: 'black',
              cursor: 'pointer',
              fontSize: '14px',
              fontWeight: '500'
            }}
          >
            Invitations ({Array.isArray(invitations) ? invitations.filter(inv => inv.status === 'pending').length : 0})
          </button>
          <button 
            onClick={() => navigate('/contacts')}
            style={{
              padding: '8px 12px',
              border: '1px solid #ddd',
              borderRadius: '4px',
              backgroundColor: 'white',
              color: 'black',
              cursor: 'pointer',
              fontSize: '14px',
              fontWeight: '500'
            }}
          >
            联系人
          </button>
          <button 
            onClick={() => navigate('/profile')}
            style={{
              padding: '8px 12px',
              border: '1px solid #ddd',
              borderRadius: '4px',
              backgroundColor: 'white',
              color: 'black',
              cursor: 'pointer',
              fontSize: '14px',
              fontWeight: '500'
            }}
          >
            个人中心
          </button>
        </div>
      </div>
      
      {showInvitations && (
        <div style={{ padding: '15px', borderBottom: '1px solid #e0e0e0', backgroundColor: 'white' }}>
          <h3 style={{ margin: '0 0 15px 0', color: '#333' }}>Pending Invitations</h3>
          {Array.isArray(invitations) && invitations.filter(inv => inv.status === 'pending').length > 0 ? (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))', gap: '15px' }}>
              {invitations.filter(inv => inv.status === 'pending').map(invitation => (
                <div key={invitation.id} style={{ 
                  padding: '15px', 
                  border: '1px solid #e0e0e0', 
                  borderRadius: '8px', 
                  backgroundColor: '#f8f9fa' 
                }}>
                  <div style={{ marginBottom: '15px' }}>
                    <div><strong>Room:</strong> {invitation.room_name}</div>
                    <div><strong>Invited by:</strong> {invitation.inviter_name}</div>
                  </div>
                  <div style={{ display: 'flex', gap: '10px' }}>
                    <button 
                      onClick={() => handleInvitationAction(invitation.id, 'accepted')}
                      style={{
                        flex: 1,
                        padding: '8px 16px',
                        backgroundColor: '#27ae60',
                        color: 'white',
                        border: 'none',
                        borderRadius: '4px',
                        cursor: 'pointer',
                        fontSize: '14px',
                        fontWeight: '500'
                      }}
                    >
                      Accept
                    </button>
                    <button 
                      onClick={() => handleInvitationAction(invitation.id, 'rejected')}
                      style={{
                        flex: 1,
                        padding: '8px 16px',
                        backgroundColor: '#e74c3c',
                        color: 'white',
                        border: 'none',
                        borderRadius: '4px',
                        cursor: 'pointer',
                        fontSize: '14px',
                        fontWeight: '500'
                      }}
                    >
                      Reject
                    </button>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <p style={{ color: '#666', fontStyle: 'italic' }}>No pending invitations</p>
          )}
        </div>
      )}
      
      <div style={{ padding: '20px', borderBottom: '1px solid #e0e0e0', backgroundColor: 'white' }}>
        <h3 style={{ margin: '0 0 15px 0', color: '#333' }}>Create New Room</h3>
        <div style={{ display: 'flex', gap: '10px', maxWidth: '600px' }}>
          <input
            type="text"
            placeholder="Room name"
            value={newRoomName}
            onChange={(e) => setNewRoomName(e.target.value)}
            style={{
              flex: 1,
              padding: '10px',
              border: '1px solid #ddd',
              borderRadius: '4px',
              fontSize: '14px'
            }}
          />
          <button 
            onClick={handleCreateRoom}
            style={{
              padding: '0 20px',
              backgroundColor: '#3498db',
              color: 'white',
              border: 'none',
              borderRadius: '4px',
              cursor: 'pointer',
              fontSize: '14px',
              fontWeight: '500'
            }}
          >
            Create
          </button>
        </div>
      </div>
      
      <div style={{ flex: 1, padding: '20px', overflowY: 'auto' }}>
        <h3 style={{ margin: '0 0 20px 0', color: '#333' }}>Rooms</h3>
        {Array.isArray(rooms) && rooms.length > 0 ? (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(250px, 1fr))', gap: '15px' }}>
            {rooms.map(room => (
              <div
                key={room.id}
                onClick={() => handleRoomSelect(room)}
                style={{
                  padding: '20px',
                  border: '1px solid #e0e0e0',
                  borderRadius: '8px',
                  cursor: 'pointer',
                  backgroundColor: 'white',
                  transition: 'all 0.2s ease',
                  boxShadow: '0 2px 4px rgba(0,0,0,0.1)'
                }}
              >
                <h4 style={{ margin: '0 0 10px 0', color: '#333' }}>{room.name}</h4>
                <p style={{ margin: 0, color: '#666', fontSize: '14px' }}>
                  {room.members && Array.isArray(room.members) ? `${room.members.length} members` : '0 members'}
                </p>
              </div>
            ))}
          </div>
        ) : (
          <div style={{ textAlign: 'center', padding: '60px 20px', backgroundColor: 'white', borderRadius: '8px', boxShadow: '0 2px 4px rgba(0,0,0,0.1)' }}>
            <div style={{ 
              width: '80px', 
              height: '80px', 
              borderRadius: '50%', 
              backgroundColor: '#e3f2fd', 
              display: 'flex', 
              justifyContent: 'center', 
              alignItems: 'center', 
              margin: '0 auto 20px' 
            }}>
              <span style={{ fontSize: '36px', color: '#2196f3' }}>💬</span>
            </div>
            <h3 style={{ color: '#333', marginBottom: '10px' }}>No rooms yet</h3>
            <p style={{ color: '#666' }}>Create a new room to start chatting</p>
          </div>
        )}
      </div>
    </div>
  );
};

export default Rooms;