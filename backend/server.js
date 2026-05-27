const express = require('express');
const mysql = require('mysql2');
const cors = require('cors');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 3000;

// MySQL Connection (using RDS)
const db = mysql.createConnection({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME
});

db.connect(err => {
  if (err) {
    console.error('Database connection failed:', err);
  } else {
    console.log('✅ Connected to RDS MySQL');
  }
});

// Create table if not exists
db.query(`
  CREATE TABLE IF NOT EXISTS todos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    task TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  )
`);

// Get todos for user
app.get('/api/todos', (req, res) => {
  const userId = req.query.userId;
  db.query('SELECT * FROM todos WHERE user_id = ? ORDER BY created_at DESC', [userId], (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(results);
  });
});

// Add new todo
app.post('/api/todos', (req, res) => {
  const { userId, task } = req.body;
  db.query('INSERT INTO todos (user_id, task) VALUES (?, ?)', [userId, task], (err) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ message: 'Task added' });
  });
});

// Delete todo
app.delete('/api/todos/:id', (req, res) => {
  const { id } = req.params;
  db.query('DELETE FROM todos WHERE id = ?', [id], (err) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ message: 'Task deleted' });
  });
});

app.listen(PORT, () => {
  console.log(`Backend running on port ${PORT}`);
});
