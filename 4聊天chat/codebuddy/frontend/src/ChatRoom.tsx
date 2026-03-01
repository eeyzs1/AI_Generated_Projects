import React, { useEffect, useState, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { useWebSocket } from './WebSocketContext';
import { authAPI, roomAPI, messageAPI } from './api';
import type { User, Room, RoomDetail, Message, WSMessage } from './types';
import UserList from './UserList';

const ChatRoom: React.FC = () => {
  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const [rooms, setRooms] = useState<Room[]>([]);
  const [selectedRoom, setSelectedRoom] = useState<Room | null>(null);
  const [roomDetail, setRoomDetail] = useState<RoomDetail | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [newMessage, setNewMessage] = useState('');
  const [newRoomName, setNewRoomName] = useState('');
  const [showCreateRoom, setShowCreateRoom] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const { onlineUsers, sendMessage, onMessage } = useWebSocket();
  const navigate = useNavigate();

  useEffect(() => {
    loadCurrentUser();
    loadRooms();
  }, []);

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  useEffect(() => {
    const unsubscribe = onMessage((wsMessage: WSMessage) => {
      if (wsMessage.type === 'message' && selectedRoom) {
        // 如果是新消息且属于当前房间，添加到消息列表
        if (wsMessage.data.room_id === selectedRoom.id) {
          setMessages((prev) => [
            ...prev,
            {
              id: wsMessage.data.id,
              room_id: wsMessage.data.room_id,
              sender_id: wsMessage.data.sender_id,
              sender_username: wsMessage.data.sender_username,
              content: wsMessage.data.content,
              created_at: wsMessage.data.created_at,
            },
          ]);
        }
      }
    });

    return unsubscribe;
  }, [selectedRoom]);

  const loadCurrentUser = async () => {
    try {
      const response = await authAPI.getMe();
      setCurrentUser(response.data);
    } catch (error) {
      console.error('Failed to load user:', error);
      navigate('/login');
    }
  };

  const loadRooms = async () => {
    try {
      const response = await roomAPI.getAll();
      setRooms(response.data);
    } catch (error) {
      console.error('Failed to load rooms:', error);
    }
  };

  const loadMessages = async (roomId: number) => {
    try {
      const response = await messageAPI.getRoomMessages(roomId);
      setMessages(response.data);
    } catch (error) {
      console.error('Failed to load messages:', error);
    }
  };

  const loadRoomDetail = async (roomId: number) => {
    try {
      const response = await roomAPI.getDetail(roomId);
      setRoomDetail(response.data);
    } catch (error) {
      console.error('Failed to load room detail:', error);
    }
  };

  const handleSelectRoom = (room: Room) => {
    setSelectedRoom(room);
    loadMessages(room.id);
    loadRoomDetail(room.id);
  };

  const handleCreateRoom = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newRoomName.trim()) return;

    try {
      const response = await roomAPI.create(newRoomName);
      setRooms((prev) => [...prev, response.data]);
      setNewRoomName('');
      setShowCreateRoom(false);
      // 自动选择新创建的房间
      handleSelectRoom(response.data);
    } catch (error) {
      console.error('Failed to create room:', error);
    }
  };

  const handleSendMessage = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newMessage.trim() || !selectedRoom) return;

    sendMessage({
      type: 'message',
      room_id: selectedRoom.id,
      content: newMessage,
    });

    setNewMessage('');
  };

  const handleAddToRoom = async (userId: number) => {
    if (!selectedRoom) return;

    try {
      await roomAPI.addMember(selectedRoom.id, userId);
      // 重新加载房间详情
      await loadRoomDetail(selectedRoom.id);
      alert('添加成功');
    } catch (error: any) {
      alert(error.response?.data?.detail || '添加失败');
    }
  };

  const handleLogout = () => {
    localStorage.removeItem('token');
    navigate('/login');
  };

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  const formatTime = (dateString: string) => {
    const date = new Date(dateString);
    return date.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' });
  };

  if (!currentUser) {
    return <div style={styles.loading}>加载中...</div>;
  }

  return (
    <div style={styles.container}>
      {/* 侧边栏 */}
      <div style={styles.sidebar}>
        <div style={styles.sidebarHeader}>
          <h2 style={styles.logo}>Chat App</h2>
          <button style={styles.logoutButton} onClick={handleLogout}>
            退出
          </button>
        </div>

        <div style={styles.section}>
          <div style={styles.sectionHeader}>
            <h3 style={styles.sectionTitle}>聊天室</h3>
            <button
              style={styles.addButton}
              onClick={() => setShowCreateRoom(!showCreateRoom)}
            >
              {showCreateRoom ? '取消' : '+'}
            </button>
          </div>

          {showCreateRoom && (
            <form onSubmit={handleCreateRoom} style={styles.createRoomForm}>
              <input
                type="text"
                value={newRoomName}
                onChange={(e) => setNewRoomName(e.target.value)}
                placeholder="聊天室名称"
                style={styles.createRoomInput}
              />
              <button type="submit" style={styles.createRoomButton}>
                创建
              </button>
            </form>
          )}

          <div style={styles.roomList}>
            {rooms.map((room) => (
              <div
                key={room.id}
                style={{
                  ...styles.roomItem,
                  backgroundColor: selectedRoom?.id === room.id ? '#e3f2fd' : 'transparent',
                }}
                onClick={() => handleSelectRoom(room)}
              >
                <div style={styles.roomName}>{room.name}</div>
              </div>
            ))}
          </div>
        </div>

        <div style={styles.onlineStatus}>
          <span style={styles.onlineCount}>
            在线用户: {onlineUsers.length}
          </span>
        </div>
      </div>

      {/* 主聊天区域 */}
      <div style={styles.mainContent}>
        {selectedRoom ? (
          <>
            <div style={styles.chatHeader}>
              <h3 style={styles.chatTitle}>{selectedRoom.name}</h3>
            </div>

            <div style={styles.messagesContainer}>
              {messages.length === 0 ? (
                <div style={styles.emptyMessages}>
                  暂无消息，开始聊天吧！
                </div>
              ) : (
                messages.map((message) => (
                  <div
                    key={message.id}
                    style={{
                      ...styles.message,
                      alignSelf:
                        message.sender_id === currentUser.id
                          ? 'flex-end'
                          : 'flex-start',
                    }}
                  >
                    <div
                      style={{
                        ...styles.messageBubble,
                        backgroundColor:
                          message.sender_id === currentUser.id
                            ? '#007bff'
                            : '#f1f0f0',
                        color:
                          message.sender_id === currentUser.id
                            ? 'white'
                            : '#333',
                      }}
                    >
                      {message.sender_id !== currentUser.id && (
                        <div style={styles.messageSender}>
                          {message.sender_username}
                        </div>
                      )}
                      <div style={styles.messageContent}>{message.content}</div>
                      <div style={styles.messageTime}>{formatTime(message.created_at)}</div>
                    </div>
                  </div>
                ))
              )}
              <div ref={messagesEndRef} />
            </div>

            <form onSubmit={handleSendMessage} style={styles.messageInputForm}>
              <input
                type="text"
                value={newMessage}
                onChange={(e) => setNewMessage(e.target.value)}
                placeholder="输入消息..."
                style={styles.messageInput}
              />
              <button type="submit" style={styles.sendButton}>
                发送
              </button>
            </form>
          </>
        ) : (
          <div style={styles.emptyState}>
            <h3>选择一个聊天室开始聊天</h3>
          </div>
        )}
      </div>

      {/* 用户列表 */}
      <UserList
        currentUser={currentUser}
        onAddToRoom={handleAddToRoom}
        currentRoomId={selectedRoom?.id || null}
      />
    </div>
  );
};

const styles: { [key: string]: React.CSSProperties } = {
  container: {
    display: 'flex',
    height: '100vh',
    backgroundColor: '#f5f5f5',
  },
  loading: {
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    height: '100vh',
    fontSize: '1.2rem',
  },
  sidebar: {
    width: '280px',
    backgroundColor: 'white',
    borderRight: '1px solid #e0e0e0',
    display: 'flex',
    flexDirection: 'column',
  },
  sidebarHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: '1rem',
    borderBottom: '1px solid #e0e0e0',
  },
  logo: {
    margin: 0,
    color: '#007bff',
    fontSize: '1.5rem',
  },
  logoutButton: {
    padding: '0.5rem 1rem',
    backgroundColor: '#dc3545',
    color: 'white',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
  },
  section: {
    flex: 1,
    padding: '1rem',
    overflowY: 'auto',
  },
  sectionHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '1rem',
  },
  sectionTitle: {
    margin: 0,
    fontSize: '1rem',
    color: '#333',
  },
  addButton: {
    padding: '0.25rem 0.75rem',
    backgroundColor: '#007bff',
    color: 'white',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    fontSize: '1.2rem',
    lineHeight: 1,
  },
  createRoomForm: {
    display: 'flex',
    gap: '0.5rem',
    marginBottom: '1rem',
  },
  createRoomInput: {
    flex: 1,
    padding: '0.5rem',
    border: '1px solid #ddd',
    borderRadius: '4px',
  },
  createRoomButton: {
    padding: '0.5rem 1rem',
    backgroundColor: '#28a745',
    color: 'white',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
  },
  roomList: {
    display: 'flex',
    flexDirection: 'column',
    gap: '0.25rem',
  },
  roomItem: {
    padding: '0.75rem',
    borderRadius: '4px',
    cursor: 'pointer',
    transition: 'background-color 0.2s',
  },
  roomName: {
    color: '#333',
    fontWeight: '500',
  },
  onlineStatus: {
    padding: '1rem',
    borderTop: '1px solid #e0e0e0',
  },
  onlineCount: {
    fontSize: '0.9rem',
    color: '#666',
  },
  mainContent: {
    flex: 1,
    display: 'flex',
    flexDirection: 'column',
    backgroundColor: 'white',
  },
  chatHeader: {
    padding: '1rem',
    borderBottom: '1px solid #e0e0e0',
  },
  chatTitle: {
    margin: 0,
    color: '#333',
  },
  messagesContainer: {
    flex: 1,
    padding: '1rem',
    overflowY: 'auto',
    display: 'flex',
    flexDirection: 'column',
    gap: '0.75rem',
  },
  emptyMessages: {
    textAlign: 'center',
    color: '#999',
    marginTop: '2rem',
  },
  emptyState: {
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    height: '100%',
    color: '#999',
  },
  message: {
    display: 'flex',
    maxWidth: '70%',
  },
  messageBubble: {
    padding: '0.75rem 1rem',
    borderRadius: '12px',
    boxShadow: '0 1px 2px rgba(0,0,0,0.1)',
  },
  messageSender: {
    fontSize: '0.85rem',
    marginBottom: '0.25rem',
    fontWeight: '500',
    opacity: 0.8,
  },
  messageContent: {
    wordBreak: 'break-word',
  },
  messageTime: {
    fontSize: '0.75rem',
    marginTop: '0.25rem',
    opacity: 0.7,
  },
  messageInputForm: {
    display: 'flex',
    gap: '0.5rem',
    padding: '1rem',
    borderTop: '1px solid #e0e0e0',
  },
  messageInput: {
    flex: 1,
    padding: '0.75rem',
    border: '1px solid #ddd',
    borderRadius: '24px',
    fontSize: '1rem',
    outline: 'none',
  },
  sendButton: {
    padding: '0.75rem 1.5rem',
    backgroundColor: '#007bff',
    color: 'white',
    border: 'none',
    borderRadius: '24px',
    cursor: 'pointer',
    fontWeight: '500',
  },
};

export default ChatRoom;
