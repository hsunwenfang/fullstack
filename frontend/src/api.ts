import axios from 'axios'

export type User = { id?: number; name: string; email: string }

const API_BASE = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000'

export const api = axios.create({ baseURL: `${API_BASE}/api` })

// Log the full request URL to help verify paths in DevTools
api.interceptors.request.use((config) => {
    const fullUrl = `${config.baseURL ?? ''}${config.url ?? ''}`
    // eslint-disable-next-line no-console
    console.debug('[API] →', fullUrl)
    return config
})

export async function getUsers(options?: { signal?: AbortSignal }) {
    const r = await api.get<User[]>('/users', { signal: options?.signal })
    return r.data
}

export async function createUser(user: Pick<User, 'name' | 'email'>, options?: { signal?: AbortSignal }) {
    const r = await api.post<User>('/users', user, { signal: options?.signal })
    return r.data
}

export async function sendChat(user_id: number, message: string, options?: { signal?: AbortSignal }) {
    const params = new URLSearchParams({ user_id: String(user_id), message })
    const r = await api.post<{ reply: string }>(`/chat?${params.toString()}`, undefined, { signal: options?.signal })
    return r.data
}
