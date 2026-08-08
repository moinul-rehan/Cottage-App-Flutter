-- Let a bazaar entry optionally credit the spender's meal deposit in the same
-- atomic operation (used by the "Cost deposit to {member}" checkbox).
-- Run this in the Supabase SQL editor for your project (after 0001-0004).
-- Safe to re-run: every statement below is idempotent.

create or replace function add_bazaar_entry(
  p_month_key text,
  p_spent_by uuid,
  p_amount numeric,
  p_description text,
  p_entry_date date,
  p_credit_deposit boolean
)
returns uuid as $$
declare
  v_cottage_id uuid := current_cottage_id();
  v_entry_id uuid;
  v_can_add_bazaar boolean;
begin
  select (is_super_admin() or can_add_bazaar) into v_can_add_bazaar
  from profiles where id = auth.uid();

  if not coalesce(v_can_add_bazaar, false) then
    raise exception 'You do not have permission to add bazaar entries.';
  end if;

  insert into bazaar_entries (cottage_id, month_key, spent_by, amount, description, entry_date, created_by)
  values (v_cottage_id, p_month_key, p_spent_by, p_amount, p_description, p_entry_date, auth.uid())
  returning id into v_entry_id;

  if p_credit_deposit then
    insert into meal_deposits (cottage_id, month_key, user_id, amount, deposit_date, note, created_by)
    values (
      v_cottage_id,
      p_month_key,
      p_spent_by,
      p_amount,
      p_entry_date,
      'Auto-credited from bazaar entry',
      auth.uid()
    );
  end if;

  return v_entry_id;
end;
$$ language plpgsql security definer;

grant execute on function add_bazaar_entry(text, uuid, numeric, text, date, boolean) to authenticated;
