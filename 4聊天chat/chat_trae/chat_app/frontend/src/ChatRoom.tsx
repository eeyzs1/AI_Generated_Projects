import React, { useState, useEffect, useRef } from 'react';

interface User {
  id: number;
  username: string;
  email: string;
  created_at: string;
  is_active: number;
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
}

const ChatRoom: React.FC<ChatRoomProps> = ({ user, onLogout }) => {
  const [rooms, setRooms] = useState<Room[]>([]);
  const [selectedRoom, setSelectedRoom] = useState<Room | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [newMessage, setNewMessage] = useState('');
  const [newRoomName, setNewRoomName] = useState('');
  const [ws, setWs] = useState<WebSocket | null>(null);
  const [onlineUsers, setOnlineUsers] = useState<number[]>([]);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  
  // 加载聊天室列表
  useEffect(() => {
    fetch('http://localhost:8000/rooms', {
      headers: {
        'Authorization': `Bearer ${localStorage.getItem('token')}`
      }
    })
    .then(response => response.json())
    .then(data => setRooms(data));
  }, []);
  
  // 初始化WebSocket连接
  useEffect(() => {
    const socket = new WebSocket(`ws://localhost:8000/ws/${user.id}`);
    
    socket.onopen = () => {
      console.log('WebSocket connected');
    };
    
    socket.onmessage = (event) => {
      const data = JSON.parse(event.data);
      
      if (data.type === 'online_users') {
        setOnlineUsers(data.users);
      } else if (data.type === 'message') {
        setMessages(prev => [
          {
            id: data.id,
            sender_id: data.sender_id,
            room_id: data.room_id,
            content: data.content,
            created_at: data.created_at,
            sender: null
          },
          ...prev
        ]);
      }
    };
    
    socket.onclose = () => {
      console.log('WebSocket disconnected');
    };
    
    setWs(socket);
    
    return () => {
      socket.close();
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
    fetch(`http://localhost:8000/rooms/${room.id}/messages`, {
      headers: {
        'Authorization': `Bearer ${localStorage.getItem('token')}`
      }
    })
    .then(response => response.json())
    .then(data => setMessages(data));
    
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
    
    fetch('http://localhost:8000/rooms', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${localStorage.getItem('token')}`
      },
      body: JSON.stringify({ name: newRoomName })
    })
    .then(response => response.json())
    .then(data => {
      setRooms(prev => [...prev, data]);
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
  
  return (
    <div className="chat-container">
      <div className="sidebar">
        <div className="sidebar-header">
          <h2>Chat App</h2>
          <button onClick={onLogout}>Logout</button>
        </div>
        
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
          {rooms.map(room => (
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
              onlineUsers.map(userId => (
                <div key={userId} className="user-item">
                  User {userId}
                </div>
              ))
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
              <div className="room-members">
                {selectedRoom.members.map(member => (
                  <span key={member.id} className="member">
                    {member.username}
                  </span>
                ))}
              </div>
            </div>
            
            <div className="messages-container">
              {messages.map(message => (
                <div
                  key={message.id}
                  className={`message ${message.sender_id === user.id ? 'own' : ''}`}
                >
                  <div className="message-sender">
                    {message.sender?.username || `User ${message.sender_id}`}
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