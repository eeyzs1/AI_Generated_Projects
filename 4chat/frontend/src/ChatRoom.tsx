import React, { useState, useEffect, useRef } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';

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

interface Message {
  id: number;
  sender_id: number;
  room_id: number;
  content: string;
  created_at: string;
  sender: User | null;
}

interface ChatRoomProps {
  user: User;
  onLogout: () => void;
  authenticatedFetch: (url: string, options?: RequestInit) => Promise<Response>;
}

const ChatRoom: React.FC<ChatRoomProps> = ({ user, onLogout, authenticatedFetch }) => {
  const navigate = useNavigate();
  const location = useLocation();
  const room = location.state?.room as Room;
  const [messages, setMessages] = useState<Message[]>([]);
  const [newMessage, setNewMessage] = useState('');
  const [ws, setWs] = useState<WebSocket | null>(null);
  const [inviteeUsername, setInviteeUsername] = useState('');
  const messagesEndRef = useRef<HTMLDivElement>(null);
  
  // 加载聊天室消息
  useEffect(() => {
    if (room) {
      authenticatedFetch(`/api/message/rooms/${room.id}/messages`)
      .then(response => response.json())
      .then(data => setMessages(Array.isArray(data) ? data : []));
    }
  }, [room, authenticatedFetch]);
  
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
      
      socket.onmessage = (event) => {
        if (!isMounted) return;
        
        try {
          const data = JSON.parse(event.data);
          
          if (data.type === 'msg_sent' && data.room_id === room?.id) {
            setMessages(prev => [
              ...(Array.isArray(prev) ? prev : []),
              {
                id: data.message_id,
                sender_id: data.sender_id,
                room_id: data.room_id,
                content: data.content,
                created_at: data.created_at,
                sender: data.sender || null
              }
            ]);
          }
        } catch (error) {
          console.error('Error parsing WebSocket message:', error);
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
  }, [user.id, room]);
  
  // 滚动到最新消息
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);
  
  // 发送消息
  const handleSendMessage = async () => {
    if (!newMessage || !room) return;
    await authenticatedFetch('/api/message/send', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ room_id: room.id, content: newMessage })
    });
    setNewMessage('');
  };
  
  // 发送邀请
  const handleSendInvitation = () => {
    if (!inviteeUsername || !room) return;
    
    // 首先根据username获取userId
    authenticatedFetch(`/api/user/${inviteeUsername}`)
    .then(response => {
      if (!response.ok) {
        throw new Error('User not found');
      }
      return response.json();
    })
    .then(user => {
      // 然后发送邀请
      return authenticatedFetch('/api/group/invitations', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          room_id: room.id,
          invitee_id: user.id
        })
      });
    })
    .then(response => response.json())
    .then(data => {
      setInviteeUsername('');
      alert('Invitation sent successfully!');
    })
    .catch(error => {
      alert('Failed to send invitation. User not found.');
      console.error(error);
    });
  };
  
  if (!room) {
    return (
      <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100vh', backgroundColor: '#f5f5f5' }}>
        <div style={{ textAlign: 'center' }}>
          <h2 style={{ color: '#333' }}>No room selected</h2>
          <p style={{ color: '#666', marginBottom: '20px' }}>Please select a room from the rooms list</p>
          <button 
            onClick={() => navigate('/')}
            style={{
              padding: '10px 20px',
              backgroundColor: '#3498db',
              color: 'white',
              border: 'none',
              borderRadius: '4px',
              cursor: 'pointer',
              fontSize: '16px'
            }}
          >
            Go to Rooms
          </button>
        </div>
      </div>
    );
  }
  
  return (
    <div style={{ display: 'flex', height: '100vh', backgroundColor: '#f5f5f5' }}>
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', backgroundColor: 'white' }}>
        <div style={{ padding: '20px', borderBottom: '1px solid #e0e0e0', backgroundColor: '#f8f9fa', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '15px' }}>
            <button 
              onClick={() => navigate('/')}
              style={{
                padding: '8px 12px',
                border: '1px solid #ddd',
                borderRadius: '4px',
                backgroundColor: 'white',
                cursor: 'pointer',
                fontSize: '14px'
              }}
            >
              Back to Rooms
            </button>
            <h2 style={{ margin: 0, color: '#333' }}>{room.name}</h2>
          </div>
          <div style={{ display: 'flex', gap: '10px' }}>
            <button 
              onClick={() => navigate('/contacts')}
              style={{
                padding: '8px 12px',
                border: '1px solid #ddd',
                borderRadius: '4px',
                backgroundColor: 'white',
                cursor: 'pointer',
                fontSize: '14px'
              }}
            >
              Contacts
            </button>
            <button 
              onClick={() => navigate('/profile')}
              style={{
                padding: '8px 12px',
                border: '1px solid #ddd',
                borderRadius: '4px',
                backgroundColor: 'white',
                cursor: 'pointer',
                fontSize: '14px'
              }}
            >
              Profile
            </button>
            <button 
              onClick={onLogout}
              style={{
                padding: '8px 12px',
                border: '1px solid #ddd',
                borderRadius: '4px',
                backgroundColor: '#ff4757',
                color: 'white',
                cursor: 'pointer',
                fontSize: '14px'
              }}
            >
              Logout
            </button>
          </div>
        </div>
        
        <div style={{ padding: '15px', borderBottom: '1px solid #e0e0e0', backgroundColor: '#f8f9fa' }}>
          <div style={{ display: 'flex', gap: '10px', marginBottom: '15px' }}>
            <input
              type="text"
              placeholder="Username to invite"
              value={inviteeUsername}
              onChange={(e) => setInviteeUsername(e.target.value)}
              style={{
                flex: 1,
                padding: '10px',
                border: '1px solid #ddd',
                borderRadius: '4px',
                fontSize: '14px'
              }}
            />
            <button 
              onClick={handleSendInvitation}
              style={{
                padding: '0 15px',
                backgroundColor: '#27ae60',
                color: 'white',
                border: 'none',
                borderRadius: '4px',
                cursor: 'pointer',
                fontSize: '14px'
              }}
            >
              Invite
            </button>
          </div>
          
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '10px' }}>
            <h4 style={{ margin: 0, color: '#333', flex: '100%' }}>Room Members:</h4>
            {(room.members && Array.isArray(room.members)) ? room.members.map(member => (
              <div key={member.id} style={{ 
                display: 'flex', 
                alignItems: 'center', 
                gap: '8px', 
                padding: '8px 12px', 
                border: '1px solid #e0e0e0', 
                borderRadius: '20px', 
                backgroundColor: 'white', 
                fontSize: '14px' 
              }}>
                <div style={{ 
                  width: '24px', 
                  height: '24px', 
                  borderRadius: '50%', 
                  overflow: 'hidden' 
                }}>
                  <img 
                    src={member.avatar || '/api/storage/static/avatars/default/default1.png'} 
                    alt="Member avatar" 
                    style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                  />
                </div>
                <span>{member.displayname || member.username}</span>
              </div>
            )) : null}
          </div>
        </div>
        
        <div style={{ flex: 1, padding: '20px', overflowY: 'auto', backgroundColor: '#f5f5f5' }}>
          {Array.isArray(messages) && messages.length > 0 ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '15px' }}>
              {messages.map(message => (
                <div
                  key={message.id}
                  style={{
                    maxWidth: '70%',
                    alignSelf: message.sender_id === user.id ? 'flex-end' : 'flex-start',
                    padding: '12px',
                    borderRadius: '18px',
                    backgroundColor: message.sender_id === user.id ? '#dcf8c6' : 'white',
                    boxShadow: '0 1px 2px rgba(0,0,0,0.1)'
                  }}
                >
                  <div style={{ display: 'flex', gap: '10px', marginBottom: '8px', alignItems: 'center' }}>
                    <div style={{ 
                      width: '32px', 
                      height: '32px', 
                      borderRadius: '50%', 
                      overflow: 'hidden' 
                    }}>
                      <img 
                        src={message.sender?.avatar || '/api/storage/static/avatars/default/default1.png'} 
                        alt="User avatar" 
                        style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                      />
                    </div>
                    <div style={{ fontSize: '14px', fontWeight: '500', color: '#333' }}>
                      {message.sender?.displayname || message.sender?.username || `User ${message.sender_id}`}
                    </div>
                  </div>
                  <div style={{ fontSize: '16px', color: '#333', lineHeight: '1.4' }}>
                    {message.content}
                  </div>
                  <div style={{ fontSize: '12px', color: '#999', marginTop: '8px', textAlign: 'right' }}>
                    {new Date(message.created_at).toLocaleTimeString()}
                  </div>
                </div>
              ))}
              <div ref={messagesEndRef} />
            </div>
          ) : (
            <div style={{ textAlign: 'center', padding: '40px', color: '#666' }}>
              <p>No messages yet. Start the conversation!</p>
            </div>
          )}
        </div>
        
        <div style={{ padding: '20px', borderTop: '1px solid #e0e0e0', backgroundColor: 'white' }}>
          <div style={{ display: 'flex', gap: '10px' }}>
            <input
              type="text"
              placeholder="Type a message..."
              value={newMessage}
              onChange={(e) => setNewMessage(e.target.value)}
              onKeyPress={(e) => e.key === 'Enter' && handleSendMessage()}
              style={{
                flex: 1,
                padding: '12px',
                border: '1px solid #ddd',
                borderRadius: '24px',
                fontSize: '16px'
              }}
            />
            <button 
              onClick={handleSendMessage}
              style={{
                width: '48px',
                height: '48px',
                borderRadius: '50%',
                backgroundColor: '#3498db',
                color: 'white',
                border: 'none',
                cursor: 'pointer',
                display: 'flex',
                justifyContent: 'center',
                alignItems: 'center',
                fontSize: '18px'
              }}
            >
              ↵
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default ChatRoom;