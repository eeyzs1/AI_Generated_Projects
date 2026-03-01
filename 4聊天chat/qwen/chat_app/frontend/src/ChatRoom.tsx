import React, { useState, useEffect, useRef } from 'react';

interface ChatRoomProps {
  currentUser: any;
  token: string;
}

interface Message {
  id: number;
  content: string;
  timestamp: string;
  sender_id: number;
  sender_username?: string;
}

const ChatRoom: React.FC<ChatRoomProps> = ({ currentUser, token }) => {
  const [rooms, setRooms] = useState<any[]>([]);
  const [selectedRoom, setSelectedRoom] = useState<any>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [newMessage, setNewMessage] = useState('');
  const [ws, setWs] = useState<WebSocket | null>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  // Fetch rooms
  useEffect(() => {
    const fetchRooms = async () => {
      try {
        const response = await fetch('http://localhost:8000/rooms', {
          headers: {
            'Authorization': `Bearer ${token}`
          }
        });
        if (response.ok) {
          const data = await response.json();
          setRooms(data);
          if (data.length > 0 && !selectedRoom) {
            setSelectedRoom(data[0]);
          }
        }
      } catch (err) {
        console.error('Failed to fetch rooms:', err);
      }
    };

    fetchRooms();
  }, [token, selectedRoom]);

  // Fetch messages when room changes
  useEffect(() => {
    if (selectedRoom) {
      const fetchMessages = async () => {
        try {
          const response = await fetch(`http://localhost:8000/rooms/${selectedRoom.id}/messages`, {
            headers: {
              'Authorization': `Bearer ${token}`
            }
          });
          if (response.ok) {
            const data = await response.json();
            setMessages(data);
          }
        } catch (err) {
          console.error('Failed to fetch messages:', err);
        }
      };

      fetchMessages();
    }
  }, [selectedRoom, token]);

  // Setup WebSocket connection
  useEffect(() => {
    if (selectedRoom) {
      // Close previous connection if exists
      if (ws) {
        ws.close();
      }

      const socket = new WebSocket(`ws://localhost:8000/ws/${currentUser.username}`);
      
      socket.onopen = () => {
        console.log('Connected to WebSocket');
        // Join the selected room
        socket.send(JSON.stringify({
          type: 'join_room',
          room: selectedRoom.name
        }));
      };
      
      socket.onmessage = (event) => {
        const data = JSON.parse(event.data);
        
        if (data.type === 'message' && data.room === selectedRoom.name) {
          setMessages(prev => [
            ...prev,
            {
              id: Date.now(), // In a real app, this would come from the backend
              content: data.content,
              timestamp: data.timestamp,
              sender_id: data.sender === currentUser.username ? currentUser.id : -1,
              sender_username: data.sender
            }
          ]);
        } else if (data.type === 'user_joined' && data.room === selectedRoom.name) {
          console.log(`${data.user} joined the room`);
        } else if (data.type === 'user_left' && data.room === selectedRoom.name) {
          console.log(`${data.user} left the room`);
        }
      };
      
      socket.onclose = () => {
        console.log('Disconnected from WebSocket');
      };
      
      setWs(socket);
      
      return () => {
        socket.close();
      };
    }
  }, [selectedRoom, currentUser]);

  // Scroll to bottom of messages
  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  const handleSendMessage = async () => {
    if (!newMessage.trim() || !selectedRoom || !ws) return;

    // Send via WebSocket
    ws.send(JSON.stringify({
      type: 'message',
      room: selectedRoom.name,
      content: newMessage
    }));

    setNewMessage('');
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSendMessage();
    }
  };

  return (
    <div className="chat-room">
      <div className="room-header">
        <h3>{selectedRoom ? selectedRoom.name : 'Select a room'}</h3>
      </div>
      
      <div className="messages-container">
        {messages.map((msg) => (
          <div 
            key={msg.id} 
            className={`message ${msg.sender_id === currentUser.id ? 'own-message' : ''}`}
          >
            <div className="message-content">
              {msg.sender_id !== currentUser.id && (
                <div className="message-sender">{msg.sender_username}</div>
              )}
              <div className="message-text">{msg.content}</div>
              <div className="message-time">{new Date(msg.timestamp).toLocaleTimeString()}</div>
            </div>
          </div>
        ))}
        <div ref={messagesEndRef} />
      </div>
      
      <div className="message-input-container">
        <textarea
          value={newMessage}
          onChange={(e) => setNewMessage(e.target.value)}
          onKeyDown={handleKeyDown}
          placeholder="Type your message..."
          className="message-input"
        />
        <button onClick={handleSendMessage} className="send-button">
          <i className="fas fa-paper-plane"></i>
        </button>
      </div>
    </div>
  );
};

export default ChatRoom;
