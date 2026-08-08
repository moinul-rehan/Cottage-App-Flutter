-- Utility deposits: admin-recorded payments toward a member's utility due
-- (rent + other utility costs), mirroring meal_deposits. Reduces the
-- member's due the same way a settlement does — see getMonthlyDues in
-- src/lib/data/finance.ts.
-- Run after 0014. Safe to re-run.

create table if not exists utility_deposits (
  id uuid primary key default gen_random_uuid(),
  cottage_id uuid not null references cottages(id) on delete cascade,
  month_key text not null,
  user_id uuid not null references profiles(id) on delete cascade,
  amount numeric(10, 2) not null check (amount > 0),
  deposit_date date not null default current_date,
  note text,
  created_by uuid not null references profiles(id),
  created_at timestamptz not null default now()
);

alter table utility_deposits enable row level security;

create index if not exists utility_deposits_cottage_month_idx
  on utility_deposits (cottage_id, month_key);

drop policy if exists "utility_deposits_select_own_cottage" on utility_deposits;
create policy "utility_deposits_select_own_cottage" on utility_deposits
  for select to authenticated using (cottage_id = current_cottage_id());

drop policy if exists "utility_deposits_admin_insert" on utility_deposits;
create policy "utility_deposits_admin_insert" on utility_deposits
  for insert to authenticated with check (
    is_super_admin()
    and cottage_id = current_cottage_id()
    and created_by = auth.uid()
    and not is_month_closed(cottage_id, (month_key || '-01')::date)
  );

drop policy if exists "utility_deposits_admin_delete" on utility_deposits;
create policy "utility_deposits_admin_delete" on utility_deposits
  for delete to authenticated using (
    is_super_admin()
    and cottage_id = current_cottage_id()
    and not is_month_closed(cottage_id, (month_key || '-01')::date)
  );

-- Extend reset_utility_month() (0007, last touched in 0013) to also clear
-- utility_deposits for the active month, same as utility_adjustments.
create or replace function reset_utility_month()
returns void as $$
declare
  v_cottage_id uuid := current_cottage_id();
  v_active text;
  v_start date;
  v_end date;
begin
  if not is_super_admin() then
    raise exception 'Only a super admin can reset the utility month.';
  end if;

  select active_month_key into v_active from cottages where id = v_cottage_id;

  if is_month_closed(v_cottage_id, (v_active || '-01')::date) then
    raise exception 'The active month is locked.';
  end if;

  v_start := (v_active || '-01')::date;
  v_end := (v_start + interval '1 month')::date;

  delete from expenses
  where cottage_id = v_cottage_id and expense_date >= v_start and expense_date < v_end;

  delete from settlements
  where cottage_id = v_cottage_id and settled_on >= v_start and settled_on < v_end;

  delete from cottage_balance_transactions
  where cottage_id = v_cottage_id and created_at >= v_start and created_at < v_end;

  delete from utility_adjustments
  where cottage_id = v_cottage_id and month_key = v_active;

  delete from utility_deposits
  where cottage_id = v_cottage_id and month_key = v_active;
end;
$$ language plpgsql security definer;
