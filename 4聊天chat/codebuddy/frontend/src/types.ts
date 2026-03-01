export interface User {
  id: number;
  username: string;
  email: string;
  created_at: string;
  is_online: number;
}

export interface Room {
  id: number;
  name: string;
  creator_id: number;
  created_at: string;
}

export interface RoomDetail extends Room {
  members: number[];
}

export interface Message {
  id: number;
  room_id: number;
  sender_id: number;
  sender_username?: string;
  content: string;
  created_at: string;
}

export interface WSMessage {
  type: 'message' | 'user_join' | 'user_leave' | 'online_users';
  data: any;
}
