-- Per-account language preference (English default, Bangla optional) so it
-- follows a member across devices. Run after 0001-0043. Safe to re-run.

alter table profiles add column if not exists language text not null default 'en';

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'profiles_language_check') then
    alter table profiles add constraint profiles_language_check check (language in ('en', 'bn'));
  end if;
end $$;
