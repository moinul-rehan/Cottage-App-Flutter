-- Cottage Finance Management System: Meal Ledger, Utility Ledger extensions,
-- Cottage Balance, Members permissions, Notifications.
-- Run this in the Supabase SQL editor for your project (after 0001-0003).
-- Safe to re-run: every statement below is idempotent.

-- ── Utility Ledger: expand categories + payment source ─────
alter table expenses drop constraint if exists expenses_category_check;
alter table expenses add constraint expenses_category_check check (
  category in ('house_rent', 'electricity', 'servant', 'trash', 'internet', 'filter_kit', 'other')
);

alter table expenses add column if not exists payment_source text not null default 'member'
  check (payment_source in ('member', 'cottage_balance'));

-- ── Members: extra permission flags (added early — referenced by RLS below) ─
alter table profiles add column if not exists can_add_bazaar boolean not null default true;
alter table profiles add column if not exists can_add_meals boolean not null default true;

-- ── cottage_balance_transactions ─────────────────────────────
create table if not exists cottage_balance_transactions (
  id uuid primary key default gen_random_uuid(),
  cottage_id uuid not null references cottages(id),
  amount numeric(10, 2) not null check (amount > 0),
  direction text not null check (direction in ('in', 'out')),
  reason text,
  related_expense_id uuid references expenses(id) on delete set null,
  created_by uuid not null references profiles(id),
  created_at timestamptz not null default now()
);

create index if not exists cottage_balance_transactions_cottage_idx
  on cottage_balance_transactions(cottage_id);

create or replace function get_cottage_balance(p_cottage_id uuid)
returns numeric as $$
  select coalesce(sum(case when direction = 'in' then amount else -amount end), 0)
  from cottage_balance_transactions
  where cottage_id = p_cottage_id;
$$ language sql security definer stable;

alter table cottage_balance_transactions enable row level security;

drop policy if exists "cottage_balance_select_own_cottage" on cottage_balance_transactions;
create policy "cottage_balance_select_own_cottage" on cottage_balance_transactions
  for select to authenticated using (cottage_id = current_cottage_id());

drop policy if exists "cottage_balance_admin_insert" on cottage_balance_transactions;
create policy "cottage_balance_admin_insert" on cottage_balance_transactions
  for insert to authenticated with check (is_super_admin() and cottage_id = current_cottage_id());

-- ── Meal Ledger: meal_months, bazaar_entries, meal_deposits, daily_meals ─
create table if not exists meal_months (
  id uuid primary key default gen_random_uuid(),
  cottage_id uuid not null references cottages(id),
  month_key text not null,
  is_archived boolean not null default false,
  closed_at timestamptz,
  unique (cottage_id, month_key)
);

create table if not exists bazaar_entries (
  id uuid primary key default gen_random_uuid(),
  cottage_id uuid not null references cottages(id),
  month_key text not null,
  spent_by uuid not null references profiles(id),
  amount numeric(10, 2) not null check (amount > 0),
  description text,
  entry_date date not null default current_date,
  created_by uuid not null references profiles(id),
  created_at timestamptz not null default now()
);

create index if not exists bazaar_entries_month_idx on bazaar_entries(cottage_id, month_key);

create table if not exists meal_deposits (
  id uuid primary key default gen_random_uuid(),
  cottage_id uuid not null references cottages(id),
  month_key text not null,
  user_id uuid not null references profiles(id),
  amount numeric(10, 2) not null check (amount > 0),
  deposit_date date not null default current_date,
  note text,
  created_by uuid not null references profiles(id),
  created_at timestamptz not null default now()
);

create index if not exists meal_deposits_month_idx on meal_deposits(cottage_id, month_key);

create table if not exists daily_meals (
  id uuid primary key default gen_random_uuid(),
  cottage_id uuid not null references cottages(id),
  month_key text not null,
  user_id uuid not null references profiles(id),
  meal_date date not null,
  count numeric(3, 1) not null check (count >= 0),
  created_by uuid not null references profiles(id),
  created_at timestamptz not null default now(),
  unique (user_id, meal_date)
);

create index if not exists daily_meals_month_idx on daily_meals(cottage_id, month_key);

-- ── utility_carry_ins: meal balance carried into next Utility month ──
create table if not exists utility_carry_ins (
  id uuid primary key default gen_random_uuid(),
  cottage_id uuid not null references cottages(id),
  month_key text not null,
  user_id uuid not null references profiles(id),
  amount numeric(10, 2) not null,
  source_month_key text not null,
  created_at timestamptz not null default now(),
  unique (cottage_id, month_key, user_id, source_month_key)
);

-- ── auto-stamp cottage_id + month_key defaults ──────────────
drop trigger if exists bazaar_entries_set_cottage on bazaar_entries;
create trigger bazaar_entries_set_cottage
  before insert on bazaar_entries
  for each row execute function set_cottage_id_from_caller();

drop trigger if exists meal_deposits_set_cottage on meal_deposits;
create trigger meal_deposits_set_cottage
  before insert on meal_deposits
  for each row execute function set_cottage_id_from_caller();

drop trigger if exists daily_meals_set_cottage on daily_meals;
create trigger daily_meals_set_cottage
  before insert on daily_meals
  for each row execute function set_cottage_id_from_caller();

drop trigger if exists cottage_balance_set_cottage on cottage_balance_transactions;
create trigger cottage_balance_set_cottage
  before insert on cottage_balance_transactions
  for each row execute function set_cottage_id_from_caller();

-- ── close a Meal month: archive it and write next month's carry-ins ─
create or replace function close_meal_month(p_month_key text, p_next_month_key text)
returns void as $$
declare
  v_cottage_id uuid := current_cottage_id();
  v_total_bazaar numeric;
  v_total_meals numeric;
  v_meal_rate numeric;
  r record;
begin
  if not is_super_admin() then
    raise exception 'Only a super admin can close a meal month.';
  end if;

  select coalesce(sum(amount), 0) into v_total_bazaar
  from bazaar_entries where cottage_id = v_cottage_id and month_key = p_month_key;

  select coalesce(sum(count), 0) into v_total_meals
  from daily_meals where cottage_id = v_cottage_id and month_key = p_month_key;

  v_meal_rate := case when v_total_meals > 0 then v_total_bazaar / v_total_meals else 0 end;

  for r in
    select p.id as user_id,
      coalesce(d.deposit_total, 0) as deposit_total,
      coalesce(m.meal_total, 0) as meal_total
    from profiles p
    left join (
      select user_id, sum(amount) as deposit_total from meal_deposits
      where cottage_id = v_cottage_id and month_key = p_month_key
      group by user_id
    ) d on d.user_id = p.id
    left join (
      select user_id, sum(count) as meal_total from daily_meals
      where cottage_id = v_cottage_id and month_key = p_month_key
      group by user_id
    ) m on m.user_id = p.id
    where p.cottage_id = v_cottage_id
  loop
    insert into utility_carry_ins (cottage_id, month_key, user_id, amount, source_month_key)
    values (
      v_cottage_id,
      p_next_month_key,
      r.user_id,
      (r.meal_total * v_meal_rate) - r.deposit_total,
      p_month_key
    )
    on conflict (cottage_id, month_key, user_id, source_month_key) do update
      set amount = excluded.amount;
  end loop;

  insert into meal_months (cottage_id, month_key, is_archived, closed_at)
  values (v_cottage_id, p_month_key, true, now())
  on conflict (cottage_id, month_key) do update set is_archived = true, closed_at = now();
end;
$$ language plpgsql security definer;

grant execute on function close_meal_month(text, text) to authenticated;

-- ── Meal Ledger RLS: transparent, all cottage members can read ─
alter table meal_months enable row level security;
alter table bazaar_entries enable row level security;
alter table meal_deposits enable row level security;
alter table daily_meals enable row level security;
alter table utility_carry_ins enable row level security;

drop policy if exists "meal_months_select_own_cottage" on meal_months;
create policy "meal_months_select_own_cottage" on meal_months
  for select to authenticated using (cottage_id = current_cottage_id());

drop policy if exists "bazaar_select_own_cottage" on bazaar_entries;
create policy "bazaar_select_own_cottage" on bazaar_entries
  for select to authenticated using (cottage_id = current_cottage_id());

drop policy if exists "bazaar_insert_permitted" on bazaar_entries;
create policy "bazaar_insert_permitted" on bazaar_entries
  for insert to authenticated with check (
    created_by = auth.uid()
    and cottage_id = current_cottage_id()
    and (is_super_admin() or (select can_add_bazaar from profiles where id = auth.uid()))
  );

drop policy if exists "deposits_select_own_cottage" on meal_deposits;
create policy "deposits_select_own_cottage" on meal_deposits
  for select to authenticated using (cottage_id = current_cottage_id());

drop policy if exists "deposits_admin_insert" on meal_deposits;
create policy "deposits_admin_insert" on meal_deposits
  for insert to authenticated with check (is_super_admin() and cottage_id = current_cottage_id());

drop policy if exists "daily_meals_select_own_cottage" on daily_meals;
create policy "daily_meals_select_own_cottage" on daily_meals
  for select to authenticated using (cottage_id = current_cottage_id());

drop policy if exists "daily_meals_insert_permitted" on daily_meals;
create policy "daily_meals_insert_permitted" on daily_meals
  for insert to authenticated with check (
    created_by = auth.uid()
    and cottage_id = current_cottage_id()
    and (is_super_admin() or (select can_add_meals from profiles where id = auth.uid()))
  );

drop policy if exists "carry_ins_select_own_cottage" on utility_carry_ins;
create policy "carry_ins_select_own_cottage" on utility_carry_ins
  for select to authenticated using (cottage_id = current_cottage_id());

-- ── Notifications ────────────────────────────────────────────
create table if not exists notifications (
  id uuid primary key default gen_random_uuid(),
  cottage_id uuid not null references cottages(id),
  user_id uuid not null references profiles(id),
  type text not null,
  title text not null,
  body text,
  link text,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists notifications_user_idx on notifications(user_id, is_read);

alter table notifications enable row level security;

drop policy if exists "notifications_select_own" on notifications;
create policy "notifications_select_own" on notifications
  for select to authenticated using (user_id = auth.uid());

drop policy if exists "notifications_insert_own_cottage" on notifications;
create policy "notifications_insert_own_cottage" on notifications
  for insert to authenticated with check (cottage_id = current_cottage_id());

drop policy if exists "notifications_update_own" on notifications;
create policy "notifications_update_own" on notifications
  for update to authenticated using (user_id = auth.uid());
