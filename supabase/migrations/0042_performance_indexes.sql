-- Performance pass: indexes for hot-path queries that were missing
-- coverage, found while auditing why the app felt slow to load. Run after
-- 0001-0041. Safe to re-run.

-- utility_carry_ins (0004) was never indexed, despite being read inside
-- every getMonthlyDues() call (dashboard, utilities/history, statement,
-- months history).
create index if not exists utility_carry_ins_cottage_month_idx
  on utility_carry_ins(cottage_id, month_key);

-- notifications: existing (user_id, is_read) index can't serve the
-- `.order(created_at desc)` in getNotifications - every layout render pays
-- a sort. Add the column the query actually orders by.
create index if not exists notifications_user_created_idx
  on notifications(user_id, created_at desc);

-- Meal ledger record fetchers all `.eq(month_key).order(<date> desc)`, but
-- the existing composite indexes stop at (cottage_id, month_key).
create index if not exists daily_meals_month_date_idx
  on daily_meals(cottage_id, month_key, meal_date desc);

create index if not exists meal_deposits_month_date_idx
  on meal_deposits(cottage_id, month_key, deposit_date desc);

create index if not exists bazaar_entries_month_date_idx
  on bazaar_entries(cottage_id, month_key, entry_date desc);

-- utility_deposits: getUtilityDepositHistory filters by source_type too and
-- sorts by deposit_date.
create index if not exists utility_deposits_month_source_date_idx
  on utility_deposits(cottage_id, month_key, source_type, deposit_date desc);

-- bazaar_duties: getMyNextBazaarDuty filters by user_id + end_date only
-- (no cottage_id in the query), so the existing (cottage_id, user_id,
-- end_date) index's leading column is unconstrained and unusable for that
-- query. Add a matching index instead of changing the query.
create index if not exists bazaar_duties_user_end_idx
  on bazaar_duties(user_id, end_date);
