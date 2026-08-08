-- Manual month management: let a super admin explicitly pick the active
-- month (instead of only auto-advancing by 1), and permanently delete a
-- locked history month's data. Run after 0001-0008. Safe to re-run.

-- ── set_active_month(): explicitly set the cottage's active month ──
-- Locks whatever month is currently active (same as create_new_month /
-- activate_month do), then opens the requested month — whether that
-- month already has history or is brand new. Refuses to set a month
-- later than the current real-world calendar month, so nobody can open
-- August while July hasn't happened yet.
create or replace function set_active_month(p_month_key text)
returns void as $$
declare
  v_cottage_id uuid := current_cottage_id();
  v_active text;
  v_current_calendar_month text := to_char(now(), 'YYYY-MM');
begin
  if not is_super_admin() then
    raise exception 'Only a super admin can set the active month.';
  end if;

  if p_month_key !~ '^\d{4}-\d{2}$' then
    raise exception 'Invalid month.';
  end if;

  if p_month_key > v_current_calendar_month then
    raise exception 'Cannot activate a month that has not started yet.';
  end if;

  select active_month_key into v_active from cottages where id = v_cottage_id;

  if v_active = p_month_key then
    return;
  end if;

  -- Lock the currently-active month in its place.
  insert into month_closures (cottage_id, month_key, closed_by)
  values (v_cottage_id, v_active, auth.uid())
  on conflict (cottage_id, month_key) do nothing;

  insert into meal_months (cottage_id, month_key, is_archived, closed_at)
  values (v_cottage_id, v_active, true, now())
  on conflict (cottage_id, month_key) do update set is_archived = true, closed_at = now();

  -- Open the requested month (clears any prior lock on it, if it was
  -- previously in history).
  delete from month_closures where cottage_id = v_cottage_id and month_key = p_month_key;

  insert into meal_months (cottage_id, month_key, is_archived, closed_at)
  values (v_cottage_id, p_month_key, false, null)
  on conflict (cottage_id, month_key) do update set is_archived = false, closed_at = null;

  update cottages set active_month_key = p_month_key where id = v_cottage_id;
end;
$$ language plpgsql security definer;

grant execute on function set_active_month(text) to authenticated;

-- ── delete_month(): permanently wipe a locked month's data ─────────
-- Irreversible. Refuses to touch the currently-active month — only
-- locked (history) months can be deleted.
create or replace function delete_month(p_month_key text)
returns void as $$
declare
  v_cottage_id uuid := current_cottage_id();
  v_active text;
  v_start date;
  v_end date;
begin
  if not is_super_admin() then
    raise exception 'Only a super admin can delete a month.';
  end if;

  select active_month_key into v_active from cottages where id = v_cottage_id;

  if v_active = p_month_key then
    raise exception 'Cannot delete the active month.';
  end if;

  if not exists (
    select 1 from month_closures where cottage_id = v_cottage_id and month_key = p_month_key
  ) then
    raise exception 'That month is not in history.';
  end if;

  v_start := (p_month_key || '-01')::date;
  v_end := (v_start + interval '1 month')::date;

  delete from expenses
  where cottage_id = v_cottage_id and expense_date >= v_start and expense_date < v_end;

  delete from settlements
  where cottage_id = v_cottage_id and settled_on >= v_start and settled_on < v_end;

  delete from cottage_balance_transactions
  where cottage_id = v_cottage_id and created_at >= v_start and created_at < v_end;

  delete from bazaar_entries where cottage_id = v_cottage_id and month_key = p_month_key;
  delete from meal_deposits where cottage_id = v_cottage_id and month_key = p_month_key;
  delete from daily_meals where cottage_id = v_cottage_id and month_key = p_month_key;
  delete from utility_carry_ins where cottage_id = v_cottage_id and month_key = p_month_key;

  delete from month_closures where cottage_id = v_cottage_id and month_key = p_month_key;
  delete from meal_months where cottage_id = v_cottage_id and month_key = p_month_key;
end;
$$ language plpgsql security definer;

grant execute on function delete_month(text) to authenticated;
