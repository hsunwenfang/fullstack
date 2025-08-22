import React, { useEffect, useMemo, useState } from 'react'
import axios from 'axios'

const API_BASE = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000'

export const App: React.FC = () => {
  const [users, setUsers] = useState<Array<{ id?: number; name: string; email: string }>>([])
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [message, setMessage] = useState('')
  const [reply, setReply] = useState('')
  const [selectedUserId, setSelectedUserId] = useState<number | ''>('')

  const client = useMemo(() => axios.create({ baseURL: `${API_BASE}/api` }), [])

  useEffect(() => {
    client.get('/users').then(r => setUsers(r.data)).catch(() => setUsers([]))
  }, [])

  const addUser = async () => {
    if (!name || !email) return
    const res = await client.post('/users', { name, email })
    setUsers(prev => [...prev, res.data])
    setName('')
    setEmail('')
  }

  const sendMessage = async () => {
    if (!selectedUserId || !message) return
    const params = new URLSearchParams({ user_id: String(selectedUserId), message })
    const res = await client.post(`/chat?${params.toString()}`)
    setReply(res.data.reply)
  }

  return (
    <div style={{ maxWidth: 720, margin: '2rem auto', fontFamily: 'sans-serif' }}>
      <h1>Fullstack AI App</h1>

      <section style={{ marginBottom: '2rem' }}>
        <h2>Create User</h2>
        <div style={{ display: 'flex', gap: 8 }}>
          <input placeholder="Name" value={name} onChange={e => setName(e.target.value)} />
          <input placeholder="Email" value={email} onChange={e => setEmail(e.target.value)} />
          <button onClick={addUser}>Add</button>
        </div>
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2>Users</h2>
        <select value={selectedUserId} onChange={e => setSelectedUserId(e.target.value ? Number(e.target.value) : '')}>
          <option value="">Select user</option>
          {users.map(u => (
            <option key={u.id ?? u.email} value={u.id}>{u.name} ({u.email})</option>
          ))}
        </select>
      </section>

      <section>
        <h2>Chat with AI</h2>
        <textarea rows={4} placeholder="Ask something..." value={message} onChange={e => setMessage(e.target.value)} />
        <div>
          <button onClick={sendMessage}>Send</button>
        </div>
        {reply && (
          <div style={{ marginTop: 12, padding: 12, border: '1px solid #ddd' }}>
            <strong>Assistant:</strong>
            <div>{reply}</div>
          </div>
        )}
      </section>
    </div>
  )
}
