-- Active Month workflow: one authoritative "active month" per cottage that
-- drives Dashboard/Meal/Utilities everywhere, plus password-gated
-- Reset Utilities / Reset Meal / Create New Month / Activate actions.
-- Run this in the Supabase SQL editor for your project (after 0001-0006).
-- Safe to re-run: every statement below is idempotent.

-- ── cottages: active_month_key ──────────────────────────────
alter table cottages add column if not exists active_month_key text;

update cottages set active_month_key = to_char(now(), 'YYYY-MM') where active_month_key is null;

alter table cottages alter column active_month_key set not null;

-- ── lock enforcement: extend Meal Ledger RLS with month-lock check ─
drop policy if exists "bazaar_insert_permitted" on bazaar_entries;
create policy "bazaar_insert_permitted" on bazaar_entries
  for insert to authenticated with check (
    created_by = auth.uid()
    and cottage_id = current_cottage_id()
    and (is_super_admin() or (select can_add_bazaar from profiles where id = auth.uid()))
    and not is_month_closed(cottage_id, (month_key || '-01')::date)
  );

drop policy if exists "bazaar_update_permitted" on bazaar_entries;
create policy "bazaar_update_permitted" on bazaar_entries
  for update to authenticated using (
    cottage_id = current_cottage_id()
    and (is_super_admin() or (select can_add_bazaar from profiles where id = auth.uid()))
    and not is_month_closed(cottage_id, (month_key || '-01')::date)
  );

drop policy if exists "deposits_admin_insert" on meal_deposits;
create policy "deposits_admin_insert" on meal_deposits
  for insert to authenticated with check (
    is_super_admin()
    and cottage_id = current_cottage_id()
    and not is_month_closed(cottage_id, (month_key || '-01')::date)
  );

drop policy if exists "deposits_admin_update" on meal_deposits;
create policy "deposits_admin_update" on meal_deposits
  for update to authenticated using (
    is_super_admin()
    and cottage_id = current_cottage_id()
    and not is_month_closed(cottage_id, (month_key || '-01')::date)
  );

drop policy if exists "daily_meals_insert_permitted" on daily_meals;
create policy "daily_meals_insert_permitted" on daily_meals
  for insert to authenticated with check (
    created_by = auth.uid()
    and cottage_id = current_cottage_id()
    and (is_super_admin() or (select can_add_meals from profiles where id = auth.uid()))
    and not is_month_closed(cottage_id, (month_key || '-01')::date)
  );

drop policy if exists "daily_meals_update_permitted" on daily_meals;
create policy "daily_meals_update_permitted" on daily_meals
  for update to authenticated using (
    cottage_id = current_cottage_id()
    and (is_super_admin() or (select can_add_meals from profiles where id = auth.uid()))
    and not is_month_closed(cottage_id, (month_key || '-01')::date)
  );

-- ── create_new_month(): lock the active month, carry meal balances, advance ─
create or replace function create_new_month()
returns text as $$
declare
  v_cottage_id uuid := current_cottage_id();
  v_active text;
  v_next text;
  v_total_bazaar numeric;
  v_total_meals numeric;
  v_meal_rate numeric;
  r record;
begin
  if not is_super_admin() then
    raise exception 'Only a super admin can create a new month.';
  end if;

  select active_month_key into v_active from cottages where id = v_cottage_id;
  v_next := to_char((to_date(v_active || '-01', 'YYYY-MM-DD') + interval '1 month'), 'YYYY-MM');

  -- Meal carry-forward: each member's (meal cost - deposit) for the active
  -- month becomes a due/credit line in the next month's Utility ledger.
  select coalesce(sum(amount), 0) into v_total_bazaar
  from bazaar_entries where cottage_id = v_cottage_id and month_key = v_active;

  select coalesce(sum(count), 0) into v_total_meals
  from daily_meals where cottage_id = v_cottage_id and month_key = v_active;

  v_meal_rate := case when v_total_meals > 0 then v_total_bazaar / v_total_meals else 0 end;

  for r in
    select p.id as user_id,
      coalesce(d.deposit_total, 0) as deposit_total,
      coalesce(m.meal_total, 0) as meal_total
    from profiles p
    left join (
      select user_id, sum(amount) as deposit_total from meal_deposits
      where cottage_id = v_cottage_id and month_key = v_active
      group by user_id
    ) d on d.user_id = p.id
    left join (
      select user_id, sum(count) as meal_total from daily_meals
      where cottage_id = v_cottage_id and month_key = v_active
      group by user_id
    ) m on m.user_id = p.id
    where p.cottage_id = v_cottage_id
  loop
    insert into utility_carry_ins (cottage_id, month_key, user_id, amount, source_month_key)
    values (v_cottage_id, v_next, r.user_id, (r.meal_total * v_meal_rate) - r.deposit_total, v_active)
    on conflict (cottage_id, month_key, user_id, source_month_key) do update
      set amount = excluded.amount;
  end loop;

  -- Lock the active month for both ledgers.
  insert into month_closures (cottage_id, month_key, closed_by)
  values (v_cottage_id, v_active, auth.uid())
  on conflict (cottage_id, month_key) do nothing;

  insert into meal_months (cottage_id, month_key, is_archived, closed_at)
  values (v_cottage_id, v_active, true, now())
  on conflict (cottage_id, month_key) do update set is_archived = true, closed_at = now();

  update cottages set active_month_key = v_next where id = v_cottage_id;

  return v_next;
end;
$$ language plpgsql security definer;

grant execute on function create_new_month() to authenticated;

-- ── activate_month(): reopen a locked month, re-lock whatever was active ─
create or replace function activate_month(p_month_key text)
returns void as $$
declare
  v_cottage_id uuid := current_cottage_id();
  v_active text;
begin
  if not is_super_admin() then
    raise exception 'Only a super admin can activate a month.';
  end if;

  select active_month_key into v_active from cottages where id = v_cottage_id;

  if v_active = p_month_key then
    return;
  end if;

  if not exists (
    select 1 from month_closures where cottage_id = v_cottage_id and month_key = p_month_key
  ) then
    raise exception 'That month is not in history.';
  end if;

  -- Lock the currently-active month in its place.
  insert into month_closures (cottage_id, month_key, closed_by)
  values (v_cottage_id, v_active, auth.uid())
  on conflict (cottage_id, month_key) do nothing;

  insert into meal_months (cottage_id, month_key, is_archived, closed_at)
  values (v_cottage_id, v_active, true, now())
  on conflict (cottage_id, month_key) do update set is_archived = true, closed_at = now();

  -- Unlock the requested month.
  delete from month_closures where cottage_id = v_cottage_id and month_key = p_month_key;

  update meal_months set is_archived = false, closed_at = null
  where cottage_id = v_cottage_id and month_key = p_month_key;

  update cottages set active_month_key = p_month_key where id = v_cottage_id;
end;
$$ language plpgsql security definer;

grant execute on function activate_month(text) to authenticated;

-- ── reset_utility_month(): wipe the active month's Utility ledger ──
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
end;
$$ language plpgsql security definer;

grant execute on function reset_utility_month() to authenticated;

-- ── reset_meal_month(): wipe the active month's Meal ledger ─────
create or replace function reset_meal_month()
returns void as $$
declare
  v_cottage_id uuid := current_cottage_id();
  v_active text;
begin
  if not is_super_admin() then
    raise exception 'Only a super admin can reset the meal month.';
  end if;

  select active_month_key into v_active from cottages where id = v_cottage_id;

  if is_month_closed(v_cottage_id, (v_active || '-01')::date) then
    raise exception 'The active month is locked.';
  end if;

  delete from bazaar_entries where cottage_id = v_cottage_id and month_key = v_active;
  delete from meal_deposits where cottage_id = v_cottage_id and month_key = v_active;
  delete from daily_meals where cottage_id = v_cottage_id and month_key = v_active;
end;
$$ language plpgsql security definer;

grant execute on function reset_meal_month() to authenticated;
