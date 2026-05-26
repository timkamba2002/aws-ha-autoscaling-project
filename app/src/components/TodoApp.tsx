import React, { useState, useEffect } from 'react';

const TodoApp: React.FC = () => {
  const [user, setUser] = useState<any>(null);
  const [todos, setTodos] = useState<string[]>([]);
  const [newTodo, setNewTodo] = useState('');

  // Simple Google Login simulation
  const handleGoogleLogin = () => {
    const mockUser = {
      uid: "user_" + Date.now(),
      displayName: "Demo User",
      email: "demo@example.com"
    };
    setUser(mockUser);
    localStorage.setItem('user', JSON.stringify(mockUser));
    alert("✅ Logged in with Google (Demo Mode)");
  };

  const addTodo = () => {
    if (newTodo.trim()) {
      setTodos([...todos, newTodo.trim()]);
      setNewTodo('');
    }
  };

  const deleteTodo = (index: number) => {
    setTodos(todos.filter((_, i) => i !== index));
  };

  // Load saved user
  useEffect(() => {
    const savedUser = localStorage.getItem('user');
    if (savedUser) setUser(JSON.parse(savedUser));
  }, []);

  return (
    <div style={{ maxWidth: '600px', margin: '40px auto', padding: '20px', fontFamily: 'Arial, sans-serif' }}>
      <h1 style={{ textAlign: 'center' }}>My Todo List</h1>

      {!user ? (
        <div style={{ textAlign: 'center', marginTop: '50px' }}>
          <button 
            onClick={handleGoogleLogin}
            style={{
              padding: '15px 30px',
              fontSize: '18px',
              backgroundColor: '#4285f4',
              color: 'white',
              border: 'none',
              borderRadius: '5px',
              cursor: 'pointer'
            }}
          >
            Sign in with Google
          </button>
        </div>
      ) : (
        <>
          <p style={{ textAlign: 'center' }}>Welcome, {user.displayName}!</p>

          <div style={{ display: 'flex', marginBottom: '20px' }}>
            <input
              type="text"
              value={newTodo}
              onChange={(e) => setNewTodo(e.target.value)}
              onKeyPress={(e) => e.key === 'Enter' && addTodo()}
              placeholder="Enter a new task..."
              style={{ flex: 1, padding: '10px', fontSize: '16px' }}
            />
            <button 
              onClick={addTodo}
              style={{ padding: '10px 20px', marginLeft: '10px', backgroundColor: '#4CAF50', color: 'white', border: 'none', borderRadius: '5px' }}
            >
              Add
            </button>
          </div>

          <ul style={{ listStyle: 'none', padding: 0 }}>
            {todos.map((todo, index) => (
              <li key={index} style={{ 
                padding: '12px', 
                backgroundColor: '#f9f9f9', 
                marginBottom: '8px',
                borderRadius: '5px',
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center'
              }}>
                {todo}
                <button 
                  onClick={() => deleteTodo(index)}
                  style={{ backgroundColor: '#f44336', color: 'white', border: 'none', padding: '5px 10px', borderRadius: '3px' }}
                >
                  Delete
                </button>
              </li>
            ))}
          </ul>
        </>
      )}
    </div>
  );
};

export default TodoApp;
