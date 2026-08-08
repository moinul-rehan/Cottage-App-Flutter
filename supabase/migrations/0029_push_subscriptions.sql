-- Web Push subscriptions, one row per device/browser a member has granted
-- notification permission on. notifyUsers() reads these (via the admin
-- client, bypassing RLS since it needs to push to OTHER users) to deliver
-- an actual device notification alongside every in-app one.
--
-- Run after 0001-0028. Safe to re-run.

create table if not exists push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  cottage_id uuid not null references cottages(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  created_at timestamptz not null default now()
);

create index if not exists push_subscriptions_user_idx on push_subscriptions(user_id);

alter table push_subscriptions enable row level security;

drop policy if exists "push_subscriptions_own" on push_subscriptions;
create policy "push_subscriptions_own" on push_subscriptions
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
