require('dotenv').config();
const express = require('express');
const cors = require('cors');
const mysql = require('mysql2/promise');
const winston = require('winston');
const promClient = require('prom-client');

const app = express();
const PORT = process.env.PORT || 3000;

// ==================== PROMETHEUS METRICS ====================
const register = new promClient.Registry();
promClient.collectDefaultMetrics({ register, prefix: 'ha_backend_' });

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
  help: 'Total tasks created',
  registers: [register]
});

const tasksFetchedTotal = new promClient.Counter({
  name: 'ha_backend_tasks_fetched_total',
  help: 'Total task list fetches',
  registers: [register]
});

const dbQueryDuration = new promClient.Histogram({
  name: 'ha_backend_db_query_duration_seconds',
  help: 'Duration of DB queries in seconds',
  labelNames: ['operation'],
  buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1],
  registers: [register]
});

const dbErrorsTotal = new promClient.Counter({
  name: 'ha_backend_db_errors_total',
  help: 'Total DB errors',
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

// Request metrics middleware
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

// ==================== HEALTH CHECKS ====================
// Root route
app.get('/', (req, res) => {
  res.json({ message: 'HA Project Backend is running ✅', version: '1.0' });
});

// Health check (used by ALB + ECS)
app.get('/health', async (req, res) => {
  try {
    await timedQuery('health',