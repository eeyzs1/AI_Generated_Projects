export interface UserSummary {
  id: number;
  username: string;
  email?: string;
}

export interface Room {
  id: number;
  name: string;
  creator_id?: number;
  members: UserSummary[];
  created_at?: string;
}

export interface Message {
  id: number;
  content: string;
  room_id: number;
  created_at?: string;
  sender: UserSummary;
}

export interface AuthResponse {
  access_token: string;
  token_type: string;
}
