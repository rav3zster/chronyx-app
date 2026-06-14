-- =============================================================================
-- MIGRATION: Dedicated To-Do System table setup with nested subtasks and recurrence
-- Run this script in the Supabase SQL Editor:
-- https://supabase.com/dashboard/project/evrafznbrlhovoffsbvr/sql/new
-- =============================================================================

CREATE TABLE IF NOT EXISTS todos (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title               text NOT NULL,
  notes               text,
  status              text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed', 'archived')),
  priority            text NOT NULL DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'critical')),
  category            text,
  due_date            timestamptz,
  reminder_time       timestamptz,
  estimated_minutes   integer DEFAULT 0 CHECK (estimated_minutes >= 0),
  project_id          uuid REFERENCES projects(id) ON DELETE SET NULL,
  goal_id             uuid, -- Reference to goals if goals are present in auth/app
  habit_id            uuid, -- Reference to habits if habits are present in auth/app
  recurrence          text CHECK (recurrence IN ('daily', 'weekly', 'monthly', 'custom')),
  parent_id           uuid REFERENCES todos(id) ON DELETE CASCADE, -- Self-reference for subtasks
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  completed_at        timestamptz
);

-- Indices for performance
CREATE INDEX IF NOT EXISTS idx_todos_user_id ON todos (user_id);
CREATE INDEX IF NOT EXISTS idx_todos_user_status ON todos (user_id, status);
CREATE INDEX IF NOT EXISTS idx_todos_project_id ON todos (project_id);
CREATE INDEX IF NOT EXISTS idx_todos_parent_id ON todos (parent_id);

-- Enable RLS
ALTER TABLE todos ENABLE ROW LEVEL SECURITY;

-- Policies for RLS
CREATE POLICY "Users can view own todos"
  ON todos FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own todos"
  ON todos FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own todos"
  ON todos FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own todos"
  ON todos FOR DELETE
  USING (auth.uid() = user_id);

-- Trigger for updated_at column
CREATE OR REPLACE FUNCTION update_todos_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_todos_updated_at
  BEFORE UPDATE ON todos
  FOR EACH ROW
  EXECUTE FUNCTION update_todos_updated_at();
