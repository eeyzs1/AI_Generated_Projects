import React, { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import './AvatarStyles.css';

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

interface Invitation {
  id: number;
  room_id: number;
  room_name: string;
  inviter_id: number;
  inviter_name: string;
  status: string;
  created_at: string;
}

interface ChatRoomProps {
  user: User;
  onLogout: () => void;
  authenticatedFetch: (url: string, options?: RequestInit) => Promise<Response>;
}

const ChatRoom: React.FC<ChatRoomProps> = ({ user, onLogout, authenticatedFetch }) => {
  const navigate = useNavigate();
  const [rooms, setRooms] = useState<Room[]>([]);
  const [selectedRoom, setSelectedRoom] = useState<Room | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [newMessage, setNewMessage] = useState('');
  const [newRoomName, setNewRoomName] = useState('');
  const [ws, setWs] = useState<WebSocket | null>(null);
  const [onlineUsers, setOnlineUsers] = useState<{id: number, username: string, displayname: string, avatar: string | null}[]>([]);
  const [invitations, setInvitations] = useState<Invitation[]>([]);
  const [inviteeUsername, setInviteeUsername] = useState('');
  const [showInvitations, setShowInvitations] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  
  // 加载聊天室列表
  useEffect(() => {
    authenticatedFetch('http://localhost:8000/rooms')
    .then(response => response.json())
    .then(data => setRooms(Array.isArray(data) ? data : []));
  }, [authenticatedFetch]);
  
  // 加载邀请列表
  useEffect(() => {
    authenticatedFetch('http://localhost:8000/invitations')
    .then(response => response.json())
    .then(data => setInvitations(Array.isArray(data) ? data : []));
  }, [authenticatedFetch]);
  
  // 初始化WebSocket连接
  useEffect(() => {
    let socket: WebSocket | null = null;
    let isMounted = true;
    let isConnected = false;
    
    try {
      socket = new WebSocket(`ws://localhost:8000/ws/${user.id}`);
      
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
          
          if (data.type === 'online_users') {
            setOnlineUsers(Array.isArray(data.users) ? data.users : []);
          } else if (data.type === 'message') {
            setMessages(prev => [
              ...(Array.isArray(prev) ? prev : []),
              {
                id: data.id,
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
          // 只有在连接建立后才关闭，避免出现"closed before connection established"错误
          if (isConnected || socket.readyState === WebSocket.OPEN || socket.readyState === WebSocket.CONNECTING) {
            socket.close();
          }
        } catch (error) {
          // 捕获关闭时可能出现的错误
          console.log('WebSocket close error (ignored):', error);
        }
      }
    };
  }, [user.id]);
  
  // 滚动到最新消息
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);
  
  // 选择聊天室
  const handleRoomSelect = (room: Room) => {
    setSelectedRoom(room);
    
    // 加载聊天室消息
    authenticatedFetch(`http://localhost:8000/rooms/${room.id}/messages`)
    .then(response => response.json())
    .then(data => setMessages(Array.isArray(data) ? data : []));
    
    // 加入WebSocket房间
    if (ws) {
      ws.send(JSON.stringify({
        type: 'join_room',
        room_id: room.id
      }));
    }
  };
  
  // 创建聊天室
  const handleCreateRoom = () => {
    if (!newRoomName) return;
    
    authenticatedFetch('http://localhost:8000/rooms', {
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
  
  // 发送消息
  const handleSendMessage = () => {
    if (!newMessage || !selectedRoom || !ws) return;
    
    ws.send(JSON.stringify({
      type: 'message',
      room_id: selectedRoom.id,
      content: newMessage
    }));
    
    setNewMessage('');
  };
  
  // 发送邀请
  const handleSendInvitation = () => {
    if (!inviteeUsername || !selectedRoom) return;
    
    // 首先根据username获取userId
    authenticatedFetch(`http://localhost:8000/users/${inviteeUsername}`)
    .then(response => {
      if (!response.ok) {
        throw new Error('User not found');
      }
      return response.json();
    })
    .then(user => {
      // 然后发送邀请
      return authenticatedFetch('http://localhost:8000/invitations', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          room_id: selectedRoom.id,
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
  
  // 处理邀请
  const handleInvitationAction = (invitationId: number, action: string) => {
    authenticatedFetch(`http://localhost:8000/invitations/${invitationId}/action`, {
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
        authenticatedFetch('http://localhost:8000/rooms')
        .then(response => response.json())
        .then(data => setRooms(Array.isArray(data) ? data : []));
      }
    });
  };
  
  return (
    <div className="chat-container">
      <div className="sidebar">
        <div className="sidebar-header">
          <h2>Chat App</h2>
          <div className="header-buttons">
            <button onClick={() => setShowInvitations(!showInvitations)}>
              Invitations ({Array.isArray(invitations) ? invitations.filter(inv => inv.status === 'pending').length : 0})
            </button>
            <button onClick={() => navigate('/profile')}>
              Profile
            </button>
            <button onClick={onLogout}>Logout</button>
          </div>
        </div>
        
        {showInvitations && (
          <div className="invitations-list">
            <h3>Pending Invitations</h3>
            {Array.isArray(invitations) && invitations.filter(inv => inv.status === 'pending').length > 0 ? (
              invitations.filter(inv => inv.status === 'pending').map(invitation => (
                <div key={invitation.id} className="invitation-item">
                  <div className="invitation-info">
                    <div>Room: {invitation.room_name}</div>
                    <div>Invited by: {invitation.inviter_name}</div>
                  </div>
                  <div className="invitation-actions">
                    <button onClick={() => handleInvitationAction(invitation.id, 'accepted')}>
                      Accept
                    </button>
                    <button onClick={() => handleInvitationAction(invitation.id, 'rejected')}>
                      Reject
                    </button>
                  </div>
                </div>
              ))
            ) : (
              <p>No pending invitations</p>
            )}
          </div>
        )}
        
        <div className="create-room">
          <input
            type="text"
            placeholder="Room name"
            value={newRoomName}
            onChange={(e) => setNewRoomName(e.target.value)}
          />
          <button onClick={handleCreateRoom}>Create</button>
        </div>
        
        <div className="room-list">
          <h3>Rooms</h3>
          {Array.isArray(rooms) && rooms.map(room => (
            <div
              key={room.id}
              className={`room-item ${selectedRoom?.id === room.id ? 'active' : ''}`}
              onClick={() => handleRoomSelect(room)}
            >
              {room.name}
            </div>
          ))}
        </div>
        
        <div className="online-users">
          <h3>Online Users</h3>
          <div className="user-list">
            {onlineUsers.length > 0 ? (
              onlineUsers.map(user => {
                return (
                  <div key={user.id} className="user-item">
                    <div className="user-avatar">
                      <img 
                        src={user.avatar || '/static/avatars/default/default1.png'} 
                        alt="User avatar" 
                      />
                    </div>
                    <div className="user-name">
                      {user.displayname || user.username || `User ${user.id}`}
                    </div>
                  </div>
                );
              })
            ) : (
              <p>No online users</p>
            )}
          </div>
        </div>
      </div>
      
      <div className="chat-area">
        {selectedRoom ? (
          <>
            <div className="chat-header">
              <h2>{selectedRoom.name}</h2>
              <div className="room-actions">
                <div className="invite-user">
                  <input
                    type="text"
                    placeholder="Username to invite"
                    value={inviteeUsername}
                    onChange={(e) => setInviteeUsername(e.target.value)}
                  />
                  <button onClick={handleSendInvitation}>Invite</button>
                </div>
                <div className="room-members">
                  {(selectedRoom.members && Array.isArray(selectedRoom.members)) ? selectedRoom.members.map(member => (
                    <div key={member.id} className="member">
                      <div className="member-avatar">
                        <img 
                          src={member.avatar || '/static/avatars/default/default1.png'} 
                          alt="Member avatar" 
                        />
                      </div>
                      <span className="member-name">
                        {member.displayname || member.username}
                      </span>
                    </div>
                  )) : null}
                </div>
              </div>
            </div>
            
            <div className="messages-container">
              {Array.isArray(messages) && messages.map(message => (
                <div
                  key={message.id}
                  className={`message ${message.sender_id === user.id ? 'own' : ''}`}
                >
                  <div className="message-header">
                    <div className="message-avatar">
                      <img 
                        src={message.sender?.avatar || '/static/avatars/default/default1.png'} 
                        alt="User avatar" 
                      />
                    </div>
                    <div className="message-sender">
                      {message.sender?.displayname || message.sender?.username || `User ${message.sender_id}`}
                    </div>
                  </div>
                  <div className="message-content">{message.content}</div>
                  <div className="message-time">
                    {new Date(message.created_at).toLocaleTimeString()}
                  </div>
                </div>
              ))}
              <div ref={messagesEndRef} />
            </div>
            
            <div className="message-input">
              <input
                type="text"
                placeholder="Type a message..."
                value={newMessage}
                onChange={(e) => setNewMessage(e.target.value)}
                onKeyPress={(e) => e.key === 'Enter' && handleSendMessage()}
              />
              <button onClick={handleSendMessage}>Send</button>
            </div>
          </>
        ) : (
          <div className="no-room-selected">
            <h3>Select a room or create a new one</h3>
          </div>
        )}
      </div>
    </div>
  );
};

export default ChatRoom;