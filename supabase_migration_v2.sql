-- =============================================================================
-- MIGRATION: Robust, analytics-ready & future-proof time tracking schema
-- Run this script in the Supabase SQL Editor:
-- https://supabase.com/dashboard/project/evrafznbrlhovoffsbvr/sql/new
-- =============================================================================

-- 1. Add session status, mode, and timer-related fields
ALTER TABLE time_logs 
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'completed',
  ADD COLUMN IF NOT EXISTS mode TEXT NOT NULL DEFAULT 'stopwatch',
  ADD COLUMN IF NOT EXISTS target_duration_minutes INTEGER;

-- 2. Add future-proofing fields (pause/resume support, AI insights, goals tracking)
ALTER TABLE time_logs
  ADD COLUMN IF NOT EXISTS paused_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS ai_insights TEXT,
  ADD COLUMN IF NOT EXISTS goal_id UUID REFERENCES goals(id) ON DELETE SET NULL;

-- 3. Set status = 'active' for existing running sessions (where end_time is NULL)
UPDATE time_logs 
SET status = 'active' 
WHERE end_time IS NULL;

-- 4. Apply check constraints to restrict to valid enums
ALTER TABLE time_logs 
  DROP CONSTRAINT IF EXISTS chk_time_logs_status;
ALTER TABLE time_logs 
  ADD CONSTRAINT chk_time_logs_status 
  CHECK (status IN ('active', 'completed', 'cancelled', 'paused'));

ALTER TABLE time_logs 
  DROP CONSTRAINT IF EXISTS chk_time_logs_mode;
ALTER TABLE time_logs 
  ADD CONSTRAINT chk_time_logs_mode 
  CHECK (mode IN ('stopwatch', 'timer'));

-- 5. Create index for faster querying by status & mode for analytics
CREATE INDEX IF NOT EXISTS idx_time_logs_status_mode 
  ON time_logs (user_id, status, mode);
