import axios from 'axios';
import type { User, Room, RoomDetail, Message } from './types';

const API_BASE_URL = '/api';

// 创建axios实例
const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// 添加token到请求头
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// 响应拦截器
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem('token');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

// 认证相关API
export const authAPI = {
  register: (username: string, email: string, password: string) =>
    api.post<{ id: number; username: string; email: string }>('/auth/register', {
      username,
      email,
      password,
    }),

  login: (username: string, password: string) =>
    api.post<{ access_token: string; token_type: string }>('/auth/login', {
      username,
      password,
    }),

  getMe: () => api.get<User>('/auth/me'),
};

// 用户相关API
export const userAPI = {
  getAll: () => api.get<User[]>('/users'),
};

// 聊天室相关API
export const roomAPI = {
  create: (name: string) =>
    api.post<Room>('/rooms', { name }),

  getAll: () => api.get<Room[]>('/rooms'),

  getDetail: (roomId: number) => api.get<RoomDetail>(`/rooms/${roomId}`),

  addMember: (roomId: number, userId: number) =>
    api.post('/rooms/members', { room_id: roomId, user_id: userId }),
};

// 消息相关API
export const messageAPI = {
  getRoomMessages: (roomId: number) =>
    api.get<Message[]>(`/rooms/${roomId}/messages`),
};

export default api;
