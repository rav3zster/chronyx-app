-- Chronyx — Required Supabase SQL Migrations
-- Run this in your Supabase SQL Editor: 
-- https://supabase.com/dashboard/project/evrafznbrlhovoffsbvr/sql/new

-- 1. Add category column to time_logs table
--    This enables the productivity category tracking feature.
ALTER TABLE time_logs
ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'other';

-- 2. (Optional) Add an index for faster analytics queries
CREATE INDEX IF NOT EXISTS idx_time_logs_user_category
  ON time_logs (user_id, category);

-- 3. (Optional) Add check constraint to restrict to valid categories
ALTER TABLE time_logs
ADD CONSTRAINT IF NOT EXISTS time_logs_category_check
  CHECK (category IN ('productive', 'learning', 'break', 'distraction', 'other'));
