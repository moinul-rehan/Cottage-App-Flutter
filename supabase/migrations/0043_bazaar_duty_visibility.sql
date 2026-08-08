-- Bazaar duty was only visible to its assignee (and super admins) - every
-- member should be able to see the whole cottage's duty roster, not just
-- their own. Run after 0001-0042. Safe to re-run.

drop policy if exists "bazaar_duties_select" on bazaar_duties;
create policy "bazaar_duties_select" on bazaar_duties
  for select to authenticated using (cottage_id = current_cottage_id());
