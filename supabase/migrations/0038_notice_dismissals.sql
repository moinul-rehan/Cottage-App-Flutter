-- Tracks which member has dismissed the big attention-grabbing dashboard
-- popup for a given "everyone" notice, so it only ever shows once per
-- member. Run after 0001-0037. Safe to re-run.

create table if not exists notice_dismissals (
  notice_id uuid not null references notices(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  dismissed_at timestamptz not null default now(),
  primary key (notice_id, user_id)
);

alter table notice_dismissals enable row level security;

drop policy if exists "notice_dismissals_select_own" on notice_dismissals;
create policy "notice_dismissals_select_own" on notice_dismissals
  for select to authenticated using (user_id = auth.uid());

drop policy if exists "notice_dismissals_insert_own" on notice_dismissals;
create policy "notice_dismissals_insert_own" on notice_dismissals
  for insert to authenticated with check (user_id = auth.uid());
