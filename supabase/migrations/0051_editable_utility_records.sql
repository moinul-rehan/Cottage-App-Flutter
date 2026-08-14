-- Enables edit/delete for Member Utility Deposits, Cottage Deposits, and
-- Utility Expenses (Utilities -> Utility Details), mirroring the meal
-- module's month-details edit/delete pattern (see updateDeposit/deleteDeposit
-- in src/app/(house)/meal/actions.ts).
-- Run after 0001-0050. Safe to re-run.

-- utility_deposits already has select + insert + delete policies (0015);
-- add update so an admin can correct a deposit instead of only deleting it.
drop policy if exists "utility_deposits_admin_update" on utility_deposits;
create policy "utility_deposits_admin_update" on utility_deposits
  for update to authenticated using (
    is_super_admin()
    and cottage_id = current_cottage_id()
    and not is_month_closed(cottage_id, (month_key || '-01')::date)
  );

-- Link each Member/Cottage Deposit's Cottage Balance transaction back to the
-- deposit so it can be kept in sync on edit and removed automatically when
-- the deposit is deleted (instead of leaving a stale balance entry behind).
alter table cottage_balance_transactions
  add column if not exists related_deposit_id uuid references utility_deposits(id) on delete cascade;

-- The expense's own Cottage Balance transaction was "on delete set null",
-- which left a stale (undeleted) balance entry when an expense was removed.
-- Switch it to cascade so deleting an expense also removes its transaction.
alter table cottage_balance_transactions
  drop constraint if exists cottage_balance_transactions_related_expense_id_fkey;
alter table cottage_balance_transactions
  add constraint cottage_balance_transactions_related_expense_id_fkey
  foreign key (related_expense_id) references expenses(id) on delete cascade;

-- Link a "paid by member" expense's due-credit adjustment back to the
-- expense so it can be kept in sync on edit and removed on delete.
alter table utility_adjustments
  add column if not exists related_expense_id uuid references expenses(id) on delete cascade;

-- cottage_balance_transactions only had select + insert policies; add
-- update/delete so the edit/delete server actions below can keep the linked
-- transaction in sync (update) or let cascade remove it (delete).
drop policy if exists "cottage_balance_admin_update" on cottage_balance_transactions;
create policy "cottage_balance_admin_update" on cottage_balance_transactions
  for update to authenticated using (is_super_admin() and cottage_id = current_cottage_id());

drop policy if exists "cottage_balance_admin_delete" on cottage_balance_transactions;
create policy "cottage_balance_admin_delete" on cottage_balance_transactions
  for delete to authenticated using (is_super_admin() and cottage_id = current_cottage_id());

-- utility_adjustments already has admin_insert + admin_delete (0012); add
-- update for expense-edit to keep the linked member credit in sync.
drop policy if exists "utility_adjustments_admin_update" on utility_adjustments;
create policy "utility_adjustments_admin_update" on utility_adjustments
  for update to authenticated using (
    is_super_admin()
    and cottage_id = current_cottage_id()
    and not is_month_closed(cottage_id, (month_key || '-01')::date)
  );
