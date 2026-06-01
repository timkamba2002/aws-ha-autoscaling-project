-- MySQL 8.0 DDL for Tasks table (3-tier To-Do App)
-- This matches the Node.js backend (mysql2) expectations

CREATE DATABASE IF NOT EXISTS myappdb;
USE myappdb;

-- Main tasks table
CREATE TABLE IF NOT EXISTS tasks (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    user_id         VARCHAR(128) NOT NULL,
    task            VARCHAR(255) NOT NULL,
    description     TEXT,
    status          VARCHAR(20) NOT NULL DEFAULT 'pending' 
                    CHECK (status IN ('pending', 'in_progress', 'completed')),
    priority        VARCHAR(10) NOT NULL DEFAULT 'Medium' 
                    CHECK (priority IN ('Low', 'Medium', 'High')),
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Indexes for common queries
CREATE INDEX idx_tasks_user_id ON tasks(user_id);
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_priority ON tasks(priority);
CREATE INDEX idx_tasks_user_status ON tasks(user_id, status);
CREATE INDEX idx_tasks_created_at ON tasks(created_at DESC);

-- Optional: seed some example data for demo (remove in prod)
-- INSERT INTO tasks (user_id, task, description, status, priority) VALUES
-- ('demo-user-123', 'Finish Terraform state repair', 'Import all existing resources', 'in_progress', 'High'),
-- ('demo-user-123', 'Connect React to real backend', 'Call /api/tasks from TodoApp', 'pending', 'High');