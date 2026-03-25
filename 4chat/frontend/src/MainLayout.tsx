import React, { useState, useEffect, useRef } from 'react';
import { Layout, Menu, Button, Input, Avatar, Badge, message, Card, Modal } from 'antd';
import { useNavigate } from 'react-router-dom';
import { PlusOutlined, UserOutlined, TeamOutlined, MessageOutlined, BellOutlined, SettingOutlined } from '@ant-design/icons';

const { Header, Sider, Content } = Layout;
const { Search } = Input;

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
  lastMessage?: string;
  lastMessageTime?: string;
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

interface MainLayoutProps {
  user: User;
  onLogout: () => void;
  authenticatedFetch: (url: string, options?: RequestInit) => Promise<Response>;
}

const MainLayout: React.FC<MainLayoutProps> = ({ user, onLogout, authenticatedFetch }) => {
  const navigate = useNavigate();
  const [rooms, setRooms] = useState<Room[]>([]);
  const [selectedRoom, setSelectedRoom] = useState<Room | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [newMessage, setNewMessage] = useState('');
  const [newRoomName, setNewRoomName] = useState('');
  const [showCreateRoomModal, setShowCreateRoomModal] = useState(false);
  const [invitations, setInvitations] = useState<Invitation[]>([]);
  const [showInvitations, setShowInvitations] = useState(false);
  const [inviteeUsername, setInviteeUsername] = useState('');
  const [ws, setWs] = useState<WebSocket | null>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const [isLoading, setIsLoading] = useState(false);

  // 加载聊天室列表
  useEffect(() => {
    const loadRooms = async () => {
      setIsLoading(true);
      try {
        const response = await authenticatedFetch('/api/group/rooms');
        const data = await response.json();
        setRooms(Array.isArray(data) ? data : []);
        if (Array.isArray(data) && data.length > 0 && !selectedRoom) {
          setSelectedRoom(data[0]);
        }
      } catch (error) {
        console.error('Error loading rooms:', error);
        message.error('Failed to load rooms');
      } finally {
        setIsLoading(false);
      }
    };

    loadRooms();
  }, [authenticatedFetch, selectedRoom]);

  // 加载邀请列表
  useEffect(() => {
    const loadInvitations = async () => {
      try {
        const response = await authenticatedFetch('/api/group/invitations');
        const data = await response.json();
        setInvitations(Array.isArray(data) ? data : []);
      } catch (error) {
        console.error('Error loading invitations:', error);
      }
    };

    loadInvitations();
  }, [authenticatedFetch]);

  // 加载聊天室消息
  useEffect(() => {
    if (selectedRoom) {
      const loadMessages = async () => {
        try {
          const response = await authenticatedFetch(`/api/message/rooms/${selectedRoom.id}/messages`);
          const data = await response.json();
          setMessages(Array.isArray(data) ? data : []);
        } catch (error) {
          console.error('Error loading messages:', error);
          message.error('Failed to load messages');
        }
      };

      loadMessages();
    }
  }, [selectedRoom, authenticatedFetch]);

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

          if (data.type === 'msg_sent') {
            // 更新消息列表
            if (data.room_id === selectedRoom?.id) {
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
            // 更新房间列表中的最后一条消息
            setRooms(prev => prev.map(room => {
              if (room.id === data.room_id) {
                return {
                  ...room,
                  lastMessage: data.content,
                  lastMessageTime: data.created_at
                };
              }
              return room;
            }));
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
  }, [user.id]);

  // 处理房间选择
  const handleRoomSelect = (room: Room) => {
    setSelectedRoom(room);
  };

  // 滚动到最新消息
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  // 创建聊天室
  const handleCreateRoom = async () => {
    if (!newRoomName) {
      message.warning('Please enter room name');
      return;
    }

    try {
      const response = await authenticatedFetch('/api/group/rooms', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ name: newRoomName })
      });
      const data = await response.json();
      setRooms(prev => [...prev, data]);
      setNewRoomName('');
      setShowCreateRoomModal(false);
      message.success('Room created successfully');
    } catch (error) {
      console.error('Error creating room:', error);
      message.error('Failed to create room');
    }
  };

  // 处理邀请
  const handleInvitationAction = async (invitationId: number, action: string) => {
    try {
      const response = await authenticatedFetch(`/api/group/invitations/${invitationId}/action`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ action })
      });
      const data = await response.json();
      // 更新邀请列表
      setInvitations(prev => prev.filter(inv => inv.id !== invitationId));
      // 如果接受邀请，重新加载聊天室列表
      if (action === 'accepted') {
        const response = await authenticatedFetch('/api/group/rooms');
        const roomsData = await response.json();
        setRooms(Array.isArray(roomsData) ? roomsData : []);
        message.success('Invitation accepted');
      }
    } catch (error) {
      console.error('Error handling invitation:', error);
      message.error('Failed to handle invitation');
    }
  };

  // 发送消息
  const handleSendMessage = async () => {
    if (!newMessage || !selectedRoom) return;
    await authenticatedFetch('/api/message/send', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ room_id: selectedRoom.id, content: newMessage })
    });
    setNewMessage('');
  };

  // 发送邀请
  const handleSendInvitation = async () => {
    if (!inviteeUsername || !selectedRoom) {
      message.warning('Please enter username');
      return;
    }

    try {
      // 首先根据username获取userId
      const userResponse = await authenticatedFetch(`/api/user/${inviteeUsername}`);
      if (!userResponse.ok) {
        throw new Error('User not found');
      }
      const inviteeUser = await userResponse.json();

      // 然后发送邀请
      const inviteResponse = await authenticatedFetch('/api/group/invitations', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          room_id: selectedRoom.id,
          invitee_id: inviteeUser.id
        })
      });
      const data = await inviteResponse.json();
      setInviteeUsername('');
      message.success('Invitation sent successfully!');
    } catch (error) {
      message.error('Failed to send invitation. User not found.');
      console.error(error);
    }
  };

  return (
    <Layout style={{ minHeight: '100vh' }}>
      <Sider width={300} theme="light" style={{ borderRight: '1px solid #f0f0f0', display: 'flex', flexDirection: 'column' }}>
        <div style={{ padding: '20px', borderBottom: '1px solid #f0f0f0' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
            <h2 style={{ margin: 0, color: '#1890ff', fontSize: '20px' }}>Chat App</h2>
            <Badge count={invitations.filter(inv => inv.status === 'pending').length} offset={[-4, 4]}>
              <Button 
                icon={<BellOutlined />} 
                type="text" 
                onClick={() => setShowInvitations(!showInvitations)}
              />
            </Badge>
          </div>
          
          <Button 
            type="primary" 
            icon={<PlusOutlined />} 
            block 
            onClick={() => setShowCreateRoomModal(true)}
          >
            New Room
          </Button>
        </div>

        {showInvitations && (
          <div style={{ padding: '16px', borderBottom: '1px solid #f0f0f0', backgroundColor: '#fafafa' }}>
            <h3 style={{ margin: '0 0 12px 0', fontSize: '16px', color: '#333' }}>Pending Invitations</h3>
            {invitations.filter(inv => inv.status === 'pending').length > 0 ? (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                {invitations.filter(inv => inv.status === 'pending').map(invitation => (
                  <Card key={invitation.id} size="small" style={{ margin: 0 }}>
                    <div style={{ marginBottom: '8px' }}>
                      <div><strong>Room:</strong> {invitation.room_name}</div>
                      <div><strong>Invited by:</strong> {invitation.inviter_name}</div>
                    </div>
                    <div style={{ display: 'flex', gap: '8px' }}>
                      <Button 
                        type="primary" 
                        size="small" 
                        onClick={() => handleInvitationAction(invitation.id, 'accepted')}
                      >
                        Accept
                      </Button>
                      <Button 
                        size="small" 
                        danger 
                        onClick={() => handleInvitationAction(invitation.id, 'rejected')}
                      >
                        Reject
                      </Button>
                    </div>
                  </Card>
                ))}
              </div>
            ) : (
              <p style={{ color: '#999', fontStyle: 'italic', fontSize: '16px', margin: 0 }}>No pending invitations</p>
            )}
          </div>
        )}

        <Menu
          mode="inline"
          selectedKeys={selectedRoom ? [selectedRoom.id.toString()] : []}
          style={{ flex: 1, borderRight: 0 }}
          onSelect={({ key }) => {
            const room = rooms.find(r => r.id.toString() === key);
            if (room) {
              handleRoomSelect(room);
            }
          }}
          items={rooms.map(room => ({
            key: room.id.toString(),
            icon: (
              <Avatar size={32} style={{ marginRight: '12px' }}>
                {room.name.charAt(0).toUpperCase()}
              </Avatar>
            ),
            label: (
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-start' }}>
                <div style={{ fontWeight: '500', fontSize: '16px' }}>{room.name}</div>
                {room.lastMessage && (
                  <div style={{ fontSize: '14px', color: '#999', marginTop: '2px' }}>
                    {room.lastMessage.length > 20 ? room.lastMessage.substring(0, 20) + '...' : room.lastMessage}
                  </div>
                )}
              </div>
            )
          }))}
        />
      </Sider>

      <Layout style={{ flex: 1 }}>
        <Header style={{ padding: '0 24px', display: 'flex', alignItems: 'center', backgroundColor: 'white', borderBottom: '1px solid #f0f0f0' }}>
          {selectedRoom ? (
            <div style={{ display: 'flex', alignItems: 'center', gap: '16px', flex: 1, minWidth: 0 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '12px', flex: 1 }}>
                <h1 style={{ margin: 0, fontSize: '18px', fontWeight: '500', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{selectedRoom.name}</h1>
          <div style={{ fontSize: '14px', color: '#999', whiteSpace: 'nowrap' }}>
            {selectedRoom.members && selectedRoom.members.length > 0 ? `${selectedRoom.members.length} members` : '0 members'}
          </div>
              </div>
              <Avatar size={32} style={{ backgroundColor: '#1890ff' }}>
                {selectedRoom.name.charAt(0).toUpperCase()}
              </Avatar>
            </div>
          ) : (
            <h1 style={{ margin: 0, fontSize: '16px', fontWeight: '500' }}>Select a room to start chatting</h1>
          )}
          
          <div style={{ display: 'flex', gap: '12px', marginLeft: '24px' }}>
            <Button type="text" icon={<TeamOutlined />} onClick={() => navigate('/contacts')}>Contacts</Button>
            <Button type="text" icon={<SettingOutlined />} onClick={() => navigate('/profile')}>Settings</Button>
            <Button type="text" danger onClick={onLogout}>Logout</Button>
          </div>
        </Header>

        <Content style={{ padding: '24px', backgroundColor: '#f0f2f5', overflowY: 'auto', height: 'calc(100vh - 64px)' }}>
          {selectedRoom ? (
            <div style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
              {/* 成员和邀请区域 */}
              <div style={{ padding: '16px', backgroundColor: 'white', borderRadius: '8px 8px 0 0', borderBottom: '1px solid #f0f0f0', zIndex: 1 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '16px', flexWrap: 'wrap' }}>
                  <div style={{ display: 'flex', gap: '8px', alignItems: 'center', height: '32px' }}>
                    <Input
                      placeholder="Username to invite"
                      value={inviteeUsername}
                      onChange={(e) => setInviteeUsername(e.target.value)}
                      style={{ flex: 1, minWidth: '200px', height: '32px', boxSizing: 'border-box' }}
                      size="small"
                    />
                    <Button size="small" type="primary" onClick={handleSendInvitation} style={{ width: '80px', height: '32px', boxSizing: 'border-box', margin: 0, verticalAlign: 'middle', fontSize: '16px' }}>
                      Invite
                    </Button>
                  </div>
                </div>
                
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: '8px' }}>
                  {selectedRoom.members && selectedRoom.members.map(member => (
                    <div key={member.id} style={{ display: 'flex', alignItems: 'center', gap: '6px', padding: '6px 12px', backgroundColor: '#f5f5f5', borderRadius: '16px' }}>
                      <Avatar size={24} src={member.avatar || undefined} icon={<UserOutlined />} />
                      <span style={{ fontSize: '16px' }}>{member.displayname || member.username}</span>
                    </div>
                  ))}
                </div>
              </div>

              {/* 消息列表 */}
              <div style={{ flex: 1, padding: '24px', overflowY: 'auto', backgroundColor: '#fafafa' }}>
                {messages.length > 0 ? (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                    {messages.map(message => (
                      <div
                        key={message.id}
                        style={{
                          maxWidth: '70%',
                          alignSelf: message.sender_id === user.id ? 'flex-end' : 'flex-start',
                          padding: '12px 16px',
                          borderRadius: '18px',
                          backgroundColor: message.sender_id === user.id ? '#1890ff' : 'white',
                          color: message.sender_id === user.id ? 'white' : '#333',
                          boxShadow: '0 1px 2px rgba(0,0,0,0.1)'
                        }}
                      >
                        <div style={{ display: 'flex', gap: '8px', marginBottom: '8px', alignItems: 'center' }}>
                          <Avatar size={24} src={message.sender?.avatar || undefined} icon={<UserOutlined />} />
                          <div style={{ fontSize: '14px', fontWeight: '500' }}>
                            {message.sender?.displayname || message.sender?.username || `User ${message.sender_id}`}
                          </div>
                        </div>
                        <div style={{ fontSize: '16px', lineHeight: '1.4', wordBreak: 'break-word' }}>
                          {message.content}
                        </div>
                        <div style={{ fontSize: '13px', color: message.sender_id === user.id ? 'rgba(255,255,255,0.7)' : '#999', marginTop: '6px', textAlign: 'right' }}>
                          {new Date(message.created_at).toLocaleTimeString()}
                        </div>
                      </div>
                    ))}
                    <div ref={messagesEndRef} />
                  </div>
                ) : (
                  <div style={{ textAlign: 'center', padding: '60px 20px', color: '#999' }}>
                    <p style={{ fontSize: '16px' }}>No messages yet. Start the conversation!</p>
                  </div>
                )}
              </div>

              {/* 消息输入区域 */}
              <div style={{ padding: '16px', backgroundColor: 'white', borderRadius: '0 0 8px 8px', borderTop: '1px solid #f0f0f0' }}>
                <div style={{ display: 'flex', gap: '12px', alignItems: 'center' }}>
                  <Input.TextArea
                    placeholder="Type a message..."
                    value={newMessage}
                    onChange={(e) => setNewMessage(e.target.value)}
                    onKeyPress={(e) => {
                      if (e.key === 'Enter' && !e.shiftKey) {
                        e.preventDefault();
                        handleSendMessage();
                      }
                    }}
                    autoSize={{ minRows: 1, maxRows: 4 }}
                    style={{ flex: 1, borderRadius: '20px' }}
                    disabled={false}
                  />
                  <Button 
                    type="primary" 
                    shape="circle" 
                    size="middle" 
                    onClick={handleSendMessage}
                    disabled={!newMessage.trim()}
                    style={{ width: '40px', height: '40px' }}
                  >
                    <MessageOutlined />
                  </Button>
                </div>
              </div>
            </div>
          ) : (
            <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: 'calc(100vh - 136px)', backgroundColor: 'white', borderRadius: '8px' }}>
              <div style={{ textAlign: 'center' }}>
                <MessageOutlined style={{ fontSize: '48px', color: '#d9d9d9', marginBottom: '16px' }} />
                <h2 style={{ color: '#666', marginBottom: '8px' }}>No room selected</h2>
                <p style={{ color: '#999' }}>Please select a room from the left sidebar to start chatting</p>
              </div>
            </div>
          )}
        </Content>
      </Layout>

      {/* 创建房间模态框 */}
      <Modal
        title="Create New Room"
        open={showCreateRoomModal}
        onOk={handleCreateRoom}
        onCancel={() => setShowCreateRoomModal(false)}
        okText="Create"
        cancelText="Cancel"
      >
        <Input
          placeholder="Room name"
          value={newRoomName}
          onChange={(e) => setNewRoomName(e.target.value)}
          style={{ marginBottom: '16px' }}
        />
      </Modal>
    </Layout>
  );
};

export default MainLayout;