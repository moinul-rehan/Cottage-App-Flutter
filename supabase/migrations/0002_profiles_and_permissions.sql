-- Role management + member profiles
-- Run this in the Supabase SQL editor for your project (after 0001_init.sql).

-- ── profiles: new fields ────────────────────────────────────
alter table profiles
  add column first_name text,
  add column last_name text,
  add column email text,
  add column avatar_url text,
  add column gender text check (gender in ('male', 'female', 'other')),
  add column hometown text,
  add column mobile_number text,
  add column can_add_expenses boolean not null default true;

-- Backfill first/last name from the old full_name column.
update profiles
set
  first_name = split_part(full_name, ' ', 1),
  last_name = nullif(trim(substring(full_name from position(' ' in full_name) + 1)), '')
where full_name is not null;

alter table profiles alter column first_name set not null;
alter table profiles drop column full_name;

-- ── handle_new_user: read first/last name, copy email ──────
create or replace function handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, first_name, last_name, email, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'first_name', split_part(new.email, '@', 1)),
    new.raw_user_meta_data ->> 'last_name',
    new.email,
    coalesce(new.raw_user_meta_data ->> 'role', 'member')
  );
  return new;
end;
$$ language plpgsql security definer;

-- ── self-service profile update (bypasses the admin-only RLS) ─
create or replace function update_own_profile(
  p_first_name text,
  p_last_name text,
  p_avatar_url text,
  p_gender text,
  p_hometown text,
  p_mobile_number text
)
returns void as $$
begin
  update profiles
  set
    first_name = coalesce(p_first_name, first_name),
    last_name = p_last_name,
    avatar_url = coalesce(p_avatar_url, avatar_url),
    gender = p_gender,
    hometown = p_hometown,
    mobile_number = p_mobile_number
  where id = auth.uid();
end;
$$ language plpgsql security definer;

grant execute on function update_own_profile(text, text, text, text, text, text) to authenticated;

-- Separate, narrower function for avatar uploads (fired independently of the
-- rest of the profile form) so it never clobbers other fields.
create or replace function update_own_avatar(p_avatar_url text)
returns void as $$
begin
  update profiles set avatar_url = p_avatar_url where id = auth.uid();
end;
$$ language plpgsql security definer;

grant execute on function update_own_avatar(text) to authenticated;

-- ── expenses: require can_add_expenses permission ──────────
drop policy "expenses_insert_own" on expenses;

create policy "expenses_insert_own" on expenses
  for insert to authenticated with check (
    created_by = auth.uid()
    and (is_super_admin() or (select can_add_expenses from profiles where id = auth.uid()))
  );

-- ── avatars storage bucket + policies ───────────────────────
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

create policy "avatars_public_read" on storage.objects
  for select using (bucket_id = 'avatars');

create policy "avatars_owner_insert" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "avatars_owner_update" on storage.objects
  for update to authenticated using (
    bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "avatars_owner_delete" on storage.objects
  for delete to authenticated using (
    bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text
  );
