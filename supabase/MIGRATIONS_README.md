# Migrations: keeping the app and web repos in sync

Both `Cottage-App-Flutter` and `cottage-expense-tracker` (the Next.js web
app) point at the **same** Supabase project, so they must agree on every
already-applied migration -- a number reused for two different files here
would silently desync the two repos' history from what's actually on the
database.

`supabase/migrations-web-reference/` is an NTFS junction pointing straight
at `cottage-expense-tracker`'s `supabase/migrations/` folder (not a copy --
it always reflects whatever's really there, live). Before adding a new
migration to this repo:

1. Check `migrations-web-reference/` for the highest number already used by
   the web repo, and diff it against this repo's own `migrations/` folder
   (`diff -rq supabase/migrations supabase/migrations-web-reference`) --
   they should match exactly except for app-only additions like `0053`.
2. If the web repo has migrations this repo is missing, copy them in
   verbatim first (they're already applied to the database; this repo's
   copy is just for the record).
3. Only then add a new file, numbered one past whichever repo's count is
   higher.

App-only migrations exist for things the web app does via a service-role
client that a distributable mobile app can never embed (see
`0053_cottage_profile_and_ownership_rpcs.sql`'s header comment) -- those are
fine to diverge on, as long as the number doesn't collide.
