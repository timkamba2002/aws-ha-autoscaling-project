import React from 'react';
import { Button } from '@mui/material';
import GoogleIcon from '@mui/icons-material/Google';

const GoogleLoginButton: React.FC<{ onSuccess: (user: any) => void }> = ({ onSuccess }) => {
  const handleGoogleLogin = () => {
    const mockUser = {
      uid: "user_" + Date.now(),
      displayName: "Demo User",
      email: "demo@example.com"
    };
    onSuccess(mockUser);
    alert("✅ Logged in with Google (Demo Mode)");
  };

  return (
    <Button
      variant="contained"
      startIcon={<GoogleIcon />}
      onClick={handleGoogleLogin}
      size="large"
      sx={{ mt: 3 }}
    >
      Sign in with Google
    </Button>
  );
};

export default GoogleLoginButton;
