-- =============================================================================
-- MIGRATION: Premium To-Do Enhancements (v5)
-- Run this script in the Supabase SQL Editor:
-- https://supabase.com/dashboard/project/evrafznbrlhovoffsbvr/sql/new
-- =============================================================================

-- 1. Alter todos table to add premium fields
ALTER TABLE todos
  ADD COLUMN IF NOT EXISTS energy_level TEXT CHECK (energy_level IN ('low', 'medium', 'high')),
  ADD COLUMN IF NOT EXISTS tags TEXT[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS reminder_times TIMESTAMPTZ[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS blocked_by_ids UUID[] NOT NULL DEFAULT '{}';

-- 2. Create todo_attachments table for attachments support
CREATE TABLE IF NOT EXISTS todo_attachments (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  todo_id     UUID NOT NULL REFERENCES todos(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  url         TEXT NOT NULL,
  type        TEXT NOT NULL CHECK (type IN ('image', 'pdf', 'voice', 'file')),
  size_bytes  INTEGER,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indices for performance
CREATE INDEX IF NOT EXISTS idx_todo_attachments_todo_id ON todo_attachments (todo_id);

-- 3. Enable Row Level Security (RLS) on todo_attachments
ALTER TABLE todo_attachments ENABLE ROW LEVEL SECURITY;

-- 4. Create proper RLS policies for todo_attachments (access is governed by parent todo ownership)
DROP POLICY IF EXISTS "Users can view attachments of own todos" ON todo_attachments;
CREATE POLICY "Users can view attachments of own todos"
  ON todo_attachments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM todos
      WHERE todos.id = todo_attachments.todo_id
        AND todos.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can insert attachments to own todos" ON todo_attachments;
CREATE POLICY "Users can insert attachments to own todos"
  ON todo_attachments FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM todos
      WHERE todos.id = todo_attachments.todo_id
        AND todos.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can update attachments of own todos" ON todo_attachments;
CREATE POLICY "Users can update attachments of own todos"
  ON todo_attachments FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM todos
      WHERE todos.id = todo_attachments.todo_id
        AND todos.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM todos
      WHERE todos.id = todo_attachments.todo_id
        AND todos.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can delete attachments of own todos" ON todo_attachments;
CREATE POLICY "Users can delete attachments of own todos"
  ON todo_attachments FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM todos
      WHERE todos.id = todo_attachments.todo_id
        AND todos.user_id = auth.uid()
    )
  );

-- 5. Re-verify/re-apply RLS policies on the main todos table in case they were not set up correctly
ALTER TABLE todos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own todos" ON todos;
CREATE POLICY "Users can view own todos"
  ON todos FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own todos" ON todos;
CREATE POLICY "Users can insert own todos"
  ON todos FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own todos" ON todos;
CREATE POLICY "Users can update own todos"
  ON todos FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own todos" ON todos;
CREATE POLICY "Users can delete own todos"
  ON todos FOR DELETE
  USING (auth.uid() = user_id);

-- 6. Grant explicit table-level permissions to Supabase API roles
GRANT ALL ON public.todos TO anon, authenticated, service_role;
GRANT ALL ON public.todo_attachments TO anon, authenticated, service_role;

-- 7. Notify Postgrest to reload the schema cache
NOTIFY pgrst, 'reload schema';
