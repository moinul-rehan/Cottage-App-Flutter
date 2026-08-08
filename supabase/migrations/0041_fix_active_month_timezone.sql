-- set_active_month() compared p_month_key against to_char(now(), 'YYYY-MM'),
-- which uses the DB session's timezone (UTC). For users ahead of UTC (e.g.
-- Bangladesh, UTC+6) that rejects the current calendar month for the first
-- several hours of each day, matching a client-side bug just fixed in
-- SetActiveMonthCard.tsx (it used toISOString() instead of local date
-- parts). Compares against Asia/Dhaka's calendar month instead. Run after
-- 0001-0040. Safe to re-run.

create or replace function set_active_month(p_month_key text)
returns void as $$
declare
  v_cottage_id uuid := current_cottage_id();
  v_active text;
  v_current_calendar_month text := to_char(now() at time zone 'Asia/Dhaka', 'YYYY-MM');
  v_total_bazaar numeric;
  v_total_meals numeric;
  v_meal_rate numeric;
  r record;
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

  -- ── Carry the closing month's leftover Utility due/advance forward ──
  for r in
    select p.id as user_id,
      coalesce(a.total, 0) - coalesce(d.total, 0) as due
    from profiles p
    left join (
      select user_id, sum(amount) as total from utility_adjustments
      where cottage_id = v_cottage_id and month_key = v_active
      group by user_id
    ) a on a.user_id = p.id
    left join (
      select user_id, sum(amount) as total from utility_deposits
      where cottage_id = v_cottage_id and month_key = v_active and source_type = 'member'
      group by user_id
    ) d on d.user_id = p.id
    where p.cottage_id = v_cottage_id
  loop
    if r.due != 0 then
      insert into utility_carry_ins (cottage_id, month_key, user_id, amount, source_month_key, kind)
      values (v_cottage_id, p_month_key, r.user_id, r.due, v_active, 'utility')
      on conflict (cottage_id, month_key, user_id, source_month_key, kind) do update
        set amount = excluded.amount;
    end if;
  end loop;

  -- ── Carry the closing month's leftover Meal due/balance forward ──
  select coalesce(sum(amount), 0) into v_total_bazaar
  from bazaar_entries where cottage_id = v_cottage_id and month_key = v_active;

  select coalesce(sum(count), 0) into v_total_meals
  from daily_meals where cottage_id = v_cottage_id and month_key = v_active;

  v_meal_rate := case when v_total_meals > 0 then v_total_bazaar / v_total_meals else 0 end;

  for r in
    select p.id as user_id,
      (coalesce(m.meal_total, 0) * v_meal_rate) - coalesce(d.deposit_total, 0) as due
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
    if r.due != 0 then
      insert into utility_carry_ins (cottage_id, month_key, user_id, amount, source_month_key, kind)
      values (v_cottage_id, p_month_key, r.user_id, r.due, v_active, 'meal')
      on conflict (cottage_id, month_key, user_id, source_month_key, kind) do update
        set amount = excluded.amount;
    end if;
  end loop;

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
