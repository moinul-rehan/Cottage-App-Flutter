-- Multi-tenant "Cottage" support: every house is now an isolated cottage.
-- Run this in the Supabase SQL editor for your project (after 0001 and 0002).
-- Safe to re-run: every statement below is idempotent.

-- ── cottages ────────────────────────────────────────────────
create table if not exists cottages (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);

-- ── add cottage_id to existing tables (nullable until backfilled) ─
alter table profiles add column if not exists cottage_id uuid references cottages(id);
alter table expenses add column if not exists cottage_id uuid references cottages(id);
alter table rent_assignments add column if not exists cottage_id uuid references cottages(id);
alter table settlements add column if not exists cottage_id uuid references cottages(id);

-- ── backfill existing data into a single "My Cottage" ──────
-- Picks the earliest-created profile as the owner (promoting them to
-- super_admin if they weren't already), reusing an existing "My Cottage"
-- row if a previous run already created one.
do $$
declare
  v_cottage_id uuid;
  v_owner_id uuid;
begin
  select id into v_cottage_id from cottages order by created_at asc limit 1;

  if v_cottage_id is null then
    select id into v_owner_id from profiles order by created_at asc limit 1;

    if v_owner_id is not null then
      insert into cottages (name, created_by)
      values ('My Cottage', v_owner_id)
      returning id into v_cottage_id;

      update profiles set role = 'super_admin' where id = v_owner_id;
    end if;
  end if;

  if v_cottage_id is not null then
    update profiles set cottage_id = v_cottage_id where cottage_id is null;
    update expenses set cottage_id = v_cottage_id where cottage_id is null;
    update rent_assignments set cottage_id = v_cottage_id where cottage_id is null;
    update settlements set cottage_id = v_cottage_id where cottage_id is null;
  end if;
end $$;

alter table profiles alter column cottage_id set not null;
alter table expenses alter column cottage_id set not null;
alter table rent_assignments alter column cottage_id set not null;
alter table settlements alter column cottage_id set not null;

-- ── helper: caller's cottage id ────────────────────────────
create or replace function current_cottage_id()
returns uuid as $$
  select cottage_id from profiles where id = auth.uid();
$$ language sql security definer stable;

-- ── auto-stamp cottage_id on insert (can't be spoofed by clients) ─
create or replace function set_cottage_id_from_caller()
returns trigger as $$
begin
  new.cottage_id := current_cottage_id();
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists expenses_set_cottage on expenses;
create trigger expenses_set_cottage
  before insert on expenses
  for each row execute function set_cottage_id_from_caller();

drop trigger if exists rent_assignments_set_cottage on rent_assignments;
create trigger rent_assignments_set_cottage
  before insert on rent_assignments
  for each row execute function set_cottage_id_from_caller();

drop trigger if exists settlements_set_cottage on settlements;
create trigger settlements_set_cottage
  before insert on settlements
  for each row execute function set_cottage_id_from_caller();

-- ── signup: create a new cottage vs. join an existing one ─
create or replace function handle_new_user()
returns trigger as $$
declare
  v_mode text := new.raw_user_meta_data ->> 'mode';
  v_cottage_id uuid;
begin
  if v_mode = 'create_cottage' then
    insert into public.cottages (name, created_by)
    values (coalesce(new.raw_user_meta_data ->> 'cottage_name', 'My Cottage'), new.id)
    returning id into v_cottage_id;

    insert into public.profiles (id, cottage_id, first_name, last_name, email, role)
    values (
      new.id,
      v_cottage_id,
      coalesce(new.raw_user_meta_data ->> 'first_name', split_part(new.email, '@', 1)),
      new.raw_user_meta_data ->> 'last_name',
      new.email,
      'super_admin'
    );
  elsif v_mode = 'join_cottage' then
    insert into public.profiles (id, cottage_id, first_name, last_name, email, role)
    values (
      new.id,
      (new.raw_user_meta_data ->> 'cottage_id')::uuid,
      coalesce(new.raw_user_meta_data ->> 'first_name', split_part(new.email, '@', 1)),
      new.raw_user_meta_data ->> 'last_name',
      new.email,
      coalesce(new.raw_user_meta_data ->> 'role', 'member')
    );
  end if;
  -- Neither mode (e.g. a brand-new Google OAuth sign-in with no custom
  -- metadata yet): leave no profile row. /auth/callback creates the profile
  -- explicitly via create_cottage_for_current_user(), or rejects the sign-in
  -- if it was a "log in as existing member" attempt.
  return new;
end;
$$ language plpgsql security definer;

-- ── Google OAuth "create cottage" path (called from /auth/callback) ─
create or replace function create_cottage_for_current_user(
  p_cottage_name text,
  p_first_name text,
  p_last_name text
)
returns void as $$
declare
  v_cottage_id uuid;
  v_email text;
begin
  if exists (select 1 from profiles where id = auth.uid()) then
    return;
  end if;

  select email into v_email from auth.users where id = auth.uid();

  insert into cottages (name, created_by)
  values (coalesce(p_cottage_name, 'My Cottage'), auth.uid())
  returning id into v_cottage_id;

  insert into profiles (id, cottage_id, first_name, last_name, email, role)
  values (
    auth.uid(),
    v_cottage_id,
    coalesce(p_first_name, split_part(v_email, '@', 1)),
    p_last_name,
    v_email,
    'super_admin'
  );
end;
$$ language plpgsql security definer;

grant execute on function create_cottage_for_current_user(text, text, text) to authenticated;

-- ── month_closures: "Start new month" archive/lock ─────────
create table if not exists month_closures (
  id uuid primary key default gen_random_uuid(),
  cottage_id uuid not null references cottages(id),
  month_key text not null,
  closed_by uuid not null references profiles(id),
  closed_at timestamptz not null default now(),
  unique (cottage_id, month_key)
);

create or replace function is_month_closed(p_cottage_id uuid, p_date date)
returns boolean as $$
  select exists (
    select 1 from month_closures
    where cottage_id = p_cottage_id and month_key = to_char(p_date, 'YYYY-MM')
  );
$$ language sql security definer stable;

alter table month_closures enable row level security;

drop policy if exists "month_closures_select_own_cottage" on month_closures;
create policy "month_closures_select_own_cottage" on month_closures
  for select to authenticated using (cottage_id = current_cottage_id());

drop policy if exists "month_closures_admin_insert" on month_closures;
create policy "month_closures_admin_insert" on month_closures
  for insert to authenticated with check (is_super_admin() and cottage_id = current_cottage_id());

-- ── cottages RLS ────────────────────────────────────────────
alter table cottages enable row level security;

drop policy if exists "cottages_select_own" on cottages;
create policy "cottages_select_own" on cottages
  for select to authenticated using (id = current_cottage_id());

-- ── rewrite existing RLS for tenant isolation + month locking ─

-- profiles
drop policy if exists "profiles_select_all" on profiles;
drop policy if exists "profiles_select_own_cottage" on profiles;
drop policy if exists "profiles_admin_write" on profiles;

create policy "profiles_select_own_cottage" on profiles
  for select to authenticated using (cottage_id = current_cottage_id());

create policy "profiles_admin_write" on profiles
  for update to authenticated using (is_super_admin() and cottage_id = current_cottage_id());

-- rent_assignments
drop policy if exists "rent_select_all" on rent_assignments;
drop policy if exists "rent_select_own_cottage" on rent_assignments;
drop policy if exists "rent_admin_insert" on rent_assignments;
drop policy if exists "rent_admin_update" on rent_assignments;

create policy "rent_select_own_cottage" on rent_assignments
  for select to authenticated using (cottage_id = current_cottage_id());

create policy "rent_admin_insert" on rent_assignments
  for insert to authenticated with check (is_super_admin() and cottage_id = current_cottage_id());

create policy "rent_admin_update" on rent_assignments
  for update to authenticated using (is_super_admin() and cottage_id = current_cottage_id());

-- expenses
drop policy if exists "expenses_select_all" on expenses;
drop policy if exists "expenses_select_own_cottage" on expenses;
drop policy if exists "expenses_insert_own" on expenses;
drop policy if exists "expenses_update_own_or_admin" on expenses;
drop policy if exists "expenses_delete_own_or_admin" on expenses;

create policy "expenses_select_own_cottage" on expenses
  for select to authenticated using (cottage_id = current_cottage_id());

create policy "expenses_insert_own" on expenses
  for insert to authenticated with check (
    created_by = auth.uid()
    and cottage_id = current_cottage_id()
    and (is_super_admin() or (select can_add_expenses from profiles where id = auth.uid()))
    and not is_month_closed(cottage_id, expense_date)
  );

create policy "expenses_update_own_or_admin" on expenses
  for update to authenticated using (
    cottage_id = current_cottage_id()
    and (created_by = auth.uid() or is_super_admin())
    and not is_month_closed(cottage_id, expense_date)
  );

create policy "expenses_delete_own_or_admin" on expenses
  for delete to authenticated using (
    cottage_id = current_cottage_id()
    and (created_by = auth.uid() or is_super_admin())
    and not is_month_closed(cottage_id, expense_date)
  );

-- expense_splits (scoped via the parent expense's cottage)
drop policy if exists "splits_select_all" on expense_splits;
drop policy if exists "splits_select_own_cottage" on expense_splits;
drop policy if exists "splits_insert_with_expense" on expense_splits;

create policy "splits_select_own_cottage" on expense_splits
  for select to authenticated using (
    exists (
      select 1 from expenses
      where expenses.id = expense_splits.expense_id
        and expenses.cottage_id = current_cottage_id()
    )
  );

create policy "splits_insert_with_expense" on expense_splits
  for insert to authenticated with check (
    exists (
      select 1 from expenses
      where expenses.id = expense_splits.expense_id
        and expenses.created_by = auth.uid()
        and expenses.cottage_id = current_cottage_id()
    )
  );

-- settlements
drop policy if exists "settlements_select_all" on settlements;
drop policy if exists "settlements_select_own_cottage" on settlements;
drop policy if exists "settlements_insert_involved_or_admin" on settlements;

create policy "settlements_select_own_cottage" on settlements
  for select to authenticated using (cottage_id = current_cottage_id());

create policy "settlements_insert_involved_or_admin" on settlements
  for insert to authenticated with check (
    cottage_id = current_cottage_id()
    and (auth.uid() in (from_user, to_user) or is_super_admin())
    and not is_month_closed(cottage_id, settled_on)
  );
