-- ============================================================
-- ROOT CAUSE FIX: time_logs.user_id FK points to public.users
-- instead of auth.users. This causes every INSERT to fail with:
--   code=23503
--   message=insert or update on table "time_logs" violates
--           foreign key constraint "time_logs_user_id_fkey"
--   details=Key is not present in table "users".
--
-- Run this in Supabase SQL Editor:
-- https://supabase.com/dashboard/project/evrafznbrlhovoffsbvr/sql/new
-- ============================================================

-- Step 1: Drop the bad FK constraint
ALTER TABLE time_logs
  DROP CONSTRAINT IF EXISTS time_logs_user_id_fkey;

-- Step 2: Re-add it pointing to auth.users (correct for Supabase)
ALTER TABLE time_logs
  ADD CONSTRAINT time_logs_user_id_fkey
  FOREIGN KEY (user_id)
  REFERENCES auth.users(id)
  ON DELETE CASCADE;

-- Verify: this should show auth.users as the referenced table
-- SELECT tc.constraint_name, ccu.table_schema, ccu.table_name
-- FROM information_schema.table_constraints tc
-- JOIN information_schema.constraint_column_usage ccu
--   ON tc.constraint_name = ccu.constraint_name
-- WHERE tc.table_name = 'time_logs'
--   AND tc.constraint_type = 'FOREIGN KEY';
