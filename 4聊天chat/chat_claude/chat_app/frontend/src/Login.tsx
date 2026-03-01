import { useState } from 'react'
import type { CurrentUser } from './App'

interface Props {
  onLogin: (token: string, user: CurrentUser) => void
  onGoRegister: () => void
}

export default function Login({ onLogin, onGoRegister }: Props) {
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    try {
      const res = await fetch('/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, password }),
      })
      if (!res.ok) {
        const d = await res.json()
        setError(d.detail || '登录失败')
        return
      }
      const { access_token } = await res.json()
      const meRes = await fetch('/users/me', { headers: { Authorization: `Bearer ${access_token}` } })
      const user = await meRes.json()
      onLogin(access_token, user)
    } catch {
      setError('网络错误')
    }
  }

  return (
    <div style={cardStyle}>
      <h2 style={{ textAlign: 'center', marginBottom: 24 }}>登录</h2>
      <form onSubmit={handleSubmit}>
        <input style={inputStyle} placeholder="用户名" value={username} onChange={e => setUsername(e.target.value)} required />
        <input style={inputStyle} type="password" placeholder="密码" value={password} onChange={e => setPassword(e.target.value)} required />
        {error && <p style={{ color: 'red', fontSize: 13 }}>{error}</p>}
        <button style={btnStyle} type="submit">登录</button>
      </form>
      <p style={{ textAlign: 'center', marginTop: 12, fontSize: 13 }}>
        没有账号？<span style={{ color: '#07c160', cursor: 'pointer' }} onClick={onGoRegister}>注册</span>
      </p>
    </div>
  )
}

const cardStyle: React.CSSProperties = { background: '#fff', padding: 32, borderRadius: 8, width: 320, boxShadow: '0 2px 12px rgba(0,0,0,0.1)' }
const inputStyle: React.CSSProperties = { width: '100%', padding: '10px 12px', marginBottom: 12, border: '1px solid #ddd', borderRadius: 4, fontSize: 14, boxSizing: 'border-box' }
const btnStyle: React.CSSProperties = { width: '100%', padding: '10px 0', background: '#07c160', color: '#fff', border: 'none', borderRadius: 4, fontSize: 15, cursor: 'pointer' }
