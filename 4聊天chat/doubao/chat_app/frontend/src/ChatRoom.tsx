import React, { useState, useEffect, useRef } from 'react';
import UserList from './UserList';

interface User {
  id: number;
  username: string;
  email: string;
}

interface Room {
  id: number;
  name: string;
  creator_id: number;
  members: User[];
}

interface Message {
  id: number;
  sender_id: number;
  room_id: number;
  content: string;
  created_at: string;
  sender: User;
}

interface ChatRoomProps {
  token: string;
  user: User;
}

const ChatRoom: React.FC<ChatRoomProps> = ({ token, user }) => {
  const [rooms, setRooms] = useState<Room[]>([]);
  const [currentRoom, setCurrentRoom] = useState<Room | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [newMessage, setNewMessage] = useState('');
  const [onlineUserIds, setOnlineUserIds] = useState<number[]>([]);
  const [roomName, setRoomName] = useState('');
  const wsRef = useRef<WebSocket | null>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  // 获取用户房间列表
  useEffect(() => {
    const fetchRooms = async () => {
      try {
        const res = await fetch('/api/rooms', {
          headers: {
            'Authorization': `Bearer ${token}`
          }
        });
        const data = await res.json();
        if (res.ok) {
          setRooms(data);
          // 默认选中第一个房间
          if (data.length > 0) {
            setCurrentRoom(data[0]);
          }
        }
      } catch (err) {
        console.error('获取房间失败:', err);
      }
    };

    fetchRooms();
  }, [token]);

  // 连接WebSocket
  useEffect(() => {
    // 创建WebSocket连接
    const ws = new WebSocket(`ws://${window.location.host}/api/ws?token=${token}`);
    wsRef.current = ws;

    // 连接成功
    ws.onopen = () => {
      console.log('WebSocket连接成功');
      // 如果有当前房间，加入房间
      if (currentRoom) {
        ws.send(JSON.stringify({
          type: 'join_room',
          room_id: currentRoom.id
        }));
        fetchRoomMessages(currentRoom.id);
      }
    };

    // 接收消息
    ws.onmessage = (event) => {
      const data = JSON.parse(event.data);
      switch (data.type) {
        case 'online_users':
          setOnlineUserIds(data.data);
          break;
        case 'new_message':
          const msg = data.data;
          setMessages(prev => [
            ...prev,
            {
              ...msg,
              id: Date.now(),
              sender: { id: msg.sender_id, username: `用户${msg.sender_id}`, email: '' }
            }
          ]);
          break;
      }
    };

    // 连接关闭
    ws.onclose = () => {
      console.log('WebSocket连接关闭，5秒后重连');
      setTimeout(() => {
        wsRef.current = null;
        // 重新触发effect
        setOnlineUserIds(prev => [...prev]);
      }, 5000);
    };

    // 清理函数
    return () => {
      if (wsRef.current) {
        wsRef.current.close();
      }
    };
  }, [token, currentRoom?.id]);

  // 滚动到消息底部
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  // 获取房间消息
  const fetchRoomMessages = async (roomId: number) => {
    try {
      const res = await fetch(`/api/rooms/${roomId}/messages`, {
        headers: {
          'Authorization': `Bearer ${token}`
        }
      });
      const data = await res.json();
      if (res.ok) {
        setMessages(data);
      }
    } catch (err) {
      console.error('获取消息失败:', err);
    }
  };

  // 切换房间
  const handleRoomChange = (room: Room) => {
    // 离开当前房间
    if (currentRoom && wsRef.current) {
      wsRef.current.send(JSON.stringify({
        type: 'leave_room',
        room_id: currentRoom.id
      }));
    }
    // 加入新房间
    setCurrentRoom(room);
    if (wsRef.current) {
      wsRef.current.send(JSON.stringify({
        type: 'join_room',
        room_id: room.id
      }));
    }
    // 获取新房间消息
    fetchRoomMessages(room.id);
  };

  // 发送消息
  const handleSendMessage = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newMessage.trim() || !currentRoom || !wsRef.current) return;

    // 发送消息到WebSocket
    const messageData = {
      type: 'send_message',
      room_id: currentRoom.id,
      content: newMessage,
      created_at: new Date().toISOString()
    };
    wsRef.current.send(JSON.stringify(messageData));

    // 同时调用API保存消息
    try {
      await fetch('/api/messages', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({
          room_id: currentRoom.id,
          content: newMessage
        })
      });
    } catch (err) {
      console.error('保存消息失败:', err);
    }

    // 清空输入框
    setNewMessage('');
  };

  // 创建新房间
  const handleCreateRoom = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!roomName.trim()) return;

    try {
      const res = await fetch('/api/rooms', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({ name: roomName })
      });
      const data = await res.json();
      if (res.ok) {
        setRooms(prev => [...prev, data]);
        setRoomName('');
      }
    } catch (err) {
      console.error('创建房间失败:', err);
    }
  };

  // 构建用户信息映射
  const userMap: { [key: number]: User } = {};
  rooms.forEach(room => {
    room.members.forEach(member => {
      userMap[member.id] = member;
    });
  });
  userMap[user.id] = user;

  return (
    <div>
      {/* 创建房间表单 */}
      <div className="card">
        <h3>创建新聊天室</h3>
        <form onSubmit={handleCreateRoom}>
          <input
            type="text"
            placeholder="房间名称"
            value={roomName}
            onChange={(e) => setRoomName(e.target.value)}
            required
          />
          <button type="submit">创建房间</button>
        </form>
      </div>

      {/* 房间列表和聊天区域 */}
      <div className="chat-container">
        {/* 房间列表 */}
        <div className="user-list">
          <h3>我的聊天室</h3>
          <hr />
          {rooms.length === 0 ? (
            <p>暂无聊天室，创建一个吧！</p>
          ) : (
            rooms.map(room => (
              <div
                key={room.id}
                className="room-item"
                style={{ background: currentRoom?.id === room.id ? '#007bff' : '', color: currentRoom?.id === room.id ? 'white' : '' }}
                onClick={() => handleRoomChange(room)}
              >
                {room.name}
              </div>
            ))
          )}
        </div>

        {/* 在线用户列表 */}
        <UserList
          onlineUserIds={onlineUserIds}
          currentUserId={user.id}
          users={userMap}
        />

        {/* 聊天区域 */}
        {currentRoom ? (
          <div className="chat-room">
            <h3>{currentRoom.name}</h3>
            <div className="messages">
              {messages.map(msg => (
                <div
                  key={msg.id}
                  className={`message ${msg.sender_id === user.id ? 'sent' : 'received'}`}
                >
                  <div style={{ fontSize: '12px', marginBottom: '4px' }}>
                    {msg.sender?.username || `用户${msg.sender_id}`}
                  </div>
                  <div>{msg.content}</div>
                  <div style={{ fontSize: '10px', textAlign: 'right', marginTop: '4px' }}>
                    {new Date(msg.created_at).toLocaleString()}
                  </div>
                </div>
              ))}
              <div ref={messagesEndRef} />
            </div>
            <form onSubmit={handleSendMessage} className="message-input">
              <input
                type="text"
                placeholder="输入消息..."
                value={newMessage}
                onChange={(e) => setNewMessage(e.target.value)}
                required
              />
              <button type="submit">发送</button>
            </form>
          </div>
        ) : (
          <div className="chat-room" style={{ justifyContent: 'center', alignItems: 'center' }}>
            <p>请选择一个聊天室开始聊天</p>
          </div>
        )}
      </div>
    </div>
  );
};

export default ChatRoom;
