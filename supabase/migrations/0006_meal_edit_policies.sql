-- Allow editing existing Meal Ledger records (daily meals, deposits, bazaar
-- entries) — previously these tables only had select/insert RLS policies, so
-- upserts/updates from the Month Details "edit row" UI would be rejected.
-- Run this in the Supabase SQL editor for your project (after 0001-0005).
-- Safe to re-run: every statement below is idempotent.

drop policy if exists "daily_meals_update_permitted" on daily_meals;
create policy "daily_meals_update_permitted" on daily_meals
  for update to authenticated using (
    cottage_id = current_cottage_id()
    and (is_super_admin() or (select can_add_meals from profiles where id = auth.uid()))
  );

drop policy if exists "deposits_admin_update" on meal_deposits;
create policy "deposits_admin_update" on meal_deposits
  for update to authenticated using (is_super_admin() and cottage_id = current_cottage_id());

drop policy if exists "bazaar_update_permitted" on bazaar_entries;
create policy "bazaar_update_permitted" on bazaar_entries
  for update to authenticated using (
    cottage_id = current_cottage_id()
    and (is_super_admin() or (select can_add_bazaar from profiles where id = auth.uid()))
  );
