import React, { useState, useEffect, useRef } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import axios from 'axios';

interface User {
  id: number;
  username: string;
  email: string;
  is_active: boolean;
}

interface Message {
  id: number;
  sender_id: number;
  room_id: number;
  content: string;
  created_at: string;
  is_read: boolean;
  sender?: User;
}

interface ChatRoomProps {
  user: User;
  api: axios.AxiosInstance;
  wsBaseUrl: string;
  onSendMessage: (roomId: number, content: string) => Promise<{ success: boolean; error?: string; message?: Message }>;
  onGetMessages: (roomId: number) => Promise<{ success: boolean; error?: string; messages?: Message[] }>;
}

const ChatRoom: React.FC<ChatRoomProps> = ({ user, api, wsBaseUrl, onSendMessage, onGetMessages }) => {
  const { roomId } = useParams<{ roomId: string }>();
  const navigate = useNavigate();
  const [room, setRoom] = useState<{ id: number; name: string; members: any[] } | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [newMessage, setNewMessage] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [sending, setSending] = useState(false);
  const [typing, setTyping] = useState(false);
  const [typingUsers, setTypingUsers] = useState<Set<number>>(new Set());
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const typingTimeoutRef = useRef<NodeJS.Timeout | null>(null);
  const wsRef = useRef<WebSocket | null>(null);

  // 获取聊天室信息和消息
  useEffect(() => {
    const fetchRoomData = async () => {
      if (!roomId) {
        navigate('/');
        return;
      }

      try {
        // 获取聊天室信息
        const roomResponse = await api.get(`/rooms/${roomId}`);
        setRoom(roomResponse.data);

        // 获取聊天记录
        const messagesResult = await onGetMessages(parseInt(roomId));
        if (messagesResult.success && messagesResult.messages) {
          setMessages(messagesResult.messages);
        } else {
          setError(messagesResult.error || 'Failed to load messages');
        }

        setLoading(false);
      } catch (error) {
        console.error('Error fetching room data:', error);
        setError('Failed to load room data');
        setLoading(false);
      }
    };

    fetchRoomData();
  }, [roomId, navigate, api, onGetMessages]);

  // 建立WebSocket连接
  useEffect(() => {
    if (!roomId || !user) return;

    const token = localStorage.getItem('token');
    if (!token) {
      navigate('/login');
      return;
    }

    // 建立WebSocket连接
    const ws = new WebSocket(`${wsBaseUrl}/chat/${roomId}?token=${token}`);
    
    ws.onopen = () => {
      console.log('WebSocket connected');
    };

    ws.onmessage = (event) => {
      const data = JSON.parse(event.data);
      
      if (data.type === 'message') {
        // 收到新消息
        setMessages(prevMessages => [...prevMessages, data.data]);
      } else if (data.type === 'user_joined') {
        // 用户加入聊天室
        console.log('User joined:', data.data.user_id);
        // 可以更新聊天室成员列表
      } else if (data.type === 'user_left') {
        // 用户离开聊天室
        console.log('User left:', data.data.user_id);
        // 可以更新聊天室成员列表
      } else if (data.type === 'typing') {
        // 用户正在输入
        const { user_id, is_typing } = data.data;
        if (user_id !== user.id) {
          setTypingUsers(prev => {
            const newSet = new Set(prev);
            if (is_typing) {
              newSet.add(user_id);
            } else {
              newSet.delete(user_id);
            }
            return newSet;
          });
        }
      }
    };

    ws.onclose = () => {
      console.log('WebSocket disconnected');
    };

    ws.onerror = (error) => {
      console.error('WebSocket error:', error);
    };

    wsRef.current = ws;

    return () => {
      ws.close();
    };
  }, [roomId, user, wsBaseUrl, navigate]);

  // 滚动到最新消息
  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  // 处理发送消息
  const handleSendMessage = async () => {
    if (!newMessage.trim() || sending || !roomId) return;

    setSending(true);
    
    // 发送"停止输入"信号
    if (wsRef.current && wsRef.current.readyState === WebSocket.OPEN) {
      wsRef.current.send(JSON.stringify({
        type: 'typing',
        data: { is_typing: false }
      }));
    }
    
    // 发送消息
    const result = await onSendMessage(parseInt(roomId), newMessage);
    
    if (result.success) {
      setNewMessage('');
    } else {
      setError(result.error || 'Failed to send message');
    }
    
    setSending(false);
  };

  // 处理输入变化
  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setNewMessage(e.target.value);
    
    // 发送"正在输入"信号
    if (!typing && wsRef.current && wsRef.current.readyState === WebSocket.OPEN) {
      setTyping(true);
      wsRef.current.send(JSON.stringify({
        type: 'typing',
        data: { is_typing: true }
      }));
    }
    
    // 清除之前的定时器
    if (typingTimeoutRef.current) {
      clearTimeout(typingTimeoutRef.current);
    }
    
    // 设置新的定时器
    typingTimeoutRef.current = setTimeout(() => {
      if (wsRef.current && wsRef.current.readyState === WebSocket.OPEN) {
        wsRef.current.send(JSON.stringify({
          type: 'typing',
          data: { is_typing: false }
        }));
        setTyping(false);
      }
    }, 1000);
  };

  // 处理按键事件
  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSendMessage();
    }
  };

  // 获取正在输入的用户名称
  const getTypingUserNames = () => {
    if (!room || typingUsers.size === 0) return '';
    
    const names = Array.from(typingUsers).map(userId => {
      const member = room.members.find(m => m.user_id === userId);
      return member ? member.user.username : '';
    }).filter(Boolean);
    
    if (names.length === 1) {
      return `${names[0]} is typing...`;
    } else if (names.length > 1) {
      return `${names.join(', ')} are typing...`;
    }
    
    return '';
  };

  if (loading) {
    return <div className="loading">Loading...</div>;
  }

  if (error) {
    return <div className="error">{error}</div>;
  }

  if (!room) {
    return <div className="error">Room not found</div>;
  }

  return (
    <div className="chatroom">
      <div className="chatroom-header">
        <h2>{room.name}</h2>
        <button onClick={() => navigate('/')}>Back to Rooms</button>
      </div>
      
      <div className="chatroom-messages">
        {messages.length === 0 ? (
          <div className="no-messages">No messages yet. Start the conversation!</div>
        ) : (
          messages.map((message) => (
            <div 
              key={message.id} 
              className={`message ${message.sender_id === user.id ? 'own-message' : 'other-message'}`}
            >
              <div className="message-header">
                <span className="message-sender">
                  {message.sender ? message.sender.username : 'Unknown User'}
                </span>
                <span className="message-time">
                  {new Date(message.created_at).toLocaleTimeString()}
                </span>
              </div>
              <div className="message-content">{message.content}</div>
            </div>
          ))
        )}
        <div ref={messagesEndRef} />
        <div className="typing-indicator">{getTypingUserNames()}</div>
      </div>
      
      <div className="chatroom-input">
        <input
          type="text"
          placeholder="Type a message..."
          value={newMessage}
          onChange={handleInputChange}
          onKeyPress={handleKeyPress}
          disabled={sending}
        />
        <button onClick={handleSendMessage} disabled={sending || !newMessage.trim()}>
          {sending ? 'Sending...' : 'Send'}
        </button>
      </div>
      
      <style jsx>{`
        .chatroom {
          display: flex;
          flex-direction: column;
          height: 100vh;
          max-width: 1200px;
          margin: 0 auto;
          background-color: #fff;
        }
        
        .chatroom-header {
          display: flex;
          justify-content: space-between;
          align-items: center;
          padding: 1rem;
          background-color: #007bff;
          color: white;
        }
        
        .chatroom-header h2 {
          margin: 0;
        }
        
        .chatroom-header button {
          padding: 0.5rem 1rem;
          background-color: transparent;
          color: white;
          border: 1px solid white;
          border-radius: 4px;
          cursor: pointer;
        }
        
        .chatroom-header button:hover {
          background-color: rgba(255, 255, 255, 0.1);
        }
        
        .chatroom-messages {
          flex: 1;
          overflow-y: auto;
          padding: 1rem;
          background-color: #f5f5f5;
        }
        
        .message {
          margin-bottom: 1rem;
          padding: 0.75rem;
          border-radius: 8px;
          max-width: 80%;
        }
        
        .own-message {
          background-color: #007bff;
          color: white;
          margin-left: auto;
        }
        
        .other-message {
          background-color: #e9ecef;
          color: #333;
        }
        
        .message-header {
          display: flex;
          justify-content: space-between;
          margin-bottom: 0.25rem;
          font-size: 0.875rem;
        }
        
        .message-sender {
          font-weight: 500;
        }
        
        .message-time {
          opacity: 0.7;
        }
        
        .message-content {
          word-wrap: break-word;
        }
        
        .no-messages {
          text-align: center;
          color: #6c757d;
          margin-top: 2rem;
        }
        
        .typing-indicator {
          color: #6c757d;
          font-style: italic;
          font-size: 0.875rem;
          margin-top: 0.5rem;
        }
        
        .chatroom-input {
          display: flex;
          padding: 1rem;
          background-color: #fff;
          border-top: 1px solid #e9ecef;
        }
        
        .chatroom-input input {
          flex: 1;
          padding: 0.75rem;
          border: 1px solid #ddd;
          border-radius: 4px 0 0 4px;
          font-size: 1rem;
        }
        
        .chatroom-input input:focus {
          outline: none;
          border-color: #007bff;
        }
        
        .chatroom-input button {
          padding: 0.75rem 1.5rem;
          background-color: #007bff;
          color: white;
          border: none;
          border-radius: 0 4px 4px 0;
          cursor: pointer;
        }
        
        .chatroom-input button:hover {
          background-color: #0069d9;
        }
        
        .chatroom-input button:disabled {
          background-color: #6c757d;
          cursor: not-allowed;
        }
        
        .loading {
          display: flex;
          justify-content: center;
          align-items: center;
          height: 100vh;
          font-size: 1.25rem;
          color: #6c757d;
        }
        
        .error {
          display: flex;
          justify-content: center;
          align-items: center;
          height: 100vh;
          font-size: 1.25rem;
          color: #dc3545;
        }
      `}</style>
    </div>
  );
};

export default ChatRoom;