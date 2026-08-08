-- Native App Release Management & Download Analytics
-- Migration: 0046_app_releases.sql

-- 1. Create app_releases table
create table if not exists app_releases (
  id uuid primary key default gen_random_uuid(),
  platform text not null default 'android' check (platform in ('android', 'google_play', 'app_store', 'windows', 'macos', 'linux')),
  version text not null,
  channel text not null default 'beta' check (channel in ('stable', 'beta', 'alpha')),
  file_path text not null,
  file_size_bytes bigint not null default 0,
  checksum_sha256 text,
  release_notes text,
  min_supported_version text,
  status text not null default 'draft' check (status in ('active', 'archived', 'draft')),
  uploaded_by uuid references profiles(id) on delete set null,
  download_count integer not null default 0,
  created_at timestamptz not null default now(),
  published_at timestamptz
);

-- Index for fast lookup of active releases by platform and channel
create index if not exists idx_app_releases_platform_status on app_releases(platform, status, channel);
create unique index if not exists idx_app_releases_unique_version on app_releases(platform, version);

-- 2. Create app_download_logs table for analytics
create table if not exists app_download_logs (
  id uuid primary key default gen_random_uuid(),
  release_id uuid references app_releases(id) on delete cascade,
  platform text not null default 'android',
  user_agent text,
  created_at timestamptz not null default now()
);

create index if not exists idx_app_download_logs_created_at on app_download_logs(created_at);
create index if not exists idx_app_download_logs_release_id on app_download_logs(release_id);

-- 3. Function & Trigger to automatically archive previous active releases when a new release becomes active
create or replace function auto_archive_previous_active_release()
returns trigger as $$
begin
  if new.status = 'active' then
    update app_releases
    set status = 'archived'
    where platform = new.platform
      and channel = new.channel
      and id != new.id
      and status = 'active';

    if new.published_at is null then
      new.published_at := now();
    end if;
  end if;
  return new;
end;
$$ language plpgsql;

drop trigger if exists trigger_auto_archive_previous_release on app_releases;
create trigger trigger_auto_archive_previous_release
  before insert or update of status on app_releases
  for each row
  when (new.status = 'active')
  execute function auto_archive_previous_active_release();

-- 4. RPC Function to increment download count & record analytics log securely
create or replace function record_app_download(p_release_id uuid, p_user_agent text default null)
returns void as $$
begin
  update app_releases
  set download_count = download_count + 1
  where id = p_release_id;

  insert into app_download_logs (release_id, platform, user_agent)
  select p_release_id, platform, p_user_agent
  from app_releases
  where id = p_release_id;
end;
$$ language plpgsql security definer;

-- 5. RLS Policies
alter table app_releases enable row level security;
alter table app_download_logs enable row level security;

-- Public can view active releases
create policy "Public can view active releases"
  on app_releases for select
  using (status = 'active');

-- Service role & admins have full control
create policy "Admins full control on app_releases"
  on app_releases for all
  using (true)
  with check (true);

create policy "Admins full control on app_download_logs"
  on app_download_logs for all
  using (true)
  with check (true);
