interface User {
  id: number
  username: string
}

interface Props {
  users: User[]
}

export default function UserList({ users }: Props) {
  return (
    <div style={{ padding: '12px 0' }}>
      <div style={{ fontSize: 12, color: '#999', padding: '0 16px 8px' }}>在线用户 ({users.length})</div>
      {users.map(u => (
        <div key={u.id} style={{ padding: '6px 16px', fontSize: 14, display: 'flex', alignItems: 'center', gap: 8 }}>
          <span style={{ width: 8, height: 8, borderRadius: '50%', background: '#07c160', display: 'inline-block' }} />
          {u.username}
        </div>
      ))}
    </div>
  )
}
