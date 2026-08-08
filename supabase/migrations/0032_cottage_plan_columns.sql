-- Groundwork for a future subscription plan - unused/unenforced for now
-- (the app stays fully free), but present so billing work later is
-- additive rather than a retrofit.
-- Run after 0001-0031. Safe to re-run.

alter table cottages add column if not exists plan text not null default 'free';
alter table cottages add column if not exists subscription_status text not null default 'active';
