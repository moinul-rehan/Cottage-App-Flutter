-- Shared-house expense manager schema
-- Run this in the Supabase SQL editor for your project.

create extension if not exists "pgcrypto";

-- ── profiles ────────────────────────────────────────────────
-- One row per auth.users entry. Created automatically via trigger on signup.
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  role text not null default 'member' check (role in ('super_admin', 'member')),
  room_label text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- Auto-create a profile row whenever a new auth user is created (via admin invite).
create function handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, full_name, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.email),
    coalesce(new.raw_user_meta_data ->> 'role', 'member')
  );
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- ── rent_assignments ────────────────────────────────────────
-- Super admin sets each member's fixed monthly rent (room size/facility based).
create table rent_assignments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  monthly_rent_amount numeric(10, 2) not null check (monthly_rent_amount >= 0),
  effective_from date not null default current_date,
  set_by uuid not null references profiles(id),
  notes text,
  created_at timestamptz not null default now()
);

create index rent_assignments_user_id_idx on rent_assignments(user_id);

-- ── expenses ────────────────────────────────────────────────
create table expenses (
  id uuid primary key default gen_random_uuid(),
  category text not null check (category in ('servant', 'electricity', 'internet', 'other')),
  amount numeric(10, 2) not null check (amount > 0),
  description text,
  paid_by uuid not null references profiles(id),
  expense_date date not null default current_date,
  split_type text not null check (split_type in ('equal', 'custom')),
  created_by uuid not null references profiles(id),
  created_at timestamptz not null default now()
);

create index expenses_expense_date_idx on expenses(expense_date);
create index expenses_paid_by_idx on expenses(paid_by);

-- ── expense_splits ──────────────────────────────────────────
create table expense_splits (
  id uuid primary key default gen_random_uuid(),
  expense_id uuid not null references expenses(id) on delete cascade,
  user_id uuid not null references profiles(id),
  share_amount numeric(10, 2) not null check (share_amount >= 0),
  unique (expense_id, user_id)
);

create index expense_splits_user_id_idx on expense_splits(user_id);

-- ── settlements ─────────────────────────────────────────────
create table settlements (
  id uuid primary key default gen_random_uuid(),
  from_user uuid not null references profiles(id),
  to_user uuid not null references profiles(id),
  amount numeric(10, 2) not null check (amount > 0),
  settled_on date not null default current_date,
  note text,
  recorded_by uuid not null references profiles(id),
  created_at timestamptz not null default now(),
  check (from_user <> to_user)
);

create index settlements_from_user_idx on settlements(from_user);
create index settlements_to_user_idx on settlements(to_user);

-- ── helper: is current user a super_admin ──────────────────
create function is_super_admin()
returns boolean as $$
  select exists (
    select 1 from profiles
    where id = auth.uid() and role = 'super_admin'
  );
$$ language sql security definer stable;

-- ── RLS ─────────────────────────────────────────────────────
alter table profiles enable row level security;
alter table rent_assignments enable row level security;
alter table expenses enable row level security;
alter table expense_splits enable row level security;
alter table settlements enable row level security;

-- profiles: everyone authenticated can read all profiles (house transparency);
-- only super_admin can insert/update; users cannot edit their own role.
create policy "profiles_select_all" on profiles
  for select to authenticated using (true);

create policy "profiles_admin_write" on profiles
  for update to authenticated using (is_super_admin());

-- rent_assignments: everyone can read; only super_admin can write.
create policy "rent_select_all" on rent_assignments
  for select to authenticated using (true);

create policy "rent_admin_insert" on rent_assignments
  for insert to authenticated with check (is_super_admin());

create policy "rent_admin_update" on rent_assignments
  for update to authenticated using (is_super_admin());

-- expenses: everyone can read; any member can insert an expense (paid_by can be
-- themselves or another member they're recording on behalf of), only the
-- creator or super_admin can update/delete.
create policy "expenses_select_all" on expenses
  for select to authenticated using (true);

create policy "expenses_insert_own" on expenses
  for insert to authenticated with check (created_by = auth.uid());

create policy "expenses_update_own_or_admin" on expenses
  for update to authenticated using (created_by = auth.uid() or is_super_admin());

create policy "expenses_delete_own_or_admin" on expenses
  for delete to authenticated using (created_by = auth.uid() or is_super_admin());

-- expense_splits: everyone can read; insert only alongside an expense the
-- caller created (enforced via join back to expenses.created_by).
create policy "splits_select_all" on expense_splits
  for select to authenticated using (true);

create policy "splits_insert_with_expense" on expense_splits
  for insert to authenticated with check (
    exists (
      select 1 from expenses
      where expenses.id = expense_splits.expense_id
        and expenses.created_by = auth.uid()
    )
  );

-- settlements: everyone can read; insert only if the caller is one of the two
-- parties involved, or is super_admin.
create policy "settlements_select_all" on settlements
  for select to authenticated using (true);

create policy "settlements_insert_involved_or_admin" on settlements
  for insert to authenticated with check (
    auth.uid() in (from_user, to_user) or is_super_admin()
  );
