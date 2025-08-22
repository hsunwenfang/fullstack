import React, { useEffect, useState } from 'react'
import { createUser, getUsers, sendChat, type User } from '../api'

export const App: React.FC = () => {
  const [users, setUsers] = useState<User[]>([])
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [message, setMessage] = useState('')
  const [reply, setReply] = useState('')
  const [selectedUserId, setSelectedUserId] = useState<string>('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)


  useEffect(() => {
    // In React 18 StrictMode (dev), effects run twice on mount.
    // Cancel the first in-flight request to avoid duplicate work.
    const ac = new AbortController()
      ; (async () => {
        try {
          setLoading(true)
          setError(null)
          let list = await getUsers({ signal: ac.signal })
          if (list.length === 0) {
            // Seed three default users if none exist
            const defaults = [
              { name: 'A', email: 'a@example.com' },
              { name: 'B', email: 'b@example.com' },
              { name: 'C', email: 'c@example.com' },
            ]
            const created: User[] = []
            for (const u of defaults) {
              created.push(await createUser(u, { signal: ac.signal }))
            }
            list = created
          }
          setUsers(list)
          // Preselect the first user if none selected yet
          if (list[0]?.id) {
            setSelectedUserId((prev) => (prev === '' ? String(list[0].id) : prev))
          }
          setLoading(false)
        } catch (err: any) {
          // Ignore cancellations; surface other errors minimally
          if (err && (err.code === 'ERR_CANCELED' || err.name === 'CanceledError' || err.message === 'canceled')) return
          setUsers([])
          setError('Failed to load users')
          // eslint-disable-next-line no-console
          console.error('Failed to load users', err)
          setLoading(false)
        }
      })()
    return () => ac.abort()
  }, [])

  const addUser = async () => {
    if (!name || !email) return
    const created = await createUser({ name, email })
    setUsers(prev => [...prev, created])
    setName('')
    setEmail('')
  }

  const sendMessage = async () => {
    if (!selectedUserId || !message) return
    const res = await sendChat(Number(selectedUserId), message)
    setReply(res.reply)
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
        <select value={selectedUserId} onChange={e => setSelectedUserId(e.target.value)}>
          <option value="">Select user</option>
          {users.map(u => (
            <option key={u.id ?? u.email} value={u.id ? String(u.id) : ''}>{u.name} ({u.email})</option>
          ))}
        </select>
        {loading && <div>Loading users…</div>}
        {error && <div style={{ color: 'crimson' }}>{error}</div>}
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
