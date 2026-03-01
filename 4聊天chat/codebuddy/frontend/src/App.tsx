import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { WebSocketProvider } from './WebSocketContext';
import Login from './Login';
import Register from './Register';
import ChatRoom from './ChatRoom';

const PrivateRoute: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const token = localStorage.getItem('token');
  return token ? <>{children}</> : <Navigate to="/login" />;
};

function App() {
  return (
    <WebSocketProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route path="/register" element={<Register />} />
          <Route
            path="/"
            element={
              <PrivateRoute>
                <ChatRoom />
              </PrivateRoute>
            }
          />
        </Routes>
      </BrowserRouter>
    </WebSocketProvider>
  );
}

export default App;
