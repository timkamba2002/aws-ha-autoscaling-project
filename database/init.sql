-- PostgreSQL DDL for Tasks table (3-tier To-Do App)
-- Run this manually against your RDS Postgres instance, or use in user-data / migration script.

-- Enable UUID extension (required for gen_random_uuid())
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Main tasks table
CREATE TABLE IF NOT EXISTS tasks (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         VARCHAR(128) NOT NULL,                    -- Firebase/Google user id or custom auth id
    title           VARCHAR(255) NOT NULL,
    description     TEXT,
    status          VARCHAR(20) NOT NULL DEFAULT 'pending' 
                    CHECK (status IN ('pending', 'in_progress', 'completed')),
    priority        VARCHAR(10) NOT NULL DEFAULT 'Medium' 
                    CHECK (priority IN ('Low', 'Medium', 'High')),
    due_date        TIMESTAMP WITH TIME ZONE,
    created_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_tasks_user_id ON tasks(user_id);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_priority ON tasks(priority);
CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON tasks(due_date);
CREATE INDEX IF NOT EXISTS idx_tasks_user_status ON tasks(user_id, status);
CREATE INDEX IF NOT EXISTS idx_tasks_created_at ON tasks(created_at DESC);

-- Trigger to auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_tasks_updated_at ON tasks;
CREATE TRIGGER update_tasks_updated_at
    BEFORE UPDATE ON tasks
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Optional: seed some example data for demo (remove in prod)
-- INSERT INTO tasks (user_id, title, description, status, priority, due_date) VALUES
-- ('demo-user-123', 'Finish Terraform state repair', 'Import all existing resources', 'in_progress', 'High', NOW() + INTERVAL '1 day'),
-- ('demo-user-123', 'Connect React to real backend', 'Call /api/tasks from TodoApp', 'pending', 'High', NOW() + INTERVAL '2 days');
