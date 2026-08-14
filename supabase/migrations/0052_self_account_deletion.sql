-- Self-service "delete my account" (Settings -> Security), mirroring the
-- Cottage deletion flow in 0009/request-cottage-deletion: a 7-day
-- cancellable grace period rather than an immediate hard delete. Actual
-- removal at the end of the window reuses removeMember's existing safe
-- pattern (removed_at + login ban) instead of a real row delete, since
-- deleting the profiles row would cascade-delete every expense/meal/deposit
-- that references it (see removeMember's comment in members/actions.ts).
-- Run after 0001-0051. Safe to re-run.

alter table profiles
  add column if not exists account_deletion_requested_at timestamptz,
  add column if not exists account_deletion_notice_id uuid references notices(id) on delete set null;
