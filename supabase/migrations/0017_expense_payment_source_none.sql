-- Add Utility Expense now supports Payment Source "None" (recorded only, no
-- balance or due change) alongside the existing "Member" and "Cottage
-- Balance" options — see addExpense in src/app/(house)/utilities/actions.ts.
-- The check constraint from 0004 only allowed ('member', 'cottage_balance').
-- Run after 0016. Safe to re-run.

alter table expenses drop constraint if exists expenses_payment_source_check;
alter table expenses add constraint expenses_payment_source_check
  check (payment_source in ('member', 'cottage_balance', 'none'));
