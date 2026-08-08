-- Default cost templates: admin-configured per-member amounts for utility
-- categories that are the same every month (Internet, Servant, Trash,
-- Filter Kit, etc). One row per cottage+category+member; saving again for
-- the same category+member replaces the previous amount (a template, not a
-- history — unlike rent_assignments/utility_adjustments which are
-- append-only). Used to pre-fill Generate Utility Statement when the admin
-- picks a category that has a default set.
-- Run after 0013. Safe to re-run.

create table if not exists default_costs (
  id uuid primary key default gen_random_uuid(),
  cottage_id uuid not null references cottages(id) on delete cascade,
  category text not null,
  user_id uuid not null references profiles(id) on delete cascade,
  amount numeric(10, 2) not null check (amount >= 0),
  notes text,
  set_by uuid not null references profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (cottage_id, category, user_id)
);

alter table default_costs enable row level security;

create index if not exists default_costs_cottage_category_idx
  on default_costs (cottage_id, category);

drop policy if exists "default_costs_select_own_cottage" on default_costs;
create policy "default_costs_select_own_cottage" on default_costs
  for select to authenticated using (cottage_id = current_cottage_id());

drop policy if exists "default_costs_admin_write" on default_costs;
create policy "default_costs_admin_write" on default_costs
  for insert to authenticated with check (
    is_super_admin() and cottage_id = current_cottage_id() and set_by = auth.uid()
  );

drop policy if exists "default_costs_admin_update" on default_costs;
create policy "default_costs_admin_update" on default_costs
  for update to authenticated using (
    is_super_admin() and cottage_id = current_cottage_id()
  ) with check (
    is_super_admin() and cottage_id = current_cottage_id() and set_by = auth.uid()
  );

drop policy if exists "default_costs_admin_delete" on default_costs;
create policy "default_costs_admin_delete" on default_costs
  for delete to authenticated using (
    is_super_admin() and cottage_id = current_cottage_id()
  );
