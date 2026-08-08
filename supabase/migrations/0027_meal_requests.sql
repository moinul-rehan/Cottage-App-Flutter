-- Meal request/approval workflow. A general member (no can_add_meals) can
-- request a meal for a date; a manager (can_add_meals) or the super admin
-- approves it, which writes straight into daily_meals -- or rejects it.
--
-- Run after 0001-0026. Safe to re-run.

create table if not exists meal_requests (
  id uuid primary key default gen_random_uuid(),
  cottage_id uuid not null references cottages(id) on delete cascade,
  user_id uuid not null references profiles(id),
  request_date date not null,
  lunch numeric(3, 1) not null default 0 check (lunch >= 0),
  dinner numeric(3, 1) not null default 0 check (dinner >= 0),
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'cancelled')),
  reviewed_by uuid references profiles(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

-- Only one pending request per member per date.
create unique index if not exists meal_requests_pending_unique
  on meal_requests (user_id, request_date) where status = 'pending';

create index if not exists meal_requests_cottage_idx on meal_requests (cottage_id, status);

alter table meal_requests enable row level security;

drop policy if exists "meal_requests_select" on meal_requests;
create policy "meal_requests_select" on meal_requests
  for select to authenticated using (
    cottage_id = current_cottage_id()
    and (
      is_super_admin()
      or (select can_add_meals from profiles where id = auth.uid())
      or user_id = auth.uid()
    )
  );

drop policy if exists "meal_requests_insert" on meal_requests;
create policy "meal_requests_insert" on meal_requests
  for insert to authenticated with check (
    cottage_id = current_cottage_id() and user_id = auth.uid()
  );

drop policy if exists "meal_requests_update" on meal_requests;
create policy "meal_requests_update" on meal_requests
  for update to authenticated using (
    cottage_id = current_cottage_id()
    and (
      is_super_admin()
      or (select can_add_meals from profiles where id = auth.uid())
      or user_id = auth.uid()
    )
  );
