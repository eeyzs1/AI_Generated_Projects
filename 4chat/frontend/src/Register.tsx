import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import './AvatarStyles.css';
import AvatarUploader from './AvatarUploader';

const Register: React.FC = () => {
  const navigate = useNavigate();
  const [username, setUsername] = useState('');
  const [displayname, setDisplayname] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [avatar, setAvatar] = useState<string>('');
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    // 检查是否已选择头像
    if (!avatar) {
      setError('Please select an avatar before registering.');
      return;
    }
    
    try {
      const registerData = {
        username,
        displayname,
        email,
        password,
        avatar: avatar,
      };
      
      console.log('Sending registration data:', registerData);
      
      // 注册用户
      const registerResponse = await fetch('/api/user/register', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(registerData),
      });
      
      console.log('Response status:', registerResponse.status);
      
      if (!registerResponse.ok) {
        const errorData = await registerResponse.json();
        console.error('Error data:', errorData);
        throw new Error(errorData.detail || 'Registration failed');
      }
      
      const responseData = await registerResponse.json();
      console.log('Registration successful:', responseData);
      
      setSuccess('Registration submitted! Please check your email to verify your account within 30 minutes.');
      setError('');
      
      setTimeout(() => {
        navigate('/login');
      }, 3000);
    } catch (err) {
      console.error('Registration error:', err);
      // 显示后端传来的具体错误信息
      setError(err instanceof Error ? err.message : 'Registration failed. Please try again.');
      setSuccess('');
    }
  };

  return (
    <div className="register-container">
      <h2>Register</h2>
      <form onSubmit={handleSubmit}>
        <div className="form-group">
          <label htmlFor="username">Username</label>
          <input
            type="text"
            id="username"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            required
          />
        </div>
        <div className="form-group">
          <label htmlFor="displayname">Display Name</label>
          <input
            type="text"
            id="displayname"
            value={displayname}
            onChange={(e) => setDisplayname(e.target.value)}
            required
          />
        </div>
        <div className="form-group">
          <label htmlFor="email">Email</label>
          <input
            type="email"
            id="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
          />
        </div>
        <div className="form-group">
          <label htmlFor="password">Password</label>
          <input
            type="password"
            id="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
        </div>
        <div className="form-group">
          <label>Avatar</label>
          <div className="avatar-section">
            <AvatarUploader 
              onAvatarSelected={(selectedAvatar) => setAvatar(selectedAvatar)}
              onRemoveAvatar={() => setAvatar('')}
              defaultAvatar={avatar}
            />
          </div>
        </div>
        <button type="submit">Register</button>
      </form>
      {error && <p className="error-message">{error}</p>}
      {success && <p className="success-message">{success}</p>}
      <p>Already have an account? <a href="/login">Login</a></p>
    </div>
  );
};

export default Register;