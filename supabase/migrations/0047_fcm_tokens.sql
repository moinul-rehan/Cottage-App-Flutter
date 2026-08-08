-- Device tokens for native push (Firebase Cloud Messaging), distinct from
-- `push_subscriptions` (browser Web Push/VAPID, used by the Next.js PWA and
-- unusable by a native Android app). One row per device install; a user can
-- have several (multiple devices, or a reinstall gets a new token while the
-- stale one lingers until FCM reports it invalid and it's deleted).
create table fcm_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  token text not null unique,
  platform text not null default 'android' check (platform in ('android', 'ios')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index fcm_tokens_user_id_idx on fcm_tokens (user_id);

alter table fcm_tokens enable row level security;

-- A signed-in user may register/refresh/remove only their own device's
-- token; reading/sending (src/lib/data/push.ts) happens server-side via the
-- service-role client, same pattern as push_subscriptions.
create policy "Users manage their own FCM tokens"
  on fcm_tokens for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
