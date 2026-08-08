-- Three independent additions:
--
-- 1. profiles.removed_at: an admin can permanently remove an already
--    deactivated member from the cottage roster. The profiles row itself
--    (and every historical record that references it) is never deleted —
--    only hidden from the Members list — so past expenses, meals, deposits
--    and statements stay fully intact and attributable.
--
-- 2. contacts: a simple cottage-wide address book (necessary people, not
--    members) admins can add/remove; every member can view it read-only.
--
-- 3. "gas" added to the expenses category check constraint, alongside the
--    existing categories.
--
-- Run after 0018. Safe to re-run.

alter table profiles add column if not exists removed_at timestamptz;

alter table expenses drop constraint if exists expenses_category_check;
alter table expenses add constraint expenses_category_check check (
  category in ('house_rent', 'electricity', 'gas', 'servant', 'trash', 'internet', 'filter_kit', 'other')
);

create table if not exists contacts (
  id uuid primary key default gen_random_uuid(),
  cottage_id uuid not null references cottages(id) on delete cascade,
  name text not null,
  mobile_number text,
  email text,
  created_by uuid not null references profiles(id),
  created_at timestamptz not null default now()
);

alter table contacts enable row level security;

create index if not exists contacts_cottage_idx on contacts (cottage_id);

drop policy if exists "contacts_select_own_cottage" on contacts;
create policy "contacts_select_own_cottage" on contacts
  for select to authenticated using (cottage_id = current_cottage_id());

drop policy if exists "contacts_admin_insert" on contacts;
create policy "contacts_admin_insert" on contacts
  for insert to authenticated with check (
    is_super_admin() and cottage_id = current_cottage_id() and created_by = auth.uid()
  );

drop policy if exists "contacts_admin_delete" on contacts;
create policy "contacts_admin_delete" on contacts
  for delete to authenticated using (
    is_super_admin() and cottage_id = current_cottage_id()
  );
