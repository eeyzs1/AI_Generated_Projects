import React, { useState, useEffect } from 'react';

interface User {
  id: number;
  username: string;
  email: string;
  created_at: string;
  is_active: boolean;
}

interface UserProfileProps {
  user: User;
  onLogout: () => void;
  onUserUpdate: (updatedUser: User) => void;
}

const UserProfile: React.FC<UserProfileProps> = ({ user, onLogout, onUserUpdate }) => {
  const [username, setUsername] = useState(user.username);
  const [email, setEmail] = useState(user.email);
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
      if (password && password !== confirmPassword) {
        setError('Passwords do not match');
        return;
      }

      const updateData: any = {
        username,
        email
      };

      if (password) {
        updateData.password = password;
      }

      fetch('http://localhost:8000/users/me', {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${localStorage.getItem('token')}`
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
          <button onClick={() => window.location.href = '/'}>
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
              setEmail(user.email);
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