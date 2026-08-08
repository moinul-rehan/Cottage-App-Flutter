-- "Feedback to developer": any member can report a bug with an optional
-- screenshot. Members see only their own submissions; the super admin sees
-- every submission in the cottage, which doubles as the review view (no
-- separate admin page needed).
-- Run after 0001-0030. Safe to re-run.

create table if not exists developer_feedback (
  id uuid primary key default gen_random_uuid(),
  cottage_id uuid not null references cottages(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,

  title text not null check (char_length(trim(title)) > 0),
  description text not null check (char_length(trim(description)) > 0),
  image_url text,

  created_at timestamptz not null default now()
);

create index if not exists developer_feedback_cottage_idx on developer_feedback (cottage_id, created_at desc);

alter table developer_feedback enable row level security;

drop policy if exists "developer_feedback_select" on developer_feedback;
create policy "developer_feedback_select" on developer_feedback
  for select to authenticated using (
    cottage_id = current_cottage_id()
    and (is_super_admin() or user_id = auth.uid())
  );

drop policy if exists "developer_feedback_insert" on developer_feedback;
create policy "developer_feedback_insert" on developer_feedback
  for insert to authenticated with check (
    cottage_id = current_cottage_id() and user_id = auth.uid()
  );

-- No update/delete policy: a bug report shouldn't be editable after the
-- fact - if it needs a correction, the member just files a new one.

-- ── feedback-attachments storage bucket + policies ──────────────
insert into storage.buckets (id, name, public)
values ('feedback-attachments', 'feedback-attachments', true)
on conflict (id) do nothing;

drop policy if exists "feedback_attachments_public_read" on storage.objects;
create policy "feedback_attachments_public_read" on storage.objects
  for select using (bucket_id = 'feedback-attachments');

drop policy if exists "feedback_attachments_owner_insert" on storage.objects;
create policy "feedback_attachments_owner_insert" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'feedback-attachments' and (storage.foldername(name))[1] = auth.uid()::text
  );
