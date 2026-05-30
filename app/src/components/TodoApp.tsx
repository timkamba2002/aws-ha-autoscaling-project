import React, { useState, useEffect, useCallback } from 'react';

const API_BASE = process.env.REACT_APP_API_BASE || 'http://ha-project-alb-1568483483.us-east-1.elb.amazonaws.com/api';

interface Todo {
  id: string;
  task: string;
  status?: string;
  priority?: string;
}

const TodoApp: React.FC = () => {
  const [user, setUser] = useState<any>(null);
  const [todos, setTodos] = useState<Todo[]>([]);
  const [newTodo, setNewTodo] = useState('');
  const [loading, setLoading] = useState(false);
  const [apiError, setApiError] = useState<string | null>(null);

  const userId = user?.uid || 'demo-user-123';

  const fetchTodos = useCallback(async () => {
    try {
      setLoading(true);
      setApiError(null);
      const res = await fetch(`${API_BASE}/tasks?userId=${userId}`);
      if (!res.ok) throw new Error(`API error: ${res.status}`);
      const data = await res.json();
      setTodos(data.map((t: any) => ({
        id: t.id,
        task: t.task || t.title,
        status: t.status,
        priority: t.priority
      })));
    } catch (e) {
      console.error('Failed to fetch tasks', e);
      setApiError('Cannot reach backend. Tasks cannot be loaded or saved right now.');
    } finally {
      setLoading(false);
    }
  }, [userId]);

  const addTodo = async () => {
    if (!newTodo.trim()) return;
    try {
      setApiError(null);
      const res = await fetch(`${API_BASE}/tasks`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId, title: newTodo.trim(), priority: 'Medium' })
      });
      if (!res.ok) throw new Error(`Failed to save: ${res.status}`);
      setNewTodo('');
      await fetchTodos();
    } catch (e) {
      console.error(e);
      setApiError('Failed to save task. Backend may be unreachable.');
    }
  };

  const toggleComplete = async (todo: Todo) => {
    const newStatus = todo.status === 'completed' ? 'pending' : 'completed';
    try {
      setApiError(null);
      const res = await fetch(`${API_BASE}/tasks/${todo.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId, status: newStatus })
      });
      if (!res.ok) throw new Error(`Update failed: ${res.status}`);
      await fetchTodos();
    } catch (e) {
      console.error(e);
      setApiError('Failed to update task. Backend may be unreachable.');
    }
  };

  useEffect(() => {
    const saved = localStorage.getItem('user');
    if (saved) setUser(JSON.parse(saved));
  }, []);

  useEffect(() => {
    if (user) fetchTodos();
  }, [user, fetchTodos]);

  return (
    <div style={{
      minHeight: '100vh',
      background: 'linear-gradient(135deg, #f5f7fa 0%, #e4e8ec 100%)',
      padding: '40px 20px',
      fontFamily: 'system-ui, -apple-system, sans-serif'
    }}>
      <div style={{ maxWidth: '680px', margin: '0 auto' }}>
        <h1 style={{ 
          fontSize: '42px', 
          fontWeight: 700, 
          textAlign: 'center', 
          marginBottom: '8px',
          color: '#1a1a1a'
        }}>
          To <span style={{ color: '#666', fontWeight: 400 }}>·</span> Do
        </h1>
        <p style={{ textAlign: 'center', color: '#666', marginBottom: '32px' }}>
          Persisted in MySQL RDS
        </p>

        {!user ? (
          <div style={{ textAlign: 'center' }}>
            <button 
              onClick={() => {
                const mock = { uid: 'demo-user-123', displayName: 'Demo User' };
                setUser(mock);
                localStorage.setItem('user', JSON.stringify(mock));
              }}
              style={{
                padding: '14px 32px',
                fontSize: 18,
                background: '#000',
                color: 'white',
                border: 'none',
                borderRadius: 8,
                cursor: 'pointer'
              }}
            >
              Sign in to start
            </button>
          </div>
        ) : (
          <div style={{
            background: 'white',
            borderRadius: 16,
            boxShadow: '0 10px 30px rgba(0,0,0,0.08)',
            padding: '32px'
          }}>
            <p style={{ marginBottom: 24, color: '#444' }}>
              Welcome, <strong>{user.displayName}</strong>
            </p>

            {apiError && (
              <div style={{
                background: '#fff3cd',
                color: '#856404',
                padding: '12px 16px',
                borderRadius: 8,
                marginBottom: 20,
                fontSize: 14
              }}>
                ⚠️ {apiError}
              </div>
            )}

            <div style={{ display: 'flex', gap: 12, marginBottom: 28 }}>
              <input
                value={newTodo}
                onChange={e => setNewTodo(e.target.value)}
                placeholder="What needs to be done?"
                style={{
                  flex: 1,
                  padding: '14px 18px',
                  fontSize: 16,
                  border: '1px solid #ddd',
                  borderRadius: 10,
                  outline: 'none'
                }}
                onKeyDown={e => e.key === 'Enter' && addTodo()}
              />
              <button 
                onClick={addTodo} 
                disabled={loading}
                style={{
                  padding: '14px 28px',
                  background: '#000',
                  color: 'white',
                  border: 'none',
                  borderRadius: 10,
                  fontSize: 15,
                  cursor: 'pointer'
                }}
              >
                Add
              </button>
            </div>

            {loading && <p style={{ color: '#888' }}>Loading...</p>}

            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              {todos.length === 0 && !loading && (
                <p style={{ color: '#999', textAlign: 'center', padding: '20px 0' }}>
                  No tasks yet. Add one above!
                </p>
              )}

              {todos.map(todo => (
                <div 
                  key={todo.id}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: 14,
                    padding: '16px 20px',
                    background: '#fafafa',
                    borderRadius: 12,
                    border: '1px solid #eee'
                  }}
                >
                  <input
                    type="checkbox"
                    checked={todo.status === 'completed'}
                    onChange={() => toggleComplete(todo)}
                    style={{ width: 20, height: 20, cursor: 'pointer' }}
                  />
                  <span style={{ 
                    flex: 1, 
                    fontSize: 16,
                    textDecoration: todo.status === 'completed' ? 'line-through' : 'none',
                    color: todo.status === 'completed' ? '#888' : '#222'
                  }}>
                    {todo.task}
                  </span>
                  {todo.priority && (
                    <span style={{
                      fontSize: 12,
                      padding: '3px 10px',
                      background: '#f0f0f0',
                      borderRadius: 20,
                      color: '#555'
                    }}>
                      {todo.priority}
                    </span>
                  )}
                </div>
              ))}
            </div>

            <div style={{ marginTop: 32, textAlign: 'center' }}>
              <button 
                onClick={() => { localStorage.removeItem('user'); window.location.reload(); }}
                style={{ color: '#666', background: 'none', border: 'none', cursor: 'pointer' }}
              >
                Sign out
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default TodoApp;
