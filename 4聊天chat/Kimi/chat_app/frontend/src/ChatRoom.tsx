import React, { useState, useEffect, useRef, useContext } from 'react';
import { useNavigate } from 'react-router-dom';
import axios from 'axios';
import { AuthContext, API_BASE_URL, User } from './App';
import UserList from './UserList';

interface Room {
  id: number;
  name: string;
  description?: string;
  is_group: number;
  member_count: number;
  unread_count: number;
  last_message?: string;
  last_message_time?: string;
}

interface Message {
  id: number;
  content: string;
  sender_id: number;
  sender_name?: string;
  room_id: number;
  message_type: string;
  created_at: string;
}

const ChatRoom: React.FC = () => {
  const { user, token, logout } = useContext(AuthContext);
  const navigate = useNavigate();
  
  const [rooms, setRooms] = useState<Room[]>([]);
  const [currentRoom, setCurrentRoom] = useState<Room | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [newMessage, setNewMessage] = useState('');
  const [ws, setWs] = useState<WebSocket | null>(null);
  const [onlineUserIds, setOnlineUserIds] = useState<number[]>([]);
  const [showCreateRoom, setShowCreateRoom] = useState(false);
  const [newRoomName, setNewRoomName] = useState('');
  const [newRoomDesc, setNewRoomDesc] = useState('');
  const [selectedUsers, setSelectedUsers] = useState<number[]>([]);
  const [typingUsers, setTypingUsers] = useState<{[key: number]: string}>({});
  
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const typingTimeoutRef = useRef<{[key: number]: NodeJS.Timeout}>({});

  // 初始化WebSocket连接
  useEffect(() => {
    if (!token) return;

    const wsUrl = `ws://localhost:8000/ws/${token}`;
    const websocket = new WebSocket(wsUrl);

    websocket.onopen = () => {
      console.log('WebSocket连接已建立');
    };

    websocket.onmessage = (event) => {
      const data = JSON.parse(event.data);
      handleWebSocketMessage(data);
    };

    websocket.onclose = () => {
      console.log('WebSocket连接已关闭');
    };

    websocket.onerror = (error) => {
      console.error('WebSocket错误:', error);
    };

    setWs(websocket);

    return () => {
      websocket.close();
    };
  }, [token]);

  // 获取聊天室列表
  useEffect(() => {
    fetchRooms();
  }, [token]);

  // 滚动到底部
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const handleWebSocketMessage = (data: any) => {
    switch (data.type) {
      case 'message':
        setMessages(prev => [...prev, data.data]);
        // 更新最后一条消息
        setRooms(prev => prev.map(room => 
          room.id === data.data.room_id 
            ? { ...room, last_message: data.data.content, last_message_time: data.data.created_at }
            : room
        ));
        break;
      
      case 'online_users_changed':
        setOnlineUserIds(data.data.online_user_ids);
        break;
      
      case 'typing':
        const { user_id, username } = data.data;
        setTypingUsers(prev => ({ ...prev, [user_id]: username }));
        
        // 清除之前的超时
        if (typingTimeoutRef.current[user_id]) {
          clearTimeout(typingTimeoutRef.current[user_id]);
        }
        
        // 3秒后移除输入提示
        typingTimeoutRef.current[user_id] = setTimeout(() => {
          setTypingUsers(prev => {
            const newState = { ...prev };
            delete newState[user_id];
            return newState;
          });
        }, 3000);
        break;
      
      case 'join':
        console.log('用户加入房间:', data.data);
        break;
      
      case 'leave':
        console.log('用户离开房间:', data.data);
        break;
    }
  };

  const fetchRooms = async () => {
    try {
      const response = await axios.get(`${API_BASE_URL}/api/rooms`, {
        headers: { Authorization: `Bearer ${token}` }
      });
      setRooms(response.data);
    } catch (error) {
      console.error('获取聊天室列表失败:', error);
    }
  };

  const fetchMessages = async (roomId: number) => {
    try {
      const response = await axios.get(
        `${API_BASE_URL}/api/rooms/${roomId}/messages`,
        { headers: { Authorization: `Bearer ${token}` } }
      );
      setMessages(response.data);
    } catch (error) {
      console.error('获取消息失败:', error);
    }
  };

  const handleRoomSelect = (room: Room) => {
    setCurrentRoom(room);
    fetchMessages(room.id);
    
    // 加入房间
    if (ws && ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({
        type: 'join_room',
        data: { room_id: room.id }
      }));
    }
  };

  const handleSendMessage = () => {
    if (!newMessage.trim() || !currentRoom || !ws) return;

    ws.send(JSON.stringify({
      type: 'message',
      data: {
        room_id: currentRoom.id,
        content: newMessage.trim(),
        message_type: 'text'
      }
    }));

    setNewMessage('');
  };

  const handleTyping = () => {
    if (!currentRoom || !ws) return;

    ws.send(JSON.stringify({
      type: 'typing',
      data: { room_id: currentRoom.id }
    }));
  };

  const handleCreateRoom = async () => {
    if (!newRoomName.trim()) return;

    try {
      await axios.post(
        `${API_BASE_URL}/api/rooms`,
        {
          name: newRoomName.trim(),
          description: newRoomDesc.trim(),
          member_ids: selectedUsers,
          is_group: 1
        },
        { headers: { Authorization: `Bearer ${token}` } }
      );

      setShowCreateRoom(false);
      setNewRoomName('');
      setNewRoomDesc('');
      setSelectedUsers([]);
      fetchRooms();
    } catch (error) {
      console.error('创建聊天室失败:', error);
      alert('创建聊天室失败');
    }
  };

  const handleLogout = async () => {
    try {
      await axios.post(
        `${API_BASE_URL}/api/auth/logout`,
        {},
        { headers: { Authorization: `Bearer ${token}` } }
      );
    } catch (error) {
      console.error('登出失败:', error);
    } finally {
      logout();
      navigate('/login');
    }
  };

  const handleUserSelect = (selectedUser: User) => {
    // 创建私聊房间
    setSelectedUsers(prev => {
      if (prev.includes(selectedUser.id)) {
        return prev.filter(id => id !== selectedUser.id);
      }
      return [...prev, selectedUser.id];
    });
  };

  const formatTime = (timeString?: string) => {
    if (!timeString) return '';
    const date = new Date(timeString);
    return date.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' });
  };

  const formatDate = (timeString?: string) => {
    if (!timeString) return '';
    const date = new Date(timeString);
    const now = new Date();
    const isToday = date.toDateString() === now.toDateString();
    
    if (isToday) {
      return date.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' });
    }
    return date.toLocaleDateString('zh-CN', { month: 'short', day: 'numeric' });
  };

  return (
    <div style={styles.container}>
      {/* 左侧边栏 */}
      <div style={styles.sidebar}>
        {/* 用户信息 */}
        <div style={styles.userInfo}>
          <div style={styles.userAvatar}>
            {user?.username.charAt(0).toUpperCase()}
          </div>
          <div style={styles.userDetails}>
            <span style={styles.userName}>{user?.username}</span>
            <span style={styles.userStatus}>在线</span>
          </div>
          <button onClick={handleLogout} style={styles.logoutBtn}>
            退出
          </button>
        </div>

        {/* 创建房间按钮 */}
        <button 
          onClick={() => setShowCreateRoom(true)} 
          style={styles.createRoomBtn}
        >
          + 创建聊天室
        </button>

        {/* 聊天室列表 */}
        <div style={styles.roomList}>
          <h4 style={styles.sectionTitle}>聊天室</h4>
          {rooms.map(room => (
            <div
              key={room.id}
              style={{
                ...styles.roomItem,
                ...(currentRoom?.id === room.id ? styles.roomItemActive : {}),
              }}
              onClick={() => handleRoomSelect(room)}
            >
              <div style={styles.roomAvatar}>
                {room.name.charAt(0).toUpperCase()}
              </div>
              <div style={styles.roomInfo}>
                <div style={styles.roomHeader}>
                  <span style={styles.roomName}>{room.name}</span>
                  <span style={styles.roomTime}>{formatDate(room.last_message_time)}</span>
                </div>
                <div style={styles.roomPreview}>
                  <span style={styles.lastMessage}>{room.last_message || '暂无消息'}</span>
                  {room.unread_count > 0 && (
                    <span style={styles.unreadBadge}>{room.unread_count}</span>
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>

        {/* 在线用户列表 */}
        <UserList 
          token={token || ''} 
          onlineUserIds={onlineUserIds}
          onSelectUser={() => {}}
        />
      </div>

      {/* 主聊天区域 */}
      <div style={styles.mainContent}>
        {currentRoom ? (
          <>
            {/* 聊天头部 */}
            <div style={styles.chatHeader}>
              <h3 style={styles.chatTitle}>{currentRoom.name}</h3>
              <span style={styles.memberCount}>{currentRoom.member_count} 人</span>
            </div>

            {/* 消息列表 */}
            <div style={styles.messageList}>
              {messages.map(msg => (
                <div
                  key={msg.id}
                  style={{
                    ...styles.messageItem,
                    ...(msg.sender_id === user?.id ? styles.messageItemSelf : {}),
                  }}
                >
                  {msg.sender_id !== user?.id && (
                    <div style={styles.messageAvatar}>
                      {msg.sender_name?.charAt(0).toUpperCase()}
                    </div>
                  )}
                  <div style={styles.messageContent}>
                    {msg.sender_id !== user?.id && (
                      <span style={styles.messageSender}>{msg.sender_name}</span>
                    )}
                    <div
                      style={{
                        ...styles.messageBubble,
                        ...(msg.sender_id === user?.id ? styles.messageBubbleSelf : {}),
                      }}
                    >
                      {msg.content}
                    </div>
                    <span style={styles.messageTime}>
                      {formatTime(msg.created_at)}
                    </span>
                  </div>
                </div>
              ))}
              
              {/* 正在输入提示 */}
              {Object.entries(typingUsers).map(([userId, username]) => (
                <div key={userId} style={styles.typingIndicator}>
                  {username} 正在输入...
                </div>
              ))}
              
              <div ref={messagesEndRef} />
            </div>

            {/* 输入区域 */}
            <div style={styles.inputArea}>
              <input
                type="text"
                value={newMessage}
                onChange={(e) => setNewMessage(e.target.value)}
                onKeyPress={(e) => {
                  if (e.key === 'Enter') {
                    handleSendMessage();
                  } else {
                    handleTyping();
                  }
                }}
                style={styles.messageInput}
                placeholder="输入消息..."
              />
              <button onClick={handleSendMessage} style={styles.sendBtn}>
                发送
              </button>
            </div>
          </>
        ) : (
          <div style={styles.emptyState}>
            <p>选择一个聊天室开始聊天</p>
          </div>
        )}
      </div>

      {/* 创建房间弹窗 */}
      {showCreateRoom && (
        <div style={styles.modalOverlay}>
          <div style={styles.modal}>
            <h3 style={styles.modalTitle}>创建聊天室</h3>
            <input
              type="text"
              placeholder="聊天室名称"
              value={newRoomName}
              onChange={(e) => setNewRoomName(e.target.value)}
              style={styles.modalInput}
            />
            <input
              type="text"
              placeholder="描述（可选）"
              value={newRoomDesc}
              onChange={(e) => setNewRoomDesc(e.target.value)}
              style={styles.modalInput}
            />
            <div style={styles.modalButtons}>
              <button 
                onClick={() => setShowCreateRoom(false)} 
                style={styles.modalBtnSecondary}
              >
                取消
              </button>
              <button onClick={handleCreateRoom} style={styles.modalBtnPrimary}>
                创建
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

const styles: { [key: string]: React.CSSProperties } = {
  container: {
    display: 'flex',
    height: '100vh',
    backgroundColor: '#f5f5f5',
  },
  sidebar: {
    width: '300px',
    backgroundColor: '#fff',
    borderRight: '1px solid #e0e0e0',
    display: 'flex',
    flexDirection: 'column',
    overflow: 'hidden',
  },
  userInfo: {
    display: 'flex',
    alignItems: 'center',
    padding: '16px',
    borderBottom: '1px solid #e0e0e0',
  },
  userAvatar: {
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
  userDetails: {
    flex: 1,
    display: 'flex',
    flexDirection: 'column',
  },
  userName: {
    fontSize: '14px',
    fontWeight: '500',
    color: '#333',
  },
  userStatus: {
    fontSize: '12px',
    color: '#07c160',
  },
  logoutBtn: {
    padding: '6px 12px',
    backgroundColor: '#ff4d4f',
    color: '#fff',
    border: 'none',
    borderRadius: '4px',
    fontSize: '12px',
    cursor: 'pointer',
  },
  createRoomBtn: {
    margin: '12px 16px',
    padding: '10px',
    backgroundColor: '#07c160',
    color: '#fff',
    border: 'none',
    borderRadius: '6px',
    fontSize: '14px',
    cursor: 'pointer',
  },
  roomList: {
    flex: 1,
    overflowY: 'auto',
    padding: '0 8px',
  },
  sectionTitle: {
    padding: '8px',
    margin: 0,
    fontSize: '12px',
    color: '#999',
    fontWeight: 'normal',
  },
  roomItem: {
    display: 'flex',
    alignItems: 'center',
    padding: '12px 8px',
    cursor: 'pointer',
    borderRadius: '8px',
    marginBottom: '4px',
    transition: 'background-color 0.2s',
  },
  roomItemActive: {
    backgroundColor: '#e6f7ed',
  },
  roomAvatar: {
    width: '48px',
    height: '48px',
    borderRadius: '8px',
    backgroundColor: '#07c160',
    color: '#fff',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    fontSize: '20px',
    fontWeight: 'bold',
    marginRight: '12px',
  },
  roomInfo: {
    flex: 1,
    minWidth: 0,
  },
  roomHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '4px',
  },
  roomName: {
    fontSize: '14px',
    fontWeight: '500',
    color: '#333',
    overflow: 'hidden',
    textOverflow: 'ellipsis',
    whiteSpace: 'nowrap',
  },
  roomTime: {
    fontSize: '11px',
    color: '#999',
  },
  roomPreview: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  lastMessage: {
    fontSize: '12px',
    color: '#999',
    overflow: 'hidden',
    textOverflow: 'ellipsis',
    whiteSpace: 'nowrap',
    flex: 1,
  },
  unreadBadge: {
    backgroundColor: '#ff4d4f',
    color: '#fff',
    fontSize: '11px',
    padding: '2px 6px',
    borderRadius: '10px',
    minWidth: '18px',
    textAlign: 'center',
  },
  mainContent: {
    flex: 1,
    display: 'flex',
    flexDirection: 'column',
    backgroundColor: '#f5f5f5',
  },
  chatHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: '16px 24px',
    backgroundColor: '#fff',
    borderBottom: '1px solid #e0e0e0',
  },
  chatTitle: {
    margin: 0,
    fontSize: '16px',
    fontWeight: '500',
    color: '#333',
  },
  memberCount: {
    fontSize: '13px',
    color: '#999',
  },
  messageList: {
    flex: 1,
    overflowY: 'auto',
    padding: '20px',
  },
  messageItem: {
    display: 'flex',
    marginBottom: '16px',
    alignItems: 'flex-start',
  },
  messageItemSelf: {
    flexDirection: 'row-reverse',
  },
  messageAvatar: {
    width: '36px',
    height: '36px',
    borderRadius: '50%',
    backgroundColor: '#07c160',
    color: '#fff',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    fontSize: '14px',
    fontWeight: 'bold',
    marginRight: '12px',
  },
  messageContent: {
    display: 'flex',
    flexDirection: 'column',
    maxWidth: '60%',
  },
  messageSender: {
    fontSize: '12px',
    color: '#999',
    marginBottom: '4px',
  },
  messageBubble: {
    padding: '10px 14px',
    backgroundColor: '#fff',
    borderRadius: '8px',
    fontSize: '14px',
    color: '#333',
    wordBreak: 'break-word',
    boxShadow: '0 1px 2px rgba(0, 0, 0, 0.1)',
  },
  messageBubbleSelf: {
    backgroundColor: '#95ec69',
  },
  messageTime: {
    fontSize: '11px',
    color: '#999',
    marginTop: '4px',
    alignSelf: 'flex-end',
  },
  typingIndicator: {
    fontSize: '12px',
    color: '#999',
    fontStyle: 'italic',
    marginBottom: '8px',
    paddingLeft: '48px',
  },
  inputArea: {
    display: 'flex',
    padding: '16px 24px',
    backgroundColor: '#fff',
    borderTop: '1px solid #e0e0e0',
    gap: '12px',
  },
  messageInput: {
    flex: 1,
    padding: '12px 16px',
    border: '1px solid #ddd',
    borderRadius: '8px',
    fontSize: '14px',
    outline: 'none',
  },
  sendBtn: {
    padding: '12px 24px',
    backgroundColor: '#07c160',
    color: '#fff',
    border: 'none',
    borderRadius: '8px',
    fontSize: '14px',
    cursor: 'pointer',
  },
  emptyState: {
    flex: 1,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    color: '#999',
    fontSize: '16px',
  },
  modalOverlay: {
    position: 'fixed',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 1000,
  },
  modal: {
    backgroundColor: '#fff',
    borderRadius: '12px',
    padding: '24px',
    width: '90%',
    maxWidth: '400px',
  },
  modalTitle: {
    margin: '0 0 20px 0',
    fontSize: '18px',
    fontWeight: '600',
    color: '#333',
  },
  modalInput: {
    width: '100%',
    padding: '12px',
    border: '1px solid #ddd',
    borderRadius: '8px',
    fontSize: '14px',
    marginBottom: '12px',
    outline: 'none',
  },
  modalButtons: {
    display: 'flex',
    justifyContent: 'flex-end',
    gap: '12px',
    marginTop: '20px',
  },
  modalBtnSecondary: {
    padding: '10px 20px',
    backgroundColor: '#f5f5f5',
    color: '#666',
    border: 'none',
    borderRadius: '6px',
    fontSize: '14px',
    cursor: 'pointer',
  },
  modalBtnPrimary: {
    padding: '10px 20px',
    backgroundColor: '#07c160',
    color: '#fff',
    border: 'none',
    borderRadius: '6px',
    fontSize: '14px',
    cursor: 'pointer',
  },
};

export default ChatRoom;
