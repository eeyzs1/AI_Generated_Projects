import React, { useState, useEffect } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';

const VerifyEmail: React.FC = () => {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const token = searchParams.get('token');
    if (token) {
      verifyEmail(token);
    } else {
      setError('No verification token provided');
      setLoading(false);
    }
  }, [searchParams]);

  const verifyEmail = async (token: string) => {
    try {
      const response = await fetch(`/api/user/verify-email?token=${token}`);
      const data = await response.json();
      if (response.ok) {
        setMessage(data.message);
        setError('');
      } else {
        // 检查是否是因为 token 已经被使用过
        if (data.detail === 'Invalid or expired token') {
          // 不显示错误，因为用户可能已经验证过了
          setMessage('Email already verified. You can now login.');
          setError('');
        } else {
          setError(data.detail || 'Verification failed');
        }
      }
    } catch (err) {
      setError('An error occurred during verification');
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const handleLogin = () => {
    navigate('/login');
  };

  if (loading) {
    return <div className="verify-email-container"><h2>Verifying email...</h2></div>;
  }

  return (
    <div className="verify-email-container">
      <h2>Email Verification</h2>
      {message && <div className="success-message">{message}</div>}
      {error && <div className="error-message">{error}</div>}
      <button onClick={handleLogin}>Go to Login</button>
    </div>
  );
};

export default VerifyEmail;