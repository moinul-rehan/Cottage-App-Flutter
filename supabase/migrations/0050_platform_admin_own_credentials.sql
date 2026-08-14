-- Platform admin gets its own, fully independent login system: a separate
-- password (bcrypt-hashed) per email, checked against this table instead
-- of Supabase Auth. This means the SAME email can have one password for
-- signing into their Cottage (regular Supabase Auth) and a different
-- password for platform admin - logging into one no longer logs into the
-- other, since platform sessions are now a custom signed cookie (see
-- src/lib/platform-admin-auth.ts), not a Supabase Auth session.
--
-- Only ever touched via the service-role admin client from server actions
-- (see login/actions.ts, setup/actions.ts, account/actions.ts) - never via
-- the anon/authenticated Supabase client - so RLS is enabled with no
-- policies at all (implicit deny-all for anon/authenticated; service role
-- always bypasses RLS regardless).

create table if not exists platform_admin_credentials (
  email text primary key,
  password_hash text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table platform_admin_credentials enable row level security;

-- platform_moderators.invited_by used to be a uuid FK into auth.users,
-- populated from the inviting owner's Supabase Auth user id. Platform
-- owners no longer necessarily have an auth.users row at all (their
-- identity is now just an email in PLATFORM_ADMIN_EMAILS + a row in
-- platform_admin_credentials), so this switches to storing the inviter's
-- email directly as plain text - simpler, and no longer needs a
-- auth.admin.listUsers() lookup to display.
alter table platform_moderators drop constraint if exists platform_moderators_invited_by_fkey;
alter table platform_moderators alter column invited_by type text using invited_by::text;

-- Same story for platform_settings.updated_by.
alter table platform_settings drop constraint if exists platform_settings_updated_by_fkey;
alter table platform_settings alter column updated_by type text using updated_by::text;
