-- ============================================================
-- MIGRATION: analytics-ready columns + category expansion
-- Run this in Supabase SQL Editor AFTER supabase_fix_fk.sql
-- ============================================================

-- 1. Add duration_minutes column if it does not exist.
ALTER TABLE time_logs
  ADD COLUMN IF NOT EXISTS duration_minutes integer;

-- 2. Backfill duration_minutes for all existing finished sessions
--    that are missing it.
UPDATE time_logs
SET duration_minutes = GREATEST(
  0,
  EXTRACT(EPOCH FROM (end_time - start_time)) / 60
)::integer
WHERE end_time IS NOT NULL
  AND duration_minutes IS NULL;

-- 3. Add check constraint to prevent negative durations on new rows.
ALTER TABLE time_logs
  DROP CONSTRAINT IF EXISTS chk_duration_non_negative;
ALTER TABLE time_logs
  ADD CONSTRAINT chk_duration_non_negative
  CHECK (duration_minutes IS NULL OR duration_minutes >= 0);

-- 4. Expand the category column to allow the new values.
--    If category is stored as an enum type, add the new values.
--    If it is a plain text column this is a no-op.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_type WHERE typname = 'task_category'
  ) THEN
    -- Add new enum values (Postgres allows adding, not removing).
    ALTER TYPE task_category ADD VALUE IF NOT EXISTS 'meeting';
    ALTER TYPE task_category ADD VALUE IF NOT EXISTS 'exercise';
    ALTER TYPE task_category ADD VALUE IF NOT EXISTS 'entertainment';
  END IF;
END $$;

-- 5. Verify the schema looks correct.
-- SELECT column_name, data_type, is_nullable
-- FROM information_schema.columns
-- WHERE table_name = 'time_logs'
-- ORDER BY ordinal_position;
