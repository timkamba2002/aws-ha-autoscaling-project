const express = require('express');
const mysql = require('mysql2/promise');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

const pool = mysql.createPool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: 'myappdb'
});

app.get('/health', (req, res) => res.send('OK'));

app.get('/api/todos', async (req, res) => {
  const [rows] = await pool.query('SELECT * FROM todos WHERE user_id = ? ORDER BY created_at DESC', [req.query.userId]);
  res.json(rows);
});

app.post('/api/todos', async (req, res) => {
  const { userId, task } = req.body;
  await pool.query('INSERT INTO todos (user_id, task) VALUES (?, ?)', [userId, task]);
  res.json({ success: true });
});

app.listen(3000, () => console.log('Backend API running on 3000'));
