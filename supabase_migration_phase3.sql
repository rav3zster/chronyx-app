-- ============================================================
-- Chronyx Phase 3 Migration — Focus System columns
-- Run this in your Supabase SQL editor
-- ============================================================

-- Add new columns to time_logs (safe to run multiple times)
ALTER TABLE time_logs
  ADD COLUMN IF NOT EXISTS tags         TEXT[]    DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS interruptions INT      DEFAULT 0,
  ADD COLUMN IF NOT EXISTS energy_level  TEXT     DEFAULT 'medium',
  ADD COLUMN IF NOT EXISTS break_duration_minutes INT DEFAULT NULL;

-- Enforce allowed energy_level values
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'time_logs_energy_level_check'
  ) THEN
    ALTER TABLE time_logs
      ADD CONSTRAINT time_logs_energy_level_check
        CHECK (energy_level IN ('low', 'medium', 'high'));
  END IF;
END $$;

-- Index for tag searches
CREATE INDEX IF NOT EXISTS idx_time_logs_tags ON time_logs USING GIN (tags);

-- Ensure session_mode allows 'custom'
-- (If you have a CHECK constraint, drop and recreate it)
ALTER TABLE time_logs DROP CONSTRAINT IF EXISTS time_logs_session_mode_check;
ALTER TABLE time_logs
  ADD CONSTRAINT time_logs_session_mode_check
    CHECK (session_mode IN ('stopwatch','timer','pomodoro','custom'));
