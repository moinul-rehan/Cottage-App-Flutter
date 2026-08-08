-- Multi-tenancy (0003_cottages_and_multitenancy.sql) added cottage_id to
-- profiles/expenses/rent_assignments/settlements and every RLS policy on
-- those tables filters by it (cottage_id = current_cottage_id()), but no
-- index was ever added for that column -- every RLS-filtered query against
-- these tables (which is nearly every page load and every save/publish
-- action in the app) does a full-table scan under the policy check. This is
-- very likely the actual source of the perceived page-load/save delay, not
-- a fixed-duration loading skeleton (there isn't one -- every loading.tsx
-- in the app is a plain Suspense fallback with no artificial timer; it
-- shows for exactly as long as the underlying data fetch takes).
-- Safe to re-run.

create index if not exists profiles_cottage_id_idx on profiles(cottage_id);
create index if not exists expenses_cottage_id_idx on expenses(cottage_id, expense_date);
create index if not exists rent_assignments_cottage_id_idx on rent_assignments(cottage_id);
create index if not exists settlements_cottage_id_idx on settlements(cottage_id);

-- Queried on every dashboard load (getMyNextBazaarDuty covers this
-- differently; this is the dismissable-popup-notice check).
create index if not exists notice_dismissals_user_idx on notice_dismissals(user_id);

-- Small table today, but platform-admin filters/sorts by these on every
-- request and it will only grow.
create index if not exists cottages_status_idx on cottages(status);
create index if not exists cottages_created_at_idx on cottages(created_at desc);
