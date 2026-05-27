import React, { useState, useEffect } from 'react';

const TodoApp: React.FC = () => {
  const [user, setUser] = useState<any>(null);
  const [todos, setTodos] = useState<string[]>([]);
  const [newTodo, setNewTodo] = useState('');

  // Mock Google Sign In
  const handleGoogleLogin = () => {
    const mockUser = {
      uid: "user_" + Date.now(),
      displayName: "Timothy Kamba",
      email: "timothy.kamba@example.com"
    };
    setUser(mockUser);
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
    if (!user || todos.length === 0) {
      alert("No tasks to send or not logged in!");
      return;
    }

    try {
      const response = await fetch('http://ha-project-alb-1568483483.us-east-1.elb.amazonaws.com/api/send-tasks', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: user.email, tasks: todos })
      });

      if (response.ok) {
        alert("✅ Tasks sent to your email via AWS SNS!");
      } else {
        alert("Failed to send email");
      }
    } catch (error) {
      alert("Could not connect to backend. SNS setup coming soon.");
    }
  };

  useEffect(() => {
    const savedUser = localStorage.getItem('user');
    if (savedUser) setUser(JSON.parse(savedUser));
  }, []);

  return (
    <div style={{ padding: '30px', maxWidth: '700px', margin: '0 auto', fontFamily: 'Arial, sans-serif' }}>
      <h1>✅ My To-Do List</h1>

      {!user ? (
        <button 
          onClick={handleGoogleLogin} 
          style={{ padding: '12px 24px', fontSize: '18px', cursor: 'pointer' }}
        >
          🔑 Sign in with Google
        </button>
      ) : (
        <>
          <p>Welcome, <strong>{user.displayName}</strong> ({user.email})</p>
          
          <div style={{ margin: '20px 0' }}>
            <input
              value={newTodo}
              onChange={(e) => setNewTodo(e.target.value)}
              placeholder="What needs to be done?"
              style={{ padding: '10px', width: '70%', fontSize: '16px' }}
              onKeyPress={(e) => e.key === 'Enter' && addTodo()}
            />
            <button onClick={addTodo} style={{ padding: '10px 20px', marginLeft: '8px' }}>Add Task</button>
          </div>

          <ul style={{ listStyle: 'none', padding: 0 }}>
            {todos.map((todo, index) => (
              <li key={index} style={{ padding: '10px', background: '#fff', margin: '8px 0', borderRadius: '4px' }}>
                {todo}
                <button 
                  onClick={() => deleteTodo(index)} 
                  style={{ float: 'right', color: 'red', border: 'none', background: 'none', cursor: 'pointer' }}
                >
                  Delete
                </button>
              </li>
            ))}
          </ul>

          {todos.length > 0 && (
            <button 
              onClick={sendToEmail} 
              style={{ marginTop: '20px', padding: '12px 24px', background: '#28a745', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer' }}
            >
              📧 Send Tasks to Email (via AWS SNS)
            </button>
          )}
        </>
      )}
    </div>
  );
};

export default TodoApp;
