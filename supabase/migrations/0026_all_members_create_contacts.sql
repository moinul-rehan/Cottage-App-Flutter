-- Every member can now create contacts, not just the super admin.
-- Deleting a contact stays super-admin-only.
--
-- Run after 0001-0025. Safe to re-run.

drop policy if exists "contacts_admin_insert" on contacts;
create policy "contacts_insert" on contacts
  for insert to authenticated with check (
    cottage_id = current_cottage_id() and created_by = auth.uid()
  );
