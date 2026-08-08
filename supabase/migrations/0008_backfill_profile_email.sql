-- Backfill any profiles.email left null (e.g. an account created before
-- migration 0002 added the column, or a row that never got updated) from
-- auth.users, which always has it. Safe to re-run.
update profiles p
set email = u.email
from auth.users u
where p.id = u.id and p.email is null;
