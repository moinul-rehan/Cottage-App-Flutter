-- Widen what a can_add_notice member ("manager") may create.
-- Previously (0023): meal, general only. Now: meal, general, emergency,
-- maintenance — members can flag urgent/house-maintenance issues, not just
-- meal plans and general notices. Utility Reminder and Personal Reminder
-- remain super-admin-only (Personal Reminder is admin-to-member, "pay your
-- share today" — never member-to-member).
-- Run after 0001-0023. Safe to re-run.

drop policy if exists "notices_insert" on notices;
create policy "notices_insert" on notices
  for insert to authenticated with check (
    cottage_id = current_cottage_id()
    and created_by = auth.uid()
    and (is_anonymous = false or is_super_admin())
    and (
      is_super_admin()
      or (
        (select can_add_notice from profiles where id = auth.uid())
        and type in ('meal', 'general', 'emergency', 'maintenance')
      )
    )
  );
