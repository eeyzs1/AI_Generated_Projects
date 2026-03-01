import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { BrowserRouter } from 'react-router-dom';
import Login from '../Login';

// Mock api
vi.mock('../api', () => ({
  authAPI: {
    login: vi.fn(),
  },
}));

describe('Login Component Tests', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    // Clear localStorage
    localStorage.clear();
  });

  const renderLogin = () => {
    return render(
      <BrowserRouter>
        <Login />
      </BrowserRouter>
    );
  };

  describe('Rendering', () => {
    it('should render login form with all fields', () => {
      renderLogin();

      expect(screen.getByText('登录')).toBeInTheDocument();
      expect(screen.getByLabelText('用户名')).toBeInTheDocument();
      expect(screen.getByLabelText('密码')).toBeInTheDocument();
      expect(screen.getByRole('button', { name: '登录' })).toBeInTheDocument();
      expect(screen.getByText('没有账号？')).toBeInTheDocument();
      expect(screen.getByText('注册')).toBeInTheDocument();
    });
  });

  describe('Form Validation', () => {
    it('should show error message on failed login', async () => {
      const { authAPI } = await import('../api');
      (authAPI.login as any).mockRejectedValue({
        response: { data: { detail: 'Invalid credentials' } }
      });

      renderLogin();

      const usernameInput = screen.getByLabelText('用户名');
      const passwordInput = screen.getByLabelText('密码');
      const submitButton = screen.getByRole('button', { name: '登录' });

      fireEvent.change(usernameInput, { target: { value: 'testuser' } });
      fireEvent.change(passwordInput, { target: { value: 'wrongpass' } });
      fireEvent.click(submitButton);

      await waitFor(() => {
        expect(screen.getByText(/Invalid credentials/)).toBeInTheDocument();
      });
    });
  });

  describe('User Interaction', () => {
    it('should update input values when user types', () => {
      renderLogin();

      const usernameInput = screen.getByLabelText('用户名') as HTMLInputElement;
      const passwordInput = screen.getByLabelText('密码') as HTMLInputElement;

      fireEvent.change(usernameInput, { target: { value: 'testuser' } });
      fireEvent.change(passwordInput, { target: { value: 'password123' } });

      expect(usernameInput.value).toBe('testuser');
      expect(passwordInput.value).toBe('password123');
    });
  });
});
