import React, { useState, useEffect, useRef } from 'react';
import './AvatarStyles.css';

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
}

const UserProfile: React.FC<UserProfileProps> = ({ user, onLogout, onUserUpdate }) => {
  const [username, setUsername] = useState(user.username);
  const [displayname, setDisplayname] = useState(user.displayname);
  const [email, setEmail] = useState(user.email);
  const [avatar, setAvatar] = useState<string>(user.avatar || '');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [isEditing, setIsEditing] = useState(false);
  const [previewImage, setPreviewImage] = useState<string>('');
  const [isCropping, setIsCropping] = useState(false);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  // 默认头像列表
  const defaultAvatars = [
    '/static/avatars/default1.png',
    '/static/avatars/default2.png',
    '/static/avatars/default3.png',
    '/static/avatars/default4.png',
    '/static/avatars/default5.png'
  ];

  // 压缩和裁剪图片
  const compressAndCropImage = (file: File): Promise<string> => {
    return new Promise((resolve) => {
      const canvas = canvasRef.current;
      if (!canvas) {
        resolve('');
        return;
      }
      
      const ctx = canvas.getContext('2d');
      if (!ctx) {
        resolve('');
        return;
      }
      
      const img = new Image();
      img.onload = () => {
        // 设置canvas尺寸为200x200
        canvas.width = 200;
        canvas.height = 200;
        
        // 计算裁剪区域
        const minSide = Math.min(img.width, img.height);
        const x = (img.width - minSide) / 2;
        const y = (img.height - minSide) / 2;
        
        // 绘制并裁剪图片
        ctx.drawImage(img, x, y, minSide, minSide, 0, 0, 200, 200);
        
        // 将canvas转换为base64
        const compressedImage = canvas.toDataURL('image/jpeg', 0.7);
        resolve(compressedImage);
      };
      img.src = URL.createObjectURL(file);
    });
  };

  // 将base64转换为File对象
  const dataURLtoFile = (dataurl: string, filename: string): File => {
    const arr = dataurl.split(',');
    const mime = arr[0].match(/:(.*?);/)?.[1] || 'image/jpeg';
    const bstr = atob(arr[1]);
    let n = bstr.length;
    const u8arr = new Uint8Array(n);
    while (n--) {
      u8arr[n] = bstr.charCodeAt(n);
    }
    return new File([u8arr], filename, { type: mime });
  };

  const handleAvatarUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    
    // 显示预览
    setPreviewImage(URL.createObjectURL(file));
    setIsCropping(true);
  };

  const handleCropAndUpload = async () => {
    if (!fileInputRef.current?.files?.[0]) return;
    
    const file = fileInputRef.current.files[0];
    
    try {
      // 压缩和裁剪图片
      const compressedImageDataUrl = await compressAndCropImage(file);
      
      // 将压缩后的图片转换为File对象
      const compressedFile = dataURLtoFile(compressedImageDataUrl, file.name);
      
      // 上传压缩后的图片
      const formData = new FormData();
      formData.append('file', compressedFile);
      
      const response = await fetch('http://localhost:8000/upload-avatar', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('token')}`
        },
        body: formData,
      });
      
      if (!response.ok) {
        throw new Error('Upload failed');
      }
      
      const data = await response.json();
      setAvatar(data.avatar_url);
      setIsCropping(false);
      setPreviewImage('');
    } catch (err) {
      setError('Avatar upload failed');
      setIsCropping(false);
      setPreviewImage('');
    }
  };

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
        displayname,
        email,
        avatar
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
                src={avatar || '/static/avatars/default1.png'} 
                alt="Current avatar" 
                className="avatar-image"
              />
            </div>
            {isEditing && (
              <div className="avatar-options">
                <div className="default-avatars">
                  {defaultAvatars.map((defaultAvatar, index) => (
                    <div 
                      key={index} 
                      className={`avatar-option ${avatar === defaultAvatar ? 'selected' : ''}`}
                      onClick={() => {
                        setAvatar(defaultAvatar);
                        setIsCropping(false);
                        setPreviewImage('');
                      }}
                    >
                      <img src={defaultAvatar} alt={`Default avatar ${index + 1}`} />
                    </div>
                  ))}
                </div>
                <div className="upload-avatar">
                  <input
                    ref={fileInputRef}
                    type="file"
                    accept="image/*"
                    onChange={handleAvatarUpload}
                  />
                  {isCropping && previewImage && (
                    <div className="image-preview">
                      <h4>Preview and Crop</h4>
                      <div className="crop-container">
                        <canvas ref={canvasRef} className="crop-canvas"></canvas>
                        <div className="preview-overlay">
                          <p>Image will be cropped to 200x200 pixels</p>
                        </div>
                      </div>
                      <div className="crop-actions">
                        <button type="button" onClick={handleCropAndUpload}>Confirm and Upload</button>
                        <button type="button" onClick={() => {
                          setIsCropping(false);
                          setPreviewImage('');
                          if (fileInputRef.current) {
                            fileInputRef.current.value = '';
                          }
                        }}>Cancel</button>
                      </div>
                    </div>
                  )}
                </div>
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