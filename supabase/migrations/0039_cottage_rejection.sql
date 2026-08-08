-- Platform admins need to be able to reject a pending Cottage, not just
-- approve it (0036_cottage_approval.sql only added 'pending'/'approved').
-- Run after 0036. Safe to re-run.

alter table cottages add column if not exists rejected_at timestamptz;
alter table cottages add column if not exists rejected_reason text;

do $$
begin
  if exists (
    select 1 from pg_constraint where conname = 'cottages_status_check'
  ) then
    alter table cottages drop constraint cottages_status_check;
  end if;

  alter table cottages add constraint cottages_status_check check (status in ('pending', 'approved', 'rejected'));
end $$;
