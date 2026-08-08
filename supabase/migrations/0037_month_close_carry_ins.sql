-- Auto-carries a member's leftover Utility due/advance AND Meal due/balance
-- from a closing month into utility_carry_ins for the next month, so it
-- shows up (and is counted) on that next month's Utility Statement. Run
-- after 0001-0036. Safe to re-run.

alter table utility_carry_ins add column if not exists kind text not null default 'meal';

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'utility_carry_ins_kind_check') then
    alter table utility_carry_ins add constraint utility_carry_ins_kind_check check (kind in ('meal', 'utility'));
  end if;
end $$;

alter table utility_carry_ins drop constraint if exists utility_carry_ins_cottage_id_month_key_user_id_source_month_key_key;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'utility_carry_ins_unique_kind') then
    alter table utility_carry_ins add constraint utility_carry_ins_unique_kind
      unique (cottage_id, month_key, user_id, source_month_key, kind);
  end if;
end $$;

create or replace function set_active_month(p_month_key text)
returns void as $$
declare
  v_cottage_id uuid := current_cottage_id();
  v_active text;
  v_current_calendar_month text := to_char(now(), 'YYYY-MM');
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
