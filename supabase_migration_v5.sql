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
