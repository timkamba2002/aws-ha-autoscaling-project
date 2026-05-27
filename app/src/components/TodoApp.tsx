import React, { useState, useEffect } from 'react';

const API_BASE = 'http://ha-project-alb-1568483483.us-east-1.elb.amazonaws.com/api';

const TodoApp: React.FC = () => {
  const [user, setUser] = useState<any>(null);
  const [todos, setTodos] = useState<any[]>([]);
  const [newTodo, setNewTodo] = useState('');

  const handleGoogleLogin = () => {
    const mockUser = {
      uid: "user_" + Date.now(),
      displayName: "Timothy Kamba",
      email: "timothy.kamba@example.com"
    };
    setUser(mockUser);
    localStorage.setItem('user', JSON.stringify(mockUser));
    alert("✅ Logged in with Google");
    fetchTodos(mockUser.uid);
  };

  const fetchTodos = async (userId: string) => {
    try {
      const res = await fetch(`${API_BASE}/todos?userId=${userId}`);
      const data = await res.json();
      setTodos(data);
    } catch (e) {
      console.log("Backend not responding yet");
    }
  };

  const addTodo = async () => {
    if (!newTodo.trim() || !user) return;
    try {
      await fetch(`${API_BASE}/todos`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId: user.uid, task: newTodo })
      });
      setNewTodo('');
      fetchTodos(user.uid);
    } catch (e) {
      alert("Failed to save - backend not ready");
    }
  };

  useEffect(() => {
    const savedUser = localStorage.getItem('user');
    if (savedUser) {
      const u = JSON.parse(savedUser);
      setUser(u);
      fetchTodos(u.uid);
    }
  }, []);

  return (
    <div style={{ padding: '30px', maxWidth: '700px', margin: '0 auto', fontFamily: 'Arial' }}>
      <h1>✅ My To-Do List</h1>

      {!user ? (
        <button onClick={handleGoogleLogin} style={{ padding: '15px 30px', fontSize: '18px' }}>
          Sign in with Google
        </button>
      ) : (
        <>
          <p>Welcome, <strong>{user.displayName}</strong></p>

          <div style={{ margin: '20px 0' }}>
            <input
              value={newTodo}
              onChange={(e) => setNewTodo(e.target.value)}
              placeholder="Add new task..."
              style={{ padding: '10px', width: '70%' }}
              onKeyPress={(e) => e.key === 'Enter' && addTodo()}
            />
            <button onClick={addTodo} style={{ padding: '10px 20px' }}>Add</button>
          </div>

          <ul>
            {todos.map(todo => (
              <li key={todo.id} style={{ margin: '8px 0' }}>
                {todo.task}
              </li>
            ))}
          </ul>
        </>
      )}
    </div>
  );
};

export default TodoApp;
