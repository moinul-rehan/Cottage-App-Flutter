-- Lets platform admin suspend a cottage (blocks every member's login
-- without deleting anything) and reactivate it. plan/subscription_status
-- already exist from 0032.
--
-- Run after 0001-0033. Safe to re-run.

alter table cottages add column if not exists suspended_at timestamptz;
alter table cottages add column if not exists suspended_reason text;
