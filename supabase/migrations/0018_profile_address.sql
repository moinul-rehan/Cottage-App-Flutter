-- Adds a free-text Address field to profiles (distinct from room_label,
-- which is the member's room within the cottage) so the Members page can
-- show each member's full basic info. Self-editable via update_own_profile,
-- same as hometown/mobile_number.
-- Run after 0017. Safe to re-run.

alter table profiles add column if not exists address text;

-- Postgres overloads by argument list, so the old 6-arg signature would
-- otherwise linger unused alongside this one — drop it explicitly.
drop function if exists update_own_profile(text, text, text, text, text, text);

create or replace function update_own_profile(
  p_first_name text,
  p_last_name text,
  p_avatar_url text,
  p_gender text,
  p_hometown text,
  p_mobile_number text,
  p_address text
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
    mobile_number = p_mobile_number,
    address = p_address
  where id = auth.uid();
end;
$$ language plpgsql security definer;

grant execute on function update_own_profile(text, text, text, text, text, text, text) to authenticated;
