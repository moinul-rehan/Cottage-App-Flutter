-- Cottage Profile (rename) + Security/Ownership screens' backend support.
--
-- `cottages` only has a select policy (0003_cottages_and_multitenancy.sql)
-- and `profiles` only has an admin-write policy scoped to `is_super_admin()`
-- (0003) -- neither lets a plain authenticated client update `cottages.name`
-- or a member request their own account deletion. The web app covers this
-- with a service-role admin client server-side, which a distributable
-- mobile app must never embed (see MemberService.removeMember's doc
-- comment). SECURITY DEFINER RPCs, scoped to the caller the same way
-- update_own_profile is, are the mobile-safe equivalent.
--
-- `profiles.account_deletion_requested_at` and `cottages.deletion_requested_at`/
-- `deletion_requested_by` already exist from 0052/0035 -- this migration only
-- adds the RPCs, no new columns.
--
-- Run after 0052. Safe to re-run.

-- ── Cottage Profile: rename ────────────────────────────────
create or replace function update_cottage_name(p_name text)
returns void as $$
begin
  if not is_super_admin() then
    raise exception 'Only a super admin can rename the cottage.';
  end if;
  if p_name is null or length(trim(p_name)) = 0 then
    raise exception 'Cottage name cannot be empty.';
  end if;
  update cottages set name = trim(p_name) where id = current_cottage_id();
end;
$$ language plpgsql security definer;

grant execute on function update_cottage_name(text) to authenticated;

-- ── Ownership & Control: transfer super admin ──────────────
create or replace function transfer_ownership(p_new_admin_id uuid)
returns void as $$
begin
  if not is_super_admin() then
    raise exception 'Only the current super admin can transfer ownership.';
  end if;
  if p_new_admin_id = auth.uid() then
    raise exception 'You already are the super admin.';
  end if;
  if not exists (
    select 1 from profiles
    where id = p_new_admin_id and cottage_id = current_cottage_id() and is_active
  ) then
    raise exception 'Target member is not an active member of this cottage.';
  end if;

  update profiles set role = 'super_admin' where id = p_new_admin_id;
  update profiles set role = 'member' where id = auth.uid();
end;
$$ language plpgsql security definer;

grant execute on function transfer_ownership(uuid) to authenticated;

-- ── Ownership & Control: schedule/cancel cottage deletion ──
create or replace function request_cottage_deletion()
returns void as $$
begin
  if not is_super_admin() then
    raise exception 'Only a super admin can schedule cottage deletion.';
  end if;
  update cottages
  set deletion_requested_at = now(), deletion_requested_by = auth.uid()
  where id = current_cottage_id();
end;
$$ language plpgsql security definer;

grant execute on function request_cottage_deletion() to authenticated;

create or replace function cancel_cottage_deletion()
returns void as $$
begin
  if not is_super_admin() then
    raise exception 'Only a super admin can cancel cottage deletion.';
  end if;
  update cottages
  set deletion_requested_at = null, deletion_requested_by = null
  where id = current_cottage_id();
end;
$$ language plpgsql security definer;

grant execute on function cancel_cottage_deletion() to authenticated;

-- ── Security: schedule/cancel self account deletion ────────
create or replace function request_own_account_deletion()
returns void as $$
begin
  if is_super_admin() then
    raise exception 'Transfer ownership before deleting your account.';
  end if;
  update profiles set account_deletion_requested_at = now() where id = auth.uid();
end;
$$ language plpgsql security definer;

grant execute on function request_own_account_deletion() to authenticated;

create or replace function cancel_own_account_deletion()
returns void as $$
begin
  update profiles set account_deletion_requested_at = null where id = auth.uid();
end;
$$ language plpgsql security definer;

grant execute on function cancel_own_account_deletion() to authenticated;
