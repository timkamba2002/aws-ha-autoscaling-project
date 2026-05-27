import React, { useState, useEffect } from 'react';

const API_URL = 'http://ha-project-alb-1568483483.us-east-1.elb.amazonaws.com/api';

const TodoApp: React.FC = () => {
  const [user, setUser] = useState<any>(null);
  const [todos, setTodos] = useState<any[]>([]);
  const [newTodo, setNewTodo] = useState('');
  const [loading, setLoading] = useState(false);

  const handleGoogleLogin = () => {
    const mockUser = {
      uid: "user_" + Date.now(),
      displayName: "Timothy Kamba",
      email: "timothy.kamba@example.com"
    };
    setUser(mockUser);
    localStorage.setItem('user', JSON.stringify(mockUser));
    alert("✅ Logged in with Google (Demo)");
    fetchTodos(mockUser.uid);
  };

  const fetchTodos = async (userId: string) => {
    try {
      const res = await fetch(`${API_URL}/todos?userId=${userId}`);
      const data = await res.json();
      setTodos(data);
    } catch (err) {
      console.log("Backend not ready yet");
    }
  };

  const addTodo = async () => {
    if (!newTodo.trim() || !user) return;
    
    try {
      await fetch(`${API_URL}/todos`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId: user.uid, task: newTodo.trim() })
      });
      setNewTodo('');
      fetchTodos(user.uid);
    } catch (err) {
      alert("Failed to save task");
    }
  };

  const deleteTodo = async (id: number) => {
    try {
      await fetch(`${API_URL}/todos/${id}`, { method: 'DELETE' });
      fetchTodos(user.uid);
    } catch (err) {
      alert("Failed to delete task");
    }
  };

  const sendToEmail = async () => {
    if (!user || todos.length === 0) return alert("No tasks!");

    try {
      await fetch(`${API_URL}/send-tasks`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: user.email, tasks: todos.map(t => t.task) })
      });
      alert("✅ Tasks sent to email via AWS SNS!");
    } catch (err) {
      alert("Backend not ready for SNS yet");
    }
  };

  useEffect(() => {
    const saved = localStorage.getItem('user');
    if (saved) {
      const u = JSON.parse(saved);
      setUser(u);
      fetchTodos(u.uid);
    }
  }, []);

  return (
    <div style={{ padding: '30px', maxWidth: '700px', margin: '0 auto', fontFamily: 'Arial' }}>
      <h1>✅ My To-Do List</h1>

      {!user ? (
        <button onClick={handleGoogleLogin} style={{ padding: '15px 30px', fontSize: '18px' }}>
          🔑 Sign in with Google
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

          <ul style={{ listStyle: 'none', padding: 0 }}>
            {todos.map((todo) => (
              <li key={todo.id} style={{ padding: '12px', background: '#fff', margin: '8px 0', borderRadius: '6px' }}>
                {todo.task}
                <button onClick={() => deleteTodo(todo.id)} style={{ float: 'right', color: 'red' }}>Delete</button>
              </li>
            ))}
          </ul>

          {todos.length > 0 && (
            <button onClick={sendToEmail} style={{ marginTop: '20px', padding: '12px 24px', background: '#28a745', color: 'white' }}>
              📧 Send All Tasks to Email (SNS)
            </button>
          )}
        </>
      )}
    </div>
  );
};

export default TodoApp;
