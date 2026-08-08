-- Extends 0011's Supabase Realtime publication to the tables the web app's
-- live-refresh subscribes to (0011 only covered the mobile app's dashboard
-- feed). Existing RLS select policies (cottage_id = current_cottage_id())
-- already apply to realtime changefeeds, so no new policies are needed.
-- Run after 0001-0029. Safe to re-run (each add is a no-op if already added).

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'utility_adjustments'
  ) then
    alter publication supabase_realtime add table utility_adjustments;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'utility_deposits'
  ) then
    alter publication supabase_realtime add table utility_deposits;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'notices'
  ) then
    alter publication supabase_realtime add table notices;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'cottage_balance_transactions'
  ) then
    alter publication supabase_realtime add table cottage_balance_transactions;
  end if;
end $$;
