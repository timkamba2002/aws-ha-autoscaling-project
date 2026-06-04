require('dotenv').config();
const express = require('express');
const cors = require('cors');
const mysql = require('mysql2/promise');
const winston = require('winston');

const app = express();
const PORT = process.env.PORT || 3000;

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [new winston.transports.Console()]
});

const pool = mysql.createPool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT ? parseInt(process.env.DB_PORT, 10) : 3306,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: 'myappdb',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

app.use(cors());
app.use(express.json());

app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'healthy', db: 'connected' });
  } catch (e) {
    res.status(503).json({ status: 'unhealthy' });
  }
});

app.get('/api/tasks', async (req, res) => {
  const { userId } = req.query;
  if (!userId) return res.status(400).json({ error: 'userId required' });

  try {
    const [rows] = await pool.query(
      'SELECT * FROM tasks WHERE user_id = ? ORDER BY created_at DESC',
      [userId]
    );
    res.json(rows);
  } catch (e) {
    logger.error('Failed to fetch tasks', { error: e.message });
    res.status(500).json({ error: 'Failed to fetch tasks' });
  }
});

app.post('/api/tasks', async (req, res) => {
  const { userId, title, description, priority } = req.body;
  if (!userId || !title) return res.status(400).json({ error: 'userId and title required' });

  try {
    const [result] = await pool.query(
      'INSERT INTO tasks (user_id, task, description, priority) VALUES (?, ?, ?, ?)',
      [userId, title, description || null, priority || 'Medium']
    );
    res.status(201).json({ id: result.insertId, userId, task: title, status: 'pending' });
  } catch (e) {
    logger.error('Failed to create task', { error: e.message });
    res.status(500).json({ error: 'Failed to create task' });
  }
});

app.put('/api/tasks/:id', async (req, res) => {
  const { id } = req.params;
  const { userId, title, description, status, priority } = req.body;

  try {
    const fields = [];
    const values = [];

    if (title !== undefined) { fields.push('task = ?'); values.push(title); }
    if (description !== undefined) { fields.push('description = ?'); values.push(description); }
    if (status !== undefined) { fields.push('status = ?'); values.push(status); }
    if (priority !== undefined) { fields.push('priority = ?'); values.push(priority); }

    if (fields.length === 0) return res.status(400).json({ error: 'No fields to update' });

    values.push(id, userId);

    const [result] = await pool.query(
      `UPDATE tasks SET ${fields.join(', ')} WHERE id = ? AND user_id = ?`,
      values
    );

    if (result.affectedRows === 0) return res.status(404).json({ error: 'Task not found' });
    res.json({ success: true });
  } catch (e) {
    logger.error('Failed to update task', { error: e.message });
    res.status(500).json({ error: 'Failed to update task' });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  logger.info(`Backend running on port ${PORT}`);
});
