-- =============================================================================
-- MIGRATION: reliable, analytics-ready & timer/pause-capable database schema
-- Run this script in the Supabase SQL Editor:
-- https://supabase.com/dashboard/project/evrafznbrlhovoffsbvr/sql/new
-- =============================================================================

ALTER TABLE time_logs 
  ADD COLUMN IF NOT EXISTS session_mode TEXT NOT NULL DEFAULT 'stopwatch',
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'completed',
  ADD COLUMN IF NOT EXISTS elapsed_seconds INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS duration_minutes INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS target_duration_minutes INTEGER,
  ADD COLUMN IF NOT EXISTS completion_percentage NUMERIC DEFAULT 0.0,
  ADD COLUMN IF NOT EXISTS paused_duration_seconds INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS paused_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS notes TEXT,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- Ensure created_at exists (defaults to now())
ALTER TABLE time_logs
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();

-- Update status and session_mode for legacy rows
UPDATE time_logs 
SET status = 'completed' 
WHERE end_time IS NOT NULL AND (status IS NULL OR status = 'completed');

UPDATE time_logs 
SET status = 'active' 
WHERE end_time IS NULL AND (status IS NULL OR status = 'active');

-- Apply check constraints to restrict enums if not already present
ALTER TABLE time_logs 
  DROP CONSTRAINT IF EXISTS chk_time_logs_status_v3;
ALTER TABLE time_logs 
  ADD CONSTRAINT chk_time_logs_status_v3 
  CHECK (status IN ('active', 'paused', 'completed', 'cancelled'));

ALTER TABLE time_logs 
  DROP CONSTRAINT IF EXISTS chk_time_logs_session_mode_v3;
ALTER TABLE time_logs 
  ADD CONSTRAINT chk_time_logs_session_mode_v3 
  CHECK (session_mode IN ('stopwatch', 'timer', 'pomodoro'));
