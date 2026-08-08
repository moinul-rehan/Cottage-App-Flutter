-- Bug: migration 0007 made cottages.active_month_key NOT NULL, but neither
-- cottage-creation path (handle_new_user()'s "create_cottage" branch, used
-- by email/password signup, nor create_cottage_for_current_user(), used by
-- Google OAuth signup) sets it — both insert into cottages with only
-- (name, created_by). Every new signup since 0007 has been failing with
-- "null value in column active_month_key violates not-null constraint".
--
-- Fix with a column default instead of patching each insert site, so any
-- current or future cottage-creation path is safe automatically.
-- Run after 0001-0020. Safe to re-run.

alter table cottages alter column active_month_key set default to_char(now(), 'YYYY-MM');
