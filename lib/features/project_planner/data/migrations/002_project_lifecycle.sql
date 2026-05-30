-- Chronyx — Project Planner: Lifecycle Migration (002)
-- Run in Supabase SQL Editor AFTER 001_create_projects.sql.
-- Idempotent: safe to run more than once. Preserves all existing rows.
--
-- Adds the full project lifecycle: statuses (draft/paused/deleted),
-- progress counters, lifecycle timestamps, soft-delete, task completion
-- mirror + actual minutes, and a forward-compatible blueprint version table.

-- ============================================================
-- 1. PROJECTS — lifecycle + progress columns (additive, guarded)
-- ============================================================
ALTER TABLE projects ADD COLUMN IF NOT EXISTS started_at              timestamptz;
ALTER TABLE projects ADD COLUMN IF NOT EXISTS completed_at            timestamptz;
ALTER TABLE projects ADD COLUMN IF NOT EXISTS paused_at               timestamptz;
ALTER TABLE projects ADD COLUMN IF NOT EXISTS archived_at             timestamptz;
ALTER TABLE projects ADD COLUMN IF NOT EXISTS deleted_at              timestamptz;
ALTER TABLE projects ADD COLUMN IF NOT EXISTS last_active_at          timestamptz;
ALTER TABLE projects ADD COLUMN IF NOT EXISTS completion_percentage   integer NOT NULL DEFAULT 0;
ALTER TABLE projects ADD COLUMN IF NOT EXISTS completed_days          integer NOT NULL DEFAULT 0;
ALTER TABLE projects ADD COLUMN IF NOT EXISTS completed_tasks         integer NOT NULL DEFAULT 0;
ALTER TABLE projects ADD COLUMN IF NOT EXISTS estimated_total_minutes integer NOT NULL DEFAULT 0;
ALTER TABLE projects ADD COLUMN IF NOT EXISTS actual_minutes_spent    integer NOT NULL DEFAULT 0;
ALTER TABLE projects ADD COLUMN IF NOT EXISTS streak_days             integer NOT NULL DEFAULT 0;
ALTER TABLE projects ADD COLUMN IF NOT EXISTS is_deleted              boolean NOT NULL DEFAULT false;

-- ============================================================
-- 2. PROJECTS — widen status CHECK (must run BEFORE any new-status write)
-- ============================================================
ALTER TABLE projects DROP CONSTRAINT IF EXISTS projects_status_check;
ALTER TABLE projects ADD CONSTRAINT projects_status_check
  CHECK (status IN ('draft', 'active', 'paused', 'completed', 'archived', 'deleted'));

-- New projects default to 'draft'. Existing rows keep their stored status
-- (this only affects rows inserted without an explicit status).
ALTER TABLE projects ALTER COLUMN status SET DEFAULT 'draft';

-- ============================================================
-- 3. PROJECT_TASKS — completion mirror + actual minutes
--    (completed_at and sort_order already exist in 001; guarded anyway)
-- ============================================================
ALTER TABLE project_tasks ADD COLUMN IF NOT EXISTS is_completed   boolean NOT NULL DEFAULT false;
ALTER TABLE project_tasks ADD COLUMN IF NOT EXISTS actual_minutes integer NOT NULL DEFAULT 0;
ALTER TABLE project_tasks ADD COLUMN IF NOT EXISTS completed_at   timestamptz;
ALTER TABLE project_tasks ADD COLUMN IF NOT EXISTS sort_order     integer NOT NULL DEFAULT 0;

-- Backfill is_completed from existing status (one-time, safe to re-run)
UPDATE project_tasks
   SET is_completed = true
 WHERE status = 'completed' AND is_completed = false;

-- ============================================================
-- 4. INDEXES — fast active-list queries, exclude soft-deleted
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_projects_user_not_deleted
  ON projects (user_id, status)
  WHERE is_deleted = false;

-- ============================================================
-- 5. BLUEPRINT VERSIONS — forward-compatible (planned, not yet wired in app)
--    project -> v1 -> v2 -> v3, with one is_current = true at a time.
--    projects.parsed_blueprint remains the live source of truth (cache of current).
-- ============================================================
CREATE TABLE IF NOT EXISTS project_blueprint_versions (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id             uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  version                integer NOT NULL,
  parsed_blueprint       jsonb NOT NULL,
  raw_blueprint_response text,
  is_current             boolean NOT NULL DEFAULT false,
  created_at             timestamptz NOT NULL DEFAULT now(),
  UNIQUE (project_id, version)
);

CREATE INDEX IF NOT EXISTS idx_blueprint_versions_project
  ON project_blueprint_versions (project_id, version DESC);

-- Only one current version per project.
CREATE UNIQUE INDEX IF NOT EXISTS uq_blueprint_versions_current
  ON project_blueprint_versions (project_id)
  WHERE is_current = true;

ALTER TABLE project_blueprint_versions ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'project_blueprint_versions'
      AND policyname = 'Users manage versions of own projects'
  ) THEN
    CREATE POLICY "Users manage versions of own projects"
      ON project_blueprint_versions FOR ALL
      USING (
        EXISTS (
          SELECT 1 FROM projects
          WHERE projects.id = project_blueprint_versions.project_id
            AND projects.user_id = auth.uid()
        )
      )
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM projects
          WHERE projects.id = project_blueprint_versions.project_id
            AND projects.user_id = auth.uid()
        )
      );
  END IF;
END $$;
