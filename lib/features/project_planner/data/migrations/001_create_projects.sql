-- Chronyx — Project Planner: Database Migration
-- Run in Supabase SQL Editor:
-- https://supabase.com/dashboard/project/evrafznbrlhovoffsbvr/sql/new

-- ============================================================
-- 1. PROJECTS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS projects (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title         text NOT NULL,
  goal_description text NOT NULL,
  template      text NOT NULL,
  duration_days integer NOT NULL CHECK (duration_days >= 7 AND duration_days <= 365),
  difficulty    text NOT NULL CHECK (difficulty IN ('easy', 'medium', 'hard', 'expert')),
  daily_time_minutes integer NOT NULL CHECK (daily_time_minutes >= 30 AND daily_time_minutes <= 480),
  generated_prompt text,
  raw_blueprint_response text,
  parsed_blueprint jsonb,
  status        text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'archived')),
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

-- Index for user lookups
CREATE INDEX IF NOT EXISTS idx_projects_user_id ON projects (user_id);
CREATE INDEX IF NOT EXISTS idx_projects_user_status ON projects (user_id, status);

-- RLS
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own projects"
  ON projects FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own projects"
  ON projects FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own projects"
  ON projects FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own projects"
  ON projects FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================
-- 2. PROJECT_TASKS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS project_tasks (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id       uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  day_number       integer NOT NULL,
  title            text NOT NULL,
  description      text NOT NULL DEFAULT '',
  sort_order       integer NOT NULL DEFAULT 0,
  estimated_minutes integer,
  todos            jsonb DEFAULT '[]'::jsonb,
  status           text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed', 'skipped')),
  created_at       timestamptz NOT NULL DEFAULT now(),
  completed_at     timestamptz
);

-- Index for project task lookups (ordered by day, then sort)
CREATE INDEX IF NOT EXISTS idx_project_tasks_project_id ON project_tasks (project_id);
CREATE INDEX IF NOT EXISTS idx_project_tasks_project_day ON project_tasks (project_id, day_number, sort_order);

-- RLS (access through project ownership)
ALTER TABLE project_tasks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view tasks of own projects"
  ON project_tasks FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM projects
      WHERE projects.id = project_tasks.project_id
        AND projects.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert tasks to own projects"
  ON project_tasks FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM projects
      WHERE projects.id = project_tasks.project_id
        AND projects.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update tasks of own projects"
  ON project_tasks FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM projects
      WHERE projects.id = project_tasks.project_id
        AND projects.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete tasks of own projects"
  ON project_tasks FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM projects
      WHERE projects.id = project_tasks.project_id
        AND projects.user_id = auth.uid()
    )
  );

-- ============================================================
-- 3. ADD project_id FK TO goals TABLE (optional link)
-- ============================================================
ALTER TABLE goals
ADD COLUMN IF NOT EXISTS project_id uuid REFERENCES projects(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_goals_project_id ON goals (project_id);

-- ============================================================
-- 4. ADD project_task_id FK TO time_logs TABLE (optional link)
-- ============================================================
ALTER TABLE time_logs
ADD COLUMN IF NOT EXISTS project_task_id uuid REFERENCES project_tasks(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_time_logs_project_task_id ON time_logs (project_task_id);

-- ============================================================
-- 5. updated_at TRIGGER (auto-update on row change)
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER projects_updated_at
  BEFORE UPDATE ON projects
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
