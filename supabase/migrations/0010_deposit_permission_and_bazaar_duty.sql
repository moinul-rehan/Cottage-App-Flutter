-- 1) Make "add meal deposit" a grantable per-member permission, same as
--    Utilities/Bazaar/Meals, instead of hardcoded super-admin-only.
-- 2) Bazaar duty assignments: admin assigns a member a shopping date range;
--    that member sees it on their Dashboard. Nobody sees anyone else's.
-- Run after 0001-0009. Safe to re-run.

-- ── profiles: can_add_deposit ────────────────────────────────
alter table profiles add column if not exists can_add_deposit boolean not null default false;

drop policy if exists "deposits_admin_insert" on meal_deposits;
create policy "deposits_admin_insert" on meal_deposits
  for insert to authenticated with check (
    cottage_id = current_cottage_id()
    and (is_super_admin() or (select can_add_deposit from profiles where id = auth.uid()))
    and not is_month_closed(cottage_id, (month_key || '-01')::date)
  );

drop policy if exists "deposits_admin_update" on meal_deposits;
create policy "deposits_admin_update" on meal_deposits
  for update to authenticated using (
    cottage_id = current_cottage_id()
    and (is_super_admin() or (select can_add_deposit from profiles where id = auth.uid()))
    and not is_month_closed(cottage_id, (month_key || '-01')::date)
  );

-- ── bazaar_duties: admin-assigned shopping date ranges ──────
create table if not exists bazaar_duties (
  id uuid primary key default gen_random_uuid(),
  cottage_id uuid not null references cottages(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  start_date date not null,
  end_date date not null,
  note text,
  created_by uuid not null references profiles(id),
  created_at timestamptz not null default now(),
  constraint bazaar_duties_date_order check (end_date >= start_date)
);

alter table bazaar_duties enable row level security;

create index if not exists bazaar_duties_cottage_user_idx on bazaar_duties (cottage_id, user_id, end_date);

drop policy if exists "bazaar_duties_select" on bazaar_duties;
create policy "bazaar_duties_select" on bazaar_duties
  for select to authenticated using (
    cottage_id = current_cottage_id()
    and (is_super_admin() or user_id = auth.uid())
  );

drop policy if exists "bazaar_duties_admin_insert" on bazaar_duties;
create policy "bazaar_duties_admin_insert" on bazaar_duties
  for insert to authenticated with check (
    is_super_admin()
    and cottage_id = current_cottage_id()
    and created_by = auth.uid()
  );

drop policy if exists "bazaar_duties_admin_delete" on bazaar_duties;
create policy "bazaar_duties_admin_delete" on bazaar_duties
  for delete to authenticated using (
    is_super_admin() and cottage_id = current_cottage_id()
  );
