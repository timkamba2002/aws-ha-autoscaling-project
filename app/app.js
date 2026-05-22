require('dotenv').config();
const express = require('express');
const mysql = require('mysql2/promise');

const app = express();

const pool = mysql.createPool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

// Health check (required for ALB)
app.get('/health', (req, res) => {
  res.status(200).send('OK');
});

// Home page
app.get('/', (req, res) => {
  res.send(`
    <h1>✅ 3-Tier Web App Running on AWS!</h1>
    <p>Auto Scaling Group + ALB + RDS</p>
    <a href="/db-test">Test RDS Connection →</a>
  `);
});

// Test RDS connection
app.get('/db-test', async (req, res) => {
  try {
    const [rows] = await pool.execute('SELECT NOW() as time');
    res.json({ 
      status: 'success', 
      message: 'Connected to RDS MySQL!',
      serverTime: rows[0].time 
    });
  } catch (error) {
    res.status(500).json({ status: 'error', message: error.message });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
});
