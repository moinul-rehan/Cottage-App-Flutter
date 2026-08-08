-- Every member can now create notices (meal, general, emergency,
-- maintenance) without needing the can_add_notice flag granted first.
-- Utility Reminder and Personal Reminder stay super-admin-only.
--
-- Run after 0001-0024. Safe to re-run.

drop policy if exists "notices_insert" on notices;
create policy "notices_insert" on notices
  for insert to authenticated with check (
    cottage_id = current_cottage_id()
    and created_by = auth.uid()
    and (is_anonymous = false or is_super_admin())
    and (
      is_super_admin()
      or type in ('meal', 'general', 'emergency', 'maintenance')
    )
  );
