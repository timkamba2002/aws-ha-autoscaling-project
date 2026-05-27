import React, { useState, useEffect } from 'react';

const TodoApp: React.FC = () => {
  const [user, setUser] = useState<any>(null);
  const [todos, setTodos] = useState<string[]>([]);
  const [newTodo, setNewTodo] = useState('');
  const [email, setEmail] = useState('');

  // Mock Google Sign In
  const handleGoogleLogin = () => {
    const mockUser = {
      uid: "user_" + Date.now(),
      displayName: "Timothy Kamba",
      email: "timothy.kamba@example.com"
    };
    setUser(mockUser);
    setEmail(mockUser.email);
    localStorage.setItem('user', JSON.stringify(mockUser));
    alert("✅ Logged in with Google (Demo Mode)");
  };

  const addTodo = () => {
    if (newTodo.trim() && user) {
      setTodos([...todos, newTodo.trim()]);
      setNewTodo('');
    }
  };

  const deleteTodo = (index: number) => {
    setTodos(todos.filter((_, i) => i !== index));
  };

  const sendToEmail = async () => {
    if (!user || todos.length === 0) return alert("No tasks to send!");

    try {
      const response = await fetch('http://YOUR_ALB_DNS/api/send-tasks', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: user.email, tasks: todos })
      });
      if (response.ok) {
        alert("✅ Tasks sent to your email via SNS!");
      }
    } catch (error) {
      alert("Failed to send email");
    }
  };

  useEffect(() => {
    const savedUser = localStorage.getItem('user');
    if (savedUser) setUser(JSON.parse(savedUser));
  }, []);

  return (
    <div style={{ padding: '20px', maxWidth: '600px', margin: '0 auto', fontFamily: 'Arial' }}>
      <h1>✅ My To-Do List</h1>

      {!user ? (
        <button onClick={handleGoogleLogin} style={{ padding: '10px 20px', fontSize: '16px' }}>
          Sign in with Google
        </button>
      ) : (
        <>
          <p>Welcome, <strong>{user.displayName}</strong> ({user.email})</p>
          
          <div style={{ margin: '20px 0' }}>
            <input
              value={newTodo}
              onChange={(e) => setNewTodo(e.target.value)}
              placeholder="Add new task..."
              style={{ padding: '8px', width: '70%' }}
              onKeyPress={(e) => e.key === 'Enter' && addTodo()}
            />
            <button onClick={addTodo} style={{ padding: '8px 16px' }}>Add</button>
          </div>

          <ul>
            {todos.map((todo, index) => (
              <li key={index} style={{ margin: '8px 0' }}>
                {todo}
                <button onClick={() => deleteTodo(index)} style={{ marginLeft: '10px', color: 'red' }}>Delete</button>
              </li>
            ))}
          </ul>

          <button onClick={sendToEmail} style={{ marginTop: '20px', padding: '10px 20px', background: '#28a745', color: 'white' }}>
            📧 Send Tasks to Email (SNS)
          </button>
        </>
      )}
    </div>
  );
};

export default TodoApp;
