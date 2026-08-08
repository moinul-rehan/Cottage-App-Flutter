-- Notice Board: independent communication module.
-- Never touches Meal, Utility, or Cottage Balance data — it only ever
-- displays information and, for Utility Reminder notices, references a
-- due amount/date typed in by whoever creates the notice.
-- Run after 0001-0021. Safe to re-run.

-- ── profiles: can_add_notice ─────────────────────────────────
-- Same grantable-permission pattern as can_add_expenses / can_add_bazaar /
-- can_add_meals / can_add_deposit. A permitted member may only create the
-- member-safe notice types (see the insert policy below) — Utility Reminder
-- and Emergency stay super-admin-only regardless of this flag.
alter table profiles add column if not exists can_add_notice boolean not null default false;

-- ── notices ───────────────────────────────────────────────────
create table if not exists notices (
  id uuid primary key default gen_random_uuid(),
  cottage_id uuid not null references cottages(id) on delete cascade,

  title text not null check (char_length(trim(title)) > 0),
  description text not null default '',
  type text not null check (type in ('utility', 'meal', 'general', 'emergency', 'personal', 'maintenance')),
  priority text not null default 'normal' check (priority in ('critical', 'high', 'normal', 'low')),

  visibility text not null check (visibility in ('everyone', 'specific', 'selected', 'admins')),
  target_member_ids uuid[] not null default '{}',

  is_pinned boolean not null default false,
  pin_duration text not null default 'none' check (pin_duration in ('none', 'until_manual', '1d', '3d', 'until_date', 'until_expires')),
  pin_until_date date,

  is_anonymous boolean not null default false,

  publish_at timestamptz not null default now(),
  expires_at timestamptz not null,
  archived_at timestamptz,

  -- Utility Reminder fields — Notice Board only ever displays these; it
  -- never reads or writes the real utility ledger.
  due_amount numeric(10, 2),
  due_date date,

  -- Meal Plan fields
  meal_lunch text,
  meal_dinner text,

  created_by uuid not null references profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint notices_expiry_after_publish check (expires_at > publish_at),
  constraint notices_target_required_when_scoped check (
    visibility not in ('specific', 'selected') or coalesce(array_length(target_member_ids, 1), 0) > 0
  ),
  constraint notices_visibility_matches_type check (
    (type = 'utility' and visibility in ('specific', 'selected')) or
    (type = 'personal' and visibility in ('specific', 'selected')) or
    (type = 'meal' and visibility in ('everyone', 'selected')) or
    (type = 'general' and visibility in ('everyone', 'selected')) or
    (type = 'maintenance' and visibility in ('everyone', 'selected')) or
    (type = 'emergency' and visibility in ('everyone', 'admins'))
  )
);

create index if not exists notices_cottage_publish_idx on notices (cottage_id, publish_at desc);
create index if not exists notices_cottage_pinned_idx on notices (cottage_id, is_pinned) where archived_at is null;
create index if not exists notices_target_member_ids_idx on notices using gin (target_member_ids);

alter table notices enable row level security;

drop policy if exists "notices_select" on notices;
create policy "notices_select" on notices
  for select to authenticated using (
    cottage_id = current_cottage_id()
    and (
      is_super_admin()
      or created_by = auth.uid()
      or visibility = 'everyone'
      or auth.uid() = any(target_member_ids)
    )
  );

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
        and type in ('meal', 'general', 'maintenance', 'personal')
      )
    )
  );

-- Pin/unpin/archive and edits — author or super admin, own cottage only.
drop policy if exists "notices_update" on notices;
create policy "notices_update" on notices
  for update to authenticated using (
    cottage_id = current_cottage_id()
    and (created_by = auth.uid() or is_super_admin())
  );

-- No delete policy: notices are archived (archived_at), never removed —
-- "nothing should be permanently deleted by default".
