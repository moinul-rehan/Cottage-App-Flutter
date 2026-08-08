-- Enable Supabase Realtime (Postgres logical replication over websockets)
-- on the tables the mobile app subscribes to for live sync. Existing RLS
-- select policies (cottage_id = current_cottage_id()) already apply to
-- realtime changefeeds, so no new policies are needed here.
-- Run after 0001-0010. Safe to re-run (each add is a no-op if already added).

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'daily_meals'
  ) then
    alter publication supabase_realtime add table daily_meals;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'bazaar_entries'
  ) then
    alter publication supabase_realtime add table bazaar_entries;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'expenses'
  ) then
    alter publication supabase_realtime add table expenses;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'meal_deposits'
  ) then
    alter publication supabase_realtime add table meal_deposits;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table notifications;
  end if;
end $$;
