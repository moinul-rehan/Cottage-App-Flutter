-- Lets a cottage's own super admin transfer ownership to another member,
-- and request/cancel a 7-day-delayed self-deletion of the whole cottage.
-- Cascading deletes for the actual deletion already exist from migration
-- 0033. deletion_notice_id lets the cancel flow reliably find and archive
-- the specific critical notice the request flow posted.
--
-- Run after 0001-0034. Safe to re-run.

alter table cottages add column if not exists deletion_requested_at timestamptz;
alter table cottages add column if not exists deletion_requested_by uuid references profiles(id);
alter table cottages add column if not exists deletion_notice_id uuid references notices(id);
