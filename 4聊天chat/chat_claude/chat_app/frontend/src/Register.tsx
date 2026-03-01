import { useState } from 'react'

interface Props {
  onRegistered: () => void
  onGoLogin: () => void
}

export default function Register({ onRegistered, onGoLogin }: Props) {
  const [username, setUsername] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    try {
      const res = await fetch('/auth/register', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, email, password }),
      })
      if (!res.ok) {
        const d = await res.json()
        setError(d.detail || '注册失败')
        return
      }
      setSuccess('注册成功，请登录')
      setTimeout(onRegistered, 1200)
    } catch {
      setError('网络错误')
    }
  }

  return (
    <div style={cardStyle}>
      <h2 style={{ textAlign: 'center', marginBottom: 24 }}>注册</h2>
      <form onSubmit={handleSubmit}>
        <input style={inputStyle} placeholder="用户名" value={username} onChange={e => setUsername(e.target.value)} required />
        <input style={inputStyle} type="email" placeholder="邮箱" value={email} onChange={e => setEmail(e.target.value)} required />
        <input style={inputStyle} type="password" placeholder="密码" value={password} onChange={e => setPassword(e.target.value)} required />
        {error && <p style={{ color: 'red', fontSize: 13 }}>{error}</p>}
        {success && <p style={{ color: '#07c160', fontSize: 13 }}>{success}</p>}
        <button style={btnStyle} type="submit">注册</button>
      </form>
      <p style={{ textAlign: 'center', marginTop: 12, fontSize: 13 }}>
        已有账号？<span style={{ color: '#07c160', cursor: 'pointer' }} onClick={onGoLogin}>登录</span>
      </p>
    </div>
  )
}

const cardStyle: React.CSSProperties = { background: '#fff', padding: 32, borderRadius: 8, width: 320, boxShadow: '0 2px 12px rgba(0,0,0,0.1)' }
const inputStyle: React.CSSProperties = { width: '100%', padding: '10px 12px', marginBottom: 12, border: '1px solid #ddd', borderRadius: 4, fontSize: 14, boxSizing: 'border-box' }
const btnStyle: React.CSSProperties = { width: '100%', padding: '10px 0', background: '#07c160', color: '#fff', border: 'none', borderRadius: 4, fontSize: 15, cursor: 'pointer' }
