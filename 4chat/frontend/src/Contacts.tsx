import React, { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';

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

interface ContactsProps {
  user: User;
  onLogout: () => void;
  authenticatedFetch: (url: string, options?: RequestInit) => Promise<Response>;
}

const Contacts: React.FC<ContactsProps> = ({ user, onLogout, authenticatedFetch }) => {
  const [contacts, setContacts] = useState<Contact[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState<Contact[]>([]);
  const [isSearching, setIsSearching] = useState(false);
  const navigate = useNavigate();

  // 获取联系人列表
  useEffect(() => {
    const fetchContacts = async () => {
      try {
        const response = await authenticatedFetch('/api/user/contacts');
        if (response.ok) {
          const data = await response.json();
          // 按displayname字母顺序排序
          const sortedContacts = data.sort((a: Contact, b: Contact) => {
            return a.displayname.localeCompare(b.displayname);
          });
          setContacts(sortedContacts);
        }
      } catch (error) {
        console.error('Error fetching contacts:', error);
      }
    };

    fetchContacts();
  }, [authenticatedFetch]);

  // 搜索用户
  const handleSearch = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!searchQuery.trim()) {
      setSearchResults([]);
      setIsSearching(false);
      return;
    }

    try {
      const response = await authenticatedFetch(`/api/user/search?query=${encodeURIComponent(searchQuery)}`);
      if (response.ok) {
        const data = await response.json();
        setSearchResults(data);
        setIsSearching(true);
      }
    } catch (error) {
      console.error('Error searching users:', error);
    }
  };

  // 发送联系人请求
  const handleAddContact = async (userId: number) => {
    try {
      const response = await authenticatedFetch('/api/user/contact-requests', {
        method: 'POST',
        body: JSON.stringify({ receiver_id: userId })
      });
      if (response.ok) {
        alert('Contact request sent successfully!');
        setSearchQuery('');
        setSearchResults([]);
        setIsSearching(false);
      } else {
        alert('Failed to send contact request');
      }
    } catch (error) {
      console.error('Error sending contact request:', error);
      alert('Failed to send contact request');
    }
  };

  // 跳转到联系人个人信息页面
  const handleContactClick = (contact: Contact) => {
    navigate(`/contact/${contact.id}`, { state: { contact } });
  };

  return (
    <div style={{ maxWidth: '800px', margin: '0 auto', padding: '20px' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px', paddingBottom: '10px', borderBottom: '1px solid #e0e0e0' }}>
        <h1 style={{ margin: 0, color: '#333' }}>Contacts</h1>
        <div style={{ display: 'flex', gap: '10px' }}>
          <Link to="/" style={{ 
            padding: '8px 16px', 
            border: '1px solid #ddd', 
            borderRadius: '4px', 
            textDecoration: 'none', 
            color: '#333', 
            backgroundColor: '#f5f5f5', 
            cursor: 'pointer', 
            transition: 'all 0.3s ease' 
          }}>Chats</Link>
          <Link to="/profile" style={{ 
            padding: '8px 16px', 
            border: '1px solid #ddd', 
            borderRadius: '4px', 
            textDecoration: 'none', 
            color: '#333', 
            backgroundColor: '#f5f5f5', 
            cursor: 'pointer', 
            transition: 'all 0.3s ease' 
          }}>Profile</Link>
          <button onClick={onLogout} style={{ 
            padding: '8px 16px', 
            border: '1px solid #ddd', 
            borderRadius: '4px', 
            backgroundColor: '#ff4757', 
            color: 'white', 
            cursor: 'pointer', 
            transition: 'all 0.3s ease' 
          }}>Logout</button>
        </div>
      </div>

      <div style={{ marginBottom: '20px' }}>
        <form onSubmit={handleSearch} style={{ display: 'flex', gap: '10px' }}>
          <input
            type="text"
            placeholder="Search users..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            style={{ 
              flex: 1, 
              padding: '10px', 
              border: '1px solid #ddd', 
              borderRadius: '4px' 
            }}
          />
          <button type="submit" style={{ 
            padding: '10px 20px', 
            backgroundColor: '#3498db', 
            color: 'white', 
            border: 'none', 
            borderRadius: '4px', 
            cursor: 'pointer' 
          }}>Search</button>
        </form>
      </div>

      {isSearching ? (
        <div style={{ marginTop: '20px' }}>
          <h2 style={{ marginBottom: '15px', color: '#333' }}>Search Results</h2>
          {searchResults.length > 0 ? (
            <ul style={{ listStyle: 'none', padding: 0, margin: 0 }}>
              {searchResults.map((user) => (
                <li key={user.id} style={{ 
                  display: 'flex', 
                  alignItems: 'center', 
                  padding: '15px', 
                  borderBottom: '1px solid #e0e0e0', 
                  cursor: 'pointer', 
                  transition: 'background-color 0.3s ease' 
                }}>
                  <div style={{ 
                    width: '50px', 
                    height: '50px', 
                    borderRadius: '50%', 
                    overflow: 'hidden', 
                    marginRight: '15px' 
                  }}>
                    <img src={user.avatar || '/api/storage/static/avatars/default/default1.png'} alt={user.displayname} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                  </div>
                  <div style={{ flex: 1 }}>
                    <h3 style={{ margin: '0 0 5px 0', color: '#333' }}>{user.displayname}</h3>
                    <p style={{ margin: 0, color: '#666', fontSize: '14px' }}>@{user.username}</p>
                  </div>
                  <button 
                    onClick={() => handleAddContact(user.id)}
                    style={{ 
                      padding: '6px 12px', 
                      backgroundColor: '#27ae60', 
                      color: 'white', 
                      border: 'none', 
                      borderRadius: '4px', 
                      cursor: 'pointer', 
                      fontSize: '14px' 
                    }}
                  >
                    Add Contact
                  </button>
                </li>
              ))}
            </ul>
          ) : (
            <p style={{ color: '#666', fontStyle: 'italic' }}>No users found</p>
          )}
        </div>
      ) : (
        <div style={{ marginTop: '20px' }}>
          <h2 style={{ marginBottom: '15px', color: '#333' }}>My Contacts</h2>
          {contacts.length > 0 ? (
            <ul style={{ listStyle: 'none', padding: 0, margin: 0 }}>
              {contacts.map((contact) => (
                <li 
                  key={contact.id} 
                  style={{ 
                    display: 'flex', 
                    alignItems: 'center', 
                    padding: '15px', 
                    borderBottom: '1px solid #e0e0e0', 
                    cursor: 'pointer', 
                    transition: 'background-color 0.3s ease' 
                  }}
                  onClick={() => handleContactClick(contact)}
                >
                  <div style={{ 
                    width: '50px', 
                    height: '50px', 
                    borderRadius: '50%', 
                    overflow: 'hidden', 
                    marginRight: '15px' 
                  }}>
                    <img src={contact.avatar || '/api/storage/static/avatars/default/default1.png'} alt={contact.displayname} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                  </div>
                  <div style={{ flex: 1 }}>
                    <h3 style={{ margin: '0 0 5px 0', color: '#333' }}>{contact.displayname}</h3>
                    <p style={{ margin: 0, color: '#666', fontSize: '14px' }}>@{contact.username}</p>
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center' }}>
                    <span style={{ 
                      width: '10px', 
                      height: '10px', 
                      borderRadius: '50%', 
                      backgroundColor: '#27ae60', 
                      marginRight: '10px' 
                    }}></span>
                  </div>
                </li>
              ))}
            </ul>
          ) : (
            <p style={{ color: '#666', fontStyle: 'italic' }}>You don't have any contacts yet. Search for users to add as contacts.</p>
          )}
        </div>
      )}
    </div>
  );
};

export default Contacts;