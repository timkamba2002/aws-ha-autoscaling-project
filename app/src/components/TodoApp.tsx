import React, { useState, useEffect } from 'react';
import { Container, Typography, Box } from '@mui/material';
import TodoList from './TodoList';
import GoogleLoginButton from './GoogleLoginButton';

const TodoApp: React.FC = () => {
  const [user, setUser] = useState<any>(null);

  const handleLoginSuccess = (userData: any) => {
    setUser(userData);
    localStorage.setItem('user', JSON.stringify(userData));
  };

  useEffect(() => {
    const savedUser = localStorage.getItem('user');
    if (savedUser) setUser(JSON.parse(savedUser));
  }, []);

  return (
    <Container maxWidth="md">
      <Box sx={{ textAlign: 'center', mt: 4 }}>
        <Typography variant="h3" gutterBottom>
          My Todo List
        </Typography>

        {!user ? (
          <GoogleLoginButton onSuccess={handleLoginSuccess} />
        ) : (
          <>
            <Typography variant="h6" gutterBottom>
              Welcome, {user.displayName}!
            </Typography>
            <TodoList userId={user.uid} />
          </>
        )}
      </Box>
    </Container>
  );
};

export default TodoApp;
