-- daily_meals, bazaar_entries, meal_deposits, and developer_feedback had no
-- delete RLS policy, so the delete buttons added for them silently deleted
-- 0 rows (RLS denies by default with no matching policy - no error, just
-- nothing happens). The meal-ledger policies mirror each table's existing
-- *_update_permitted / deposits_admin_update policy exactly, so delete is
-- allowed under the same conditions edit already is. developer_feedback
-- never had an update/delete policy at all (0031 deliberately left it
-- uneditable) - now that members can delete their own feedback from
-- history, this scopes delete to the submitter only.

drop policy if exists "bazaar_delete_permitted" on bazaar_entries;
create policy "bazaar_delete_permitted" on bazaar_entries
  for delete to authenticated using (
    cottage_id = current_cottage_id()
    and (is_super_admin() or (select can_add_bazaar from profiles where id = auth.uid()))
    and not is_month_closed(cottage_id, (month_key || '-01')::date)
  );

drop policy if exists "deposits_admin_delete" on meal_deposits;
create policy "deposits_admin_delete" on meal_deposits
  for delete to authenticated using (
    is_super_admin()
    and cottage_id = current_cottage_id()
    and not is_month_closed(cottage_id, (month_key || '-01')::date)
  );

drop policy if exists "daily_meals_delete_permitted" on daily_meals;
create policy "daily_meals_delete_permitted" on daily_meals
  for delete to authenticated using (
    cottage_id = current_cottage_id()
    and (is_super_admin() or (select can_add_meals from profiles where id = auth.uid()))
    and not is_month_closed(cottage_id, (month_key || '-01')::date)
  );

drop policy if exists "developer_feedback_delete_own" on developer_feedback;
create policy "developer_feedback_delete_own" on developer_feedback
  for delete to authenticated using (
    cottage_id = current_cottage_id() and user_id = auth.uid()
  );
