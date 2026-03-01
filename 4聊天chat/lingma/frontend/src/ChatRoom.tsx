import React, { useState, useEffect, useRef } from 'react';
import UserList from './UserList';

interface User {
  id: number;
  username: string;
  email: string;
  is_active: boolean;
  is_online: boolean;
  created_at: string;
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
  content: string;
  sender_id: number;
  room_id: number;
  created_at: string;
  sender?: User;
}

interface ChatRoomProps {
  currentUser: User;
  onLogout: () => void;
}

const API_BASE_URL = 'http://localhost:8000';

function ChatRoom({ currentUser, onLogout }: ChatRoomProps) {
  const [rooms, setRooms] = useState<Room[]>([]);
  const [currentRoom, setCurrentRoom] = useState<Room | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [newMessage, setNewMessage] = useState('');
  const [newRoomName, setNewRoomName] = useState('');
  const [websocket, setWebsocket] = useState<WebSocket | null>(null);
  const [onlineUsers, setOnlineUsers] = useState<User[]>([]);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  // Initialize WebSocket connection
  useEffect(() => {
    const ws = new WebSocket(`ws://localhost:8000/ws/${currentUser.id}`);
    
    ws.onopen = () => {
      console.log('WebSocket connected');
    };

    ws.onmessage = (event) => {
      const data = JSON.parse(event.data);
      
      if (data.type === 'message') {
        setMessages(prev => [...prev, data]);
      } else if (data.type === 'user_status') {
        // Update online users list
        fetchOnlineUsers();
      }
    };

    ws.onclose = () => {
      console.log('WebSocket disconnected');
    };

    setWebsocket(ws);

    return () => {
      ws.close();
    };
  }, [currentUser.id]);

  // Fetch rooms and online users on mount
  useEffect(() => {
    fetchRooms();
    fetchOnlineUsers();
  }, []);

  // Scroll to bottom when messages change
  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  const fetchRooms = async () => {
    try {
      const token = localStorage.getItem('token');
      const response = await fetch(`${API_BASE_URL}/rooms`, {
        headers: {
          'Authorization': `Bearer ${token}`
        }
      });
      
      if (response.ok) {
        const data = await response.json();
        setRooms(data);
      }
    } catch (error) {
      console.error('Failed to fetch rooms:', error);
    }
  };

  const fetchOnlineUsers = async () => {
    try {
      const token = localStorage.getItem('token');
      const response = await fetch(`${API_BASE_URL}/users/online`, {
        headers: {
          'Authorization': `Bearer ${token}`
        }
      });
      
      if (response.ok) {
        const data = await response.json();
        setOnlineUsers(data);
      }
    } catch (error) {
      console.error('Failed to fetch online users:', error);
    }
  };

  const fetchMessages = async (roomId: number) => {
    try {
      const token = localStorage.getItem('token');
      const response = await fetch(`${API_BASE_URL}/messages/room/${roomId}`, {
        headers: {
          'Authorization': `Bearer ${token}`
        }
      });
      
      if (response.ok) {
        const data = await response.json();
        setMessages(data.reverse()); // Reverse to show oldest first
      }
    } catch (error) {
      console.error('Failed to fetch messages:', error);
    }
  };

  const handleCreateRoom = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newRoomName.trim()) return;

    try {
      const token = localStorage.getItem('token');
      const response = await fetch(`${API_BASE_URL}/rooms`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({ name: newRoomName })
      });

      if (response.ok) {
        const newRoom = await response.json();
        setRooms(prev => [...prev, newRoom]);
        setNewRoomName('');
      }
    } catch (error) {
      console.error('Failed to create room:', error);
    }
  };

  const handleJoinRoom = async (room: Room) => {
    setCurrentRoom(room);
    await fetchMessages(room.id);
    
    // Notify server about room join via WebSocket
    if (websocket && websocket.readyState === WebSocket.OPEN) {
      websocket.send(JSON.stringify({
        type: 'join_room',
        room_id: room.id
      }));
    }
  };

  const handleSendMessage = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newMessage.trim() || !currentRoom) return;

    try {
      // Send via WebSocket
      if (websocket && websocket.readyState === WebSocket.OPEN) {
        websocket.send(JSON.stringify({
          type: 'message',
          room_id: currentRoom.id,
          content: newMessage
        }));
        setNewMessage('');
      }
    } catch (error) {
      console.error('Failed to send message:', error);
    }
  };

  return (
    <div className="chat-room">
      <header className="chat-header">
        <h1>Chat Application</h1>
        <div className="user-info">
          <span>Welcome, {currentUser.username}!</span>
          <button onClick={onLogout} className="logout-btn">Logout</button>
        </div>
      </header>

      <div className="chat-container">
        {/* Sidebar */}
        <div className="sidebar">
          <div className="rooms-section">
            <h3>Your Rooms</h3>
            <form onSubmit={handleCreateRoom} className="create-room-form">
              <input
                type="text"
                value={newRoomName}
                onChange={(e) => setNewRoomName(e.target.value)}
                placeholder="New room name"
                required
              />
              <button type="submit">Create Room</button>
            </form>
            
            <ul className="rooms-list">
              {rooms.map(room => (
                <li 
                  key={room.id} 
                  className={`room-item ${currentRoom?.id === room.id ? 'active' : ''}`}
                  onClick={() => handleJoinRoom(room)}
                >
                  {room.name}
                </li>
              ))}
            </ul>
          </div>
          
          <UserList users={onlineUsers} currentUser={currentUser} />
        </div>

        {/* Main Chat Area */}
        <div className="main-chat">
          {currentRoom ? (
            <>
              <div className="chat-header">
                <h2>{currentRoom.name}</h2>
              </div>
              
              <div className="messages-container">
                {messages.map(message => (
                  <div 
                    key={message.id} 
                    className={`message ${message.sender_id === currentUser.id ? 'own' : 'other'}`}
                  >
                    <div className="message-sender">
                      {message.sender?.username || 'Unknown'}
                    </div>
                    <div className="message-content">
                      {message.content}
                    </div>
                    <div className="message-time">
                      {new Date(message.created_at).toLocaleTimeString()}
                    </div>
                  </div>
                ))}
                <div ref={messagesEndRef} />
              </div>
              
              <form onSubmit={handleSendMessage} className="message-form">
                <input
                  type="text"
                  value={newMessage}
                  onChange={(e) => setNewMessage(e.target.value)}
                  placeholder="Type your message..."
                  required
                />
                <button type="submit">Send</button>
              </form>
            </>
          ) : (
            <div className="no-room-selected">
              <h3>Select a room to start chatting</h3>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

export default ChatRoom;