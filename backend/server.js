require('dotenv').config();
const express = require('express');
const cors = require('cors');
const mysql = require('mysql2/promise');
const winston = require('winston');
const promClient = require('prom-client');

const app = express();
const PORT = process.env.PORT || 3000;

// ==================== PROMETHEUS METRICS (for Grafana + learning) ====================
// Best practice: use a Registry (default is fine), enable default process + heap metrics.
const register = new promClient.Registry();
promClient.collectDefaultMetrics({ register, prefix: 'ha_backend_' });

// Custom business + technical metrics tailored to this To-Do HA project.
// These give you SLIs for the API, DB, and help observe Fargate Spot behavior + refreshes.
const httpRequestDuration = new promClient.Histogram({
  name: 'ha_backend_http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.005, 0.01, 0.05, 0.1, 0.5, 1, 2, 5],
  registers: [register]
});

const httpRequestsTotal = new promClient.Counter({
  name: 'ha_backend_http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register]
});

const tasksCreatedTotal = new promClient.Counter({
  name: 'ha_backend_tasks_created_total',
  help: 'Total tasks created (business metric)',
  registers: [register]
});

const tasksFetchedTotal = new promClient.Counter({
  name: 'ha_backend_tasks_fetched_total',
  help: 'Total task list fetches (business metric)',
  registers: [register]
});

const dbQueryDuration = new promClient.Histogram({
  name: 'ha_backend_db_query_duration_seconds',
  help: 'Duration of DB queries (SELECT/INSERT/UPDATE) in seconds',
  labelNames: ['operation'],
  buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1],
  registers: [register]
});

const dbErrorsTotal = new promClient.Counter({
  name: 'ha_backend_db_errors_total',
  help: 'Total DB errors (connection/query failures)',
  labelNames: ['operation'],
  registers: [register]
});

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

// Helper to time DB queries and record metrics
async function timedQuery(operation, sql, params) {
  const end = dbQueryDuration.startTimer({ operation });
  try {
    const result = await pool.query(sql, params);
    end();
    return result;
  } catch (e) {
    dbErrorsTotal.inc({ operation });
    end();
    throw e;
  }
}

app.use(cors());
app.use(express.json());

// Prometheus middleware: record every request (duration + count)
app.use((req, res, next) => {
  const end = httpRequestDuration.startTimer({
    method: req.method,
    route: req.route ? req.route.path : req.path
  });
  res.on('finish', () => {
    const labels = {
      method: req.method,
      route: req.route ? req.route.path : req.path,
      status_code: res.statusCode
    };
    end(labels);
    httpRequestsTotal.inc(labels);
  });
  next();
});

app.get('/health', async (req, res) => {
  try {
    await timedQuery('health', 'SELECT 1');
    res.json({ status: 'healthy', db: 'connected' });
  } catch (e) {
    res.status(503).json({ status: 'unhealthy' });
  }
});

// Dedicated /metrics for Prometheus scrape (text/plain; version=0.0.4)
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

app.get('/api/tasks', async (req, res) => {
  const { userId } = req.query;
  if (!userId) return res.status(400).json({ error: 'userId required' });

  try {
    const [rows] = await timedQuery('select_tasks',
      'SELECT * FROM tasks WHERE user_id = ? ORDER BY created_at DESC',
      [userId]
    );
    tasksFetchedTotal.inc();
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
    const [result] = await timedQuery('insert_task',
      'INSERT INTO tasks (user_id, task, description, priority) VALUES (?, ?, ?, ?)',
      [userId, title, description || null, priority || 'Medium']
    );
    tasksCreatedTotal.inc();
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

    const [result] = await timedQuery('update_task',
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
