import { describe, it, expect, beforeEach, vi } from 'vitest';
import axios from 'axios';
import { authAPI } from '../api';

// Mock axios
vi.mock('axios');

describe('Auth API Tests', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('register', () => {
    it('should register a new user successfully', async () => {
      const userData = {
        username: 'testuser',
        email: 'test@example.com',
        password: 'password123'
      };

      const mockResponse = {
        data: {
          id: 1,
          username: 'testuser',
          email: 'test@example.com',
          created_at: '2024-01-01T00:00:00',
          is_online: 0
        }
      };

      (axios.post as any).mockResolvedValue(mockResponse);

      const result = await authAPI.register(
        userData.username,
        userData.email,
        userData.password
      );

      expect(axios.post).toHaveBeenCalledWith('/auth/register', userData);
      expect(result.data).toEqual(mockResponse.data);
    });

    it('should handle registration error', async () => {
      const userData = {
        username: 'testuser',
        email: 'test@example.com',
        password: 'password123'
      };

      const mockError = new Error('Username already exists');
      (axios.post as any).mockRejectedValue(mockError);

      await expect(
        authAPI.register(userData.username, userData.email, userData.password)
      ).rejects.toThrow('Username already exists');
    });
  });

  describe('login', () => {
    it('should login successfully with valid credentials', async () => {
      const loginData = {
        username: 'testuser',
        password: 'password123'
      };

      const mockResponse = {
        data: {
          access_token: 'test-token',
          token_type: 'bearer'
        }
      };

      (axios.post as any).mockResolvedValue(mockResponse);

      const result = await authAPI.login(loginData.username, loginData.password);

      expect(axios.post).toHaveBeenCalledWith('/auth/login', loginData);
      expect(result.data).toEqual(mockResponse.data);
      expect(result.data.access_token).toBe('test-token');
    });

    it('should handle login error with invalid credentials', async () => {
      const loginData = {
        username: 'testuser',
        password: 'wrongpassword'
      };

      const mockError = new Error('Invalid credentials');
      (axios.post as any).mockRejectedValue(mockError);

      await expect(
        authAPI.login(loginData.username, loginData.password)
      ).rejects.toThrow('Invalid credentials');
    });
  });

  describe('getMe', () => {
    it('should get current user information', async () => {
      const mockResponse = {
        data: {
          id: 1,
          username: 'testuser',
          email: 'test@example.com',
          created_at: '2024-01-01T00:00:00',
          is_online: 1
        }
      };

      (axios.get as any).mockResolvedValue(mockResponse);

      const result = await authAPI.getMe();

      expect(axios.get).toHaveBeenCalledWith('/auth/me');
      expect(result.data).toEqual(mockResponse.data);
    });
  });
});
