import React, { useState, useEffect } from 'react';
import { useParams, useNavigate, useLocation } from 'react-router-dom';

interface User {
  id: number;
  username: string;
  displayname: string;
  email: string;
  avatar: string | null;
  created_at: string;
  is_active: boolean;
}

interface Contact {
  id: number;
  username: string;
  displayname: string;
  avatar: string | null;
}

interface ContactProfileProps {
  user: User;
  onLogout: () => void;
  authenticatedFetch: (url: string, options?: RequestInit) => Promise<Response>;
}

const ContactProfile: React.FC<ContactProfileProps> = ({ user, onLogout, authenticatedFetch }) => {
  const { contactId } = useParams<{ contactId: string }>();
  const navigate = useNavigate();
  const location = useLocation();
  const [contact, setContact] = useState<Contact | null>(location.state?.contact || null);
  const [loading, setLoading] = useState(!contact);

  // 获取联系人信息
  useEffect(() => {
    if (!contact && contactId) {
      const fetchContactInfo = async () => {
        try {
          setLoading(true);
          const response = await authenticatedFetch(`/users/${contactId}`);
          if (response.ok) {
            const data = await response.json();
            setContact({
              id: data.id,
              username: data.username,
              displayname: data.displayname,
              avatar: data.avatar
            });
          }
        } catch (error) {
          console.error('Error fetching contact info:', error);
        } finally {
          setLoading(false);
        }
      };

      fetchContactInfo();
    }
  }, [contact, contactId, authenticatedFetch]);

  // 发送消息（创建或进入双人聊天室）
  const handleSendMessage = async () => {
    if (!contact) return;

    try {
      // 先获取用户的所有聊天室
      const response = await authenticatedFetch('/rooms');
      if (response.ok) {
        const rooms = await response.json();
        
        // 查找是否存在只有当前用户和联系人的双人聊天室
        let existingRoom = null;
        for (const room of rooms) {
          if (room.members && room.members.length === 2) {
            const memberIds = room.members.map((member: any) => member.id);
            if (memberIds.includes(user.id) && memberIds.includes(contact.id)) {
              existingRoom = room;
              break;
            }
          }
        }

        if (existingRoom) {
          // 进入现有的双人聊天室
          navigate(`/room/${existingRoom.id}`);
        } else {
          // 创建新的双人聊天室
          const createResponse = await authenticatedFetch('/rooms', {
            method: 'POST',
            body: JSON.stringify({
              name: `${user.displayname} & ${contact.displayname}`,
              description: 'Private chat'
            })
          });

          if (createResponse.ok) {
            const newRoom = await createResponse.json();
            
            // 添加联系人到聊天室
            await authenticatedFetch(`/rooms/${newRoom.id}/add/${contact.id}`, {
              method: 'POST'
            });

            // 进入新创建的聊天室
            navigate(`/room/${newRoom.id}`);
          }
        }
      }
    } catch (error) {
      console.error('Error creating or joining chat room:', error);
      alert('Failed to create or join chat room');
    }
  };

  // 删除联系人
  const handleRemoveContact = async () => {
    if (!contact) return;

    if (window.confirm('Are you sure you want to remove this contact?')) {
      try {
        const response = await authenticatedFetch(`/contacts/${contact.id}`, {
          method: 'DELETE'
        });

        if (response.ok) {
          alert('Contact removed successfully');
          navigate('/contacts');
        } else {
          alert('Failed to remove contact');
        }
      } catch (error) {
        console.error('Error removing contact:', error);
        alert('Failed to remove contact');
      }
    }
  };

  if (loading) {
    return <div>Loading...</div>;
  }

  if (!contact) {
    return <div>Contact not found</div>;
  }

  return (
    <div style={{ maxWidth: '600px', margin: '0 auto', padding: '20px' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '30px', paddingBottom: '10px', borderBottom: '1px solid #e0e0e0' }}>
        <button 
          onClick={() => navigate('/contacts')} 
          style={{ 
            padding: '8px 16px', 
            border: '1px solid #ddd', 
            borderRadius: '4px', 
            backgroundColor: '#f5f5f5', 
            cursor: 'pointer', 
            transition: 'all 0.3s ease' 
          }}
        >
          Back
        </button>
        <h1 style={{ margin: 0, color: '#333' }}>Contact Profile</h1>
        <div style={{ display: 'flex', gap: '10px' }}>
          <button 
            onClick={onLogout} 
            style={{ 
              padding: '10px 20px', 
              border: 'none', 
              borderRadius: '4px', 
              backgroundColor: '#ff4757', 
              color: 'white', 
              cursor: 'pointer', 
              transition: 'all 0.3s ease', 
              fontSize: '14px' 
            }}
          >
            Logout
          </button>
        </div>
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '20px' }}>
        <div style={{ 
          width: '150px', 
          height: '150px', 
          borderRadius: '50%', 
          overflow: 'hidden', 
          border: '3px solid #e0e0e0' 
        }}>
          <img src={contact.avatar || '/static/avatars/default/default1.png'} alt={contact.displayname} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
        </div>
        <div style={{ textAlign: 'center' }}>
          <h2 style={{ margin: '0 0 10px 0', color: '#333', fontSize: '24px' }}>{contact.displayname}</h2>
          <p style={{ margin: 0, color: '#666', fontSize: '16px' }}>@{contact.username}</p>
        </div>
        <div style={{ display: 'flex', gap: '15px', marginTop: '20px' }}>
          <button 
            onClick={handleSendMessage} 
            style={{ 
              padding: '10px 20px', 
              border: 'none', 
              borderRadius: '4px', 
              backgroundColor: '#3498db', 
              color: 'white', 
              cursor: 'pointer', 
              transition: 'all 0.3s ease', 
              fontSize: '14px' 
            }}
          >
            Send Message
          </button>
          <button 
            onClick={handleRemoveContact} 
            style={{ 
              padding: '10px 20px', 
              border: 'none', 
              borderRadius: '4px', 
              backgroundColor: '#e74c3c', 
              color: 'white', 
              cursor: 'pointer', 
              transition: 'all 0.3s ease', 
              fontSize: '14px' 
            }}
          >
            Remove Contact
          </button>
        </div>
      </div>
    </div>
  );
};

export default ContactProfile;