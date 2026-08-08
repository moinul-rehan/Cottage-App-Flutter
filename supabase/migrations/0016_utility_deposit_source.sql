-- Utility deposits can now come from two sources:
--   'member'   — a member paying money toward their own utility due (reduces
--                that member's due in getMonthlyDues, as before).
--   'addition' — the cottage's own previously-held money being logged into
--                the system. Not tied to any member and does not reduce
--                anyone's due; instead it's credited to the Cottage Balance
--                (see addUtilityDeposit in src/app/(house)/utilities/actions.ts).
-- Run after 0015. Safe to re-run.

alter table utility_deposits
  add column if not exists source_type text not null default 'member'
    check (source_type in ('member', 'addition'));

alter table utility_deposits
  alter column user_id drop not null;

alter table utility_deposits
  drop constraint if exists utility_deposits_source_user_check;
alter table utility_deposits
  add constraint utility_deposits_source_user_check check (
    (source_type = 'member' and user_id is not null)
    or (source_type = 'addition' and user_id is null)
  );

-- Re-create the insert policy: 'addition' rows have no user_id, so the
-- previous implicit "user_id references profiles" shape still applies, this
-- just documents that the policy doesn't need to change — cottage_id/admin
-- checks are unaffected by source_type or a null user_id.
