-- reset_utility_month() predates utility_adjustments (0012) and never cleared
-- it, so a reset left admin-entered adjustment amounts still counting toward
-- "Total utility due". Adjustments have no date column (just month_key), so
-- delete by cottage_id + month_key directly instead of a date range.
-- Run after 0012. Safe to re-run.

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
end;
$$ language plpgsql security definer;
