import { useState, useEffect, useRef } from 'react'
import type { CurrentUser } from './App'
import UserList from './UserList'

interface Room { id: number; name: string; creator_id: number }
interface Message { id: number; content: string; sender: { id: number; username: string }; room_id: number; created_at: string }
interface OnlineUser { id: number; username: string }

interface Props {
  token: string
  currentUser: CurrentUser
  onLogout: () => void
}

export default function ChatRoom({ token, currentUser, onLogout }: Props) {
  const [rooms, setRooms] = useState<Room[]>([])
  const [activeRoom, setActiveRoom] = useState<Room | null>(null)
  const [messages, setMessages] = useState<Message[]>([])
  const [onlineUsers, setOnlineUsers] = useState<OnlineUser[]>([])
  const [input, setInput] = useState('')
  const [newRoomName, setNewRoomName] = useState('')
  const [error, setError] = useState('')
  const wsRef = useRef<WebSocket | null>(null)
  const bottomRef = useRef<HTMLDivElement>(null)

  const headers = { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' }

  useEffect(() => {
    fetch('/rooms', { headers }).then(r => r.json()).then(setRooms)
  }, [])

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages])

  const connectRoom = (room: Room) => {
    wsRef.current?.close()
    setMessages([])
    setActiveRoom(room)
    const wsUrl = `${location.protocol === 'https:' ? 'wss' : 'ws'}://${location.host}/ws/rooms/${room.id}?token=${token}`
    const ws = new WebSocket(wsUrl)
    wsRef.current = ws

    ws.onmessage = (e) => {
      const data = JSON.parse(e.data)
      if (data.type === 'history') setMessages(data.messages)
      else if (data.type === 'message') setMessages(prev => [...prev, data])
      else if (data.type === 'users') setOnlineUsers(data.users)
    }
    ws.onerror = () => setError('WebSocket 连接错误')
  }

  const sendMessage = () => {
    if (!input.trim() || !wsRef.current) return
    wsRef.current.send(JSON.stringify({ content: input.trim() }))
    setInput('')
  }

  const createRoom = async () => {
    if (!newRoomName.trim()) return
    const res = await fetch('/rooms', { method: 'POST', headers, body: JSON.stringify({ name: newRoomName.trim() }) })
    if (res.ok) {
      const room = await res.json()
      setRooms(prev => [room, ...prev])
      setNewRoomName('')
      connectRoom(room)
    } else {
      const d = await res.json()
      setError(d.detail || '创建失败')
    }
  }

  const joinRoom = async (room: Room) => {
    await fetch(`/rooms/${room.id}/join`, { method: 'POST', headers })
    connectRoom(room)
  }

  return (
    <div style={{ display: 'flex', height: '100vh', fontFamily: 'sans-serif' }}>
      {/* Sidebar */}
      <div style={{ width: 220, background: '#2c2c2c', color: '#fff', display: 'flex', flexDirection: 'column' }}>
        <div style={{ padding: '16px', borderBottom: '1px solid #444', fontSize: 14 }}>
          <strong>{currentUser.username}</strong>
          <button onClick={onLogout} style={{ float: 'right', background: 'none', border: 'none', color: '#aaa', cursor: 'pointer', fontSize: 12 }}>退出</button>
        </div>
        <div style={{ padding: 12, borderBottom: '1px solid #444' }}>
          <input value={newRoomName} onChange={e => setNewRoomName(e.target.value)} placeholder="新建聊天室" style={{ width: '100%', padding: '6px 8px', borderRadius: 4, border: 'none', fontSize: 13, boxSizing: 'border-box' }} onKeyDown={e => e.key === 'Enter' && createRoom()} />
          <button onClick={createRoom} style={{ marginTop: 6, width: '100%', padding: '6px 0', background: '#07c160', color: '#fff', border: 'none', borderRadius: 4, cursor: 'pointer', fontSize: 13 }}>创建</button>
        </div>
        <div style={{ flex: 1, overflowY: 'auto' }}>
          <div style={{ fontSize: 11, color: '#888', padding: '8px 12px 4px' }}>聊天室</div>
          {rooms.map(r => (
            <div key={r.id} onClick={() => joinRoom(r)} style={{ padding: '10px 14px', cursor: 'pointer', background: activeRoom?.id === r.id ? '#444' : 'transparent', fontSize: 14, borderLeft: activeRoom?.id === r.id ? '3px solid #07c160' : '3px solid transparent' }}>
              # {r.name}
            </div>
          ))}
        </div>
        <UserList users={onlineUsers} />
      </div>

      {/* Chat area */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', background: '#f5f5f5' }}>
        {activeRoom ? (
          <>
            <div style={{ padding: '14px 20px', background: '#fff', borderBottom: '1px solid #eee', fontWeight: 600 }}>
              # {activeRoom.name}
            </div>
            <div style={{ flex: 1, overflowY: 'auto', padding: '16px 20px' }}>
              {messages.map(m => (
                <div key={m.id} style={{ marginBottom: 12 }}>
                  <span style={{ fontWeight: 600, fontSize: 13, color: m.sender.id === currentUser.id ? '#07c160' : '#333' }}>{m.sender.username}</span>
                  <span style={{ fontSize: 11, color: '#aaa', marginLeft: 8 }}>{new Date(m.created_at).toLocaleTimeString()}</span>
                  <div style={{ marginTop: 4, background: '#fff', padding: '8px 12px', borderRadius: 6, display: 'inline-block', maxWidth: '70%', fontSize: 14, boxShadow: '0 1px 3px rgba(0,0,0,0.06)' }}>{m.content}</div>
                </div>
              ))}
              <div ref={bottomRef} />
            </div>
            <div style={{ padding: '12px 20px', background: '#fff', borderTop: '1px solid #eee', display: 'flex', gap: 8 }}>
              <input value={input} onChange={e => setInput(e.target.value)} onKeyDown={e => e.key === 'Enter' && sendMessage()} placeholder="输入消息..." style={{ flex: 1, padding: '10px 14px', border: '1px solid #ddd', borderRadius: 4, fontSize: 14 }} />
              <button onClick={sendMessage} style={{ padding: '10px 20px', background: '#07c160', color: '#fff', border: 'none', borderRadius: 4, cursor: 'pointer', fontSize: 14 }}>发送</button>
            </div>
          </>
        ) : (
          <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#aaa', fontSize: 16 }}>
            选择或创建一个聊天室开始聊天
          </div>
        )}
        {error && <div style={{ padding: '8px 20px', background: '#fff3f3', color: 'red', fontSize: 13 }}>{error}</div>}
      </div>
    </div>
  )
}
