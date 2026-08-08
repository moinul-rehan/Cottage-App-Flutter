-- New cottages must be verified by a platform admin before members can use
-- them. Existing cottages are backfilled as already-approved so nobody
-- currently using the app gets locked out. Run after 0001-0035. Safe to re-run.

alter table cottages add column if not exists status text not null default 'pending';
alter table cottages add column if not exists approved_at timestamptz;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'cottages_status_check'
  ) then
    alter table cottages add constraint cottages_status_check check (status in ('pending', 'approved'));
  end if;
end $$;

update cottages set status = 'approved', approved_at = coalesce(approved_at, created_at)
where status = 'pending';
