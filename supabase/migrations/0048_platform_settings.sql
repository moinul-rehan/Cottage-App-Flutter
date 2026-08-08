-- Platform-wide settings, owner-editable (see requirePlatformOwner in
-- src/lib/platform-admin.ts). Singleton row enforced via a boolean primary
-- key that only ever accepts `true`. No RLS policies - service-role only,
-- matching platform_moderators/app_releases.
create table platform_settings (
  id boolean primary key default true check (id),
  auto_approve_cottages boolean not null default false,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null
);

insert into platform_settings (id) values (true);

alter table platform_settings enable row level security;

-- Both cottage-creation paths (handle_new_user for email/password signup,
-- create_cottage_for_current_user for Google OAuth signup) consult this so
-- a new cottage is born pre-approved when the owner has turned auto-approval
-- on, instead of always defaulting to 'pending'.

create or replace function handle_new_user()
returns trigger as $$
declare
  v_mode text := new.raw_user_meta_data ->> 'mode';
  v_cottage_id uuid;
  v_auto_approve boolean;
begin
  if v_mode = 'create_cottage' then
    select auto_approve_cottages into v_auto_approve from platform_settings limit 1;

    insert into public.cottages (name, created_by, status, approved_at)
    values (
      coalesce(new.raw_user_meta_data ->> 'cottage_name', 'My Cottage'),
      new.id,
      case when coalesce(v_auto_approve, false) then 'approved' else 'pending' end,
      case when coalesce(v_auto_approve, false) then now() else null end
    )
    returning id into v_cottage_id;

    insert into public.profiles (id, cottage_id, first_name, last_name, email, role)
    values (
      new.id,
      v_cottage_id,
      coalesce(new.raw_user_meta_data ->> 'first_name', split_part(new.email, '@', 1)),
      new.raw_user_meta_data ->> 'last_name',
      new.email,
      'super_admin'
    );
  elsif v_mode = 'join_cottage' then
    insert into public.profiles (id, cottage_id, first_name, last_name, email, role)
    values (
      new.id,
      (new.raw_user_meta_data ->> 'cottage_id')::uuid,
      coalesce(new.raw_user_meta_data ->> 'first_name', split_part(new.email, '@', 1)),
      new.raw_user_meta_data ->> 'last_name',
      new.email,
      coalesce(new.raw_user_meta_data ->> 'role', 'member')
    );
  end if;
  return new;
end;
$$ language plpgsql security definer;

create or replace function create_cottage_for_current_user(
  p_cottage_name text,
  p_first_name text,
  p_last_name text
)
returns void as $$
declare
  v_cottage_id uuid;
  v_email text;
  v_auto_approve boolean;
begin
  if exists (select 1 from profiles where id = auth.uid()) then
    return;
  end if;

  select email into v_email from auth.users where id = auth.uid();
  select auto_approve_cottages into v_auto_approve from platform_settings limit 1;

  insert into cottages (name, created_by, status, approved_at)
  values (
    coalesce(p_cottage_name, 'My Cottage'),
    auth.uid(),
    case when coalesce(v_auto_approve, false) then 'approved' else 'pending' end,
    case when coalesce(v_auto_approve, false) then now() else null end
  )
  returning id into v_cottage_id;

  insert into profiles (id, cottage_id, first_name, last_name, email, role)
  values (
    auth.uid(),
    v_cottage_id,
    coalesce(p_first_name, split_part(v_email, '@', 1)),
    p_last_name,
    v_email,
    'super_admin'
  );
end;
$$ language plpgsql security definer;
