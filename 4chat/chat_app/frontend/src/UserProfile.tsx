import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import './AvatarStyles.css';
import AvatarUploader from './AvatarUploader';

interface User {
  id: number;
  username: string;
  displayname: string;
  email: string;
  avatar: string | null;
  created_at: string;
  is_active: boolean;
}

interface UserProfileProps {
  user: User;
  onLogout: () => void;
  onUserUpdate: (updatedUser: User) => void;
  authenticatedFetch: (url: string, options?: RequestInit) => Promise<Response>;
}

const UserProfile: React.FC<UserProfileProps> = ({ user, onLogout, onUserUpdate, authenticatedFetch }) => {
  const navigate = useNavigate();
  const [username, setUsername] = useState(user.username);
  const [displayname, setDisplayname] = useState(user.displayname);
  const [email, setEmail] = useState(user.email);
  const [avatar, setAvatar] = useState<string>(user.avatar || '');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [isEditing, setIsEditing] = useState(false);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setSuccess('');

    if (isEditing) {
      // 检查是否已选择头像
      if (!avatar) {
        setError('Please select an avatar');
        return;
      }
      
      if (password && password !== confirmPassword) {
        setError('Passwords do not match');
        return;
      }

      const updateData: any = {
        username,
        displayname,
        email,
        avatar
      };

      if (password) {
        updateData.password = password;
      }

      authenticatedFetch('/users/me', {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(updateData)
      })
      .then(response => {
        if (!response.ok) {
          throw new Error('Update failed');
        }
        return response.json();
      })
      .then(data => {
        setSuccess('Profile updated successfully');
        setIsEditing(false);
        onUserUpdate(data);
      })
      .catch(err => {
        setError('Failed to update profile');
        console.error(err);
      });
    } else {
      setIsEditing(true);
    }
  };

  return (
    <div className="user-profile-container">
      <div className="profile-header">
        <h2>User Profile</h2>
        <div className="header-buttons">
          <button onClick={() => navigate('/')}>
            Back to Chat
          </button>
          <button onClick={onLogout}>Logout</button>
        </div>
      </div>

      {error && <div className="error-message">{error}</div>}
      {success && <div className="success-message">{success}</div>}

      <form onSubmit={handleSubmit}>
        <div className="form-group">
          <label htmlFor="username">Username</label>
          <input
            type="text"
            id="username"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            disabled={!isEditing}
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
            disabled={!isEditing}
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
            disabled={!isEditing}
            required
          />
        </div>

        <div className="form-group">
          <label>Avatar</label>
          <div className="avatar-section">
            <div className="current-avatar">
              <img 
                src={avatar || '/static/avatars/default/default1.png'} 
                alt="Current avatar" 
                className="avatar-image"
              />
            </div>
            {isEditing && (
              <div className="avatar-options">
                <AvatarUploader 
                  onAvatarSelected={(selectedAvatar) => setAvatar(selectedAvatar)}
                  onRemoveAvatar={() => setAvatar('')}
                  defaultAvatar={avatar}
                />
              </div>
            )}
          </div>
        </div>

        {isEditing && (
          <>
            <div className="form-group">
              <label htmlFor="password">New Password (leave blank to keep current)</label>
              <input
                type="password"
                id="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
            </div>

            <div className="form-group">
              <label htmlFor="confirmPassword">Confirm New Password</label>
              <input
                type="password"
                id="confirmPassword"
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
              />
            </div>
          </>
        )}

        <div className="form-actions">
          <button type="submit">
            {isEditing ? 'Save Changes' : 'Edit Profile'}
          </button>
          {isEditing && (
            <button type="button" onClick={() => {
              setIsEditing(false);
              setUsername(user.username);
              setDisplayname(user.displayname);
              setEmail(user.email);
              setAvatar(user.avatar || '');
              setPassword('');
              setConfirmPassword('');
              setError('');
              setSuccess('');
            }}>
              Cancel
            </button>
          )}
        </div>
      </form>

      <div className="user-info">
        <h3>Account Information</h3>
        <p><strong>User ID:</strong> {user.id}</p>
        <p><strong>Account Created:</strong> {new Date(user.created_at).toLocaleString()}</p>
        <p><strong>Account Status:</strong> {user.is_active ? 'Active' : 'Inactive'}</p>
      </div>
    </div>
  );
};

export default UserProfile;