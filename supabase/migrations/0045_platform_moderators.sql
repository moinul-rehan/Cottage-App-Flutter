-- Platform moderators: emails granted the same cross-cottage platform-admin
-- access as PLATFORM_ADMIN_EMAILS (env-based "owner" list), EXCEPT managing
-- moderators themselves -- that stays owner-only (see requirePlatformOwner
-- in src/lib/platform-admin.ts). No RLS policies are defined on purpose:
-- this table is only ever read/written via the service-role client
-- (createAdminClient), never from a client-side or anon-key context.
create table platform_moderators (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  invited_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table platform_moderators enable row level security;
