import { useState } from 'react'
import Login from './Login'
import Register from './Register'
import ChatRoom from './ChatRoom'

export interface CurrentUser {
  id: number
  username: string
  email: string
}

export default function App() {
  const [token, setToken] = useState<string>(localStorage.getItem('token') || '')
  const [currentUser, setCurrentUser] = useState<CurrentUser | null>(null)
  const [page, setPage] = useState<'login' | 'register'>('login')

  const handleLogin = (t: string, user: CurrentUser) => {
    localStorage.setItem('token', t)
    setToken(t)
    setCurrentUser(user)
  }

  const handleLogout = () => {
    localStorage.removeItem('token')
    setToken('')
    setCurrentUser(null)
  }

  if (token && currentUser) {
    return <ChatRoom token={token} currentUser={currentUser} onLogout={handleLogout} />
  }

  if (token && !currentUser) {
    // Try to fetch current user
    fetch('/users/me', { headers: { Authorization: `Bearer ${token}` } })
      .then(r => r.ok ? r.json() : Promise.reject())
      .then(u => setCurrentUser(u))
      .catch(() => { localStorage.removeItem('token'); setToken('') })
  }

  return (
    <div style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', background: '#f0f2f5' }}>
      {page === 'login'
        ? <Login onLogin={handleLogin} onGoRegister={() => setPage('register')} />
        : <Register onRegistered={() => setPage('login')} onGoLogin={() => setPage('login')} />
      }
    </div>
  )
}
