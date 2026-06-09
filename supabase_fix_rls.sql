-- ============================================================
-- Chronyx — time_logs RLS Fix + Column Patch
-- Run in Supabase SQL Editor:
-- https://supabase.com/dashboard/project/evrafznbrlhovoffsbvr/sql/new
-- ============================================================

-- ── Step 1: Ensure all required columns exist ─────────────────────────────────

ALTER TABLE time_logs
  ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'other';

ALTER TABLE time_logs
  ADD COLUMN IF NOT EXISTS project_task_id UUID REFERENCES project_tasks(id) ON DELETE SET NULL;

-- ── Step 2: Enable RLS on time_logs (safe to run even if already enabled) ─────

ALTER TABLE time_logs ENABLE ROW LEVEL SECURITY;

-- ── Step 3: Drop any stale/conflicting policies before recreating ─────────────

DROP POLICY IF EXISTS "Users can view own time logs" ON time_logs;
DROP POLICY IF EXISTS "Users can insert own time logs" ON time_logs;
DROP POLICY IF EXISTS "Users can update own time logs" ON time_logs;
DROP POLICY IF EXISTS "Users can delete own time logs" ON time_logs;

-- (Also drop common variant names)
DROP POLICY IF EXISTS "Enable read access for users" ON time_logs;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON time_logs;
DROP POLICY IF EXISTS "Users can manage their own time logs" ON time_logs;

-- ── Step 4: Create proper RLS policies ───────────────────────────────────────

CREATE POLICY "Users can view own time logs"
  ON time_logs FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own time logs"
  ON time_logs FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own time logs"
  ON time_logs FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own time logs"
  ON time_logs FOR DELETE
  USING (auth.uid() = user_id);

-- ── Step 5: Indexes for performance ──────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_time_logs_user_id
  ON time_logs (user_id);

CREATE INDEX IF NOT EXISTS idx_time_logs_user_category
  ON time_logs (user_id, category);

CREATE INDEX IF NOT EXISTS idx_time_logs_start_time
  ON time_logs (user_id, start_time DESC);

-- ── Step 6: Check constraint on category (safe to re-add) ────────────────────

-- Drop first so we can recreate safely
ALTER TABLE time_logs
  DROP CONSTRAINT IF EXISTS time_logs_category_check;

ALTER TABLE time_logs
  ADD CONSTRAINT time_logs_category_check
  CHECK (category IN ('productive', 'learning', 'break', 'distraction', 'other'));

-- ── Verification query (run after to confirm) ─────────────────────────────────
-- SELECT schemaname, tablename, policyname, cmd, qual
-- FROM pg_policies
-- WHERE tablename = 'time_logs';
