-- Meal cost request/approval workflow, mirroring meal_requests (0027) but
-- for bazaar spending: a general member (no can_add_bazaar) can request a
-- meal cost entry; a manager (can_add_bazaar) or the super admin approves
-- it, which inserts a bazaar entry AND credits the same amount back into
-- the requester's meal deposit via the existing add_bazaar_entry RPC
-- (p_credit_deposit = true) -- or rejects it.
--
-- Run after 0001-0027. Safe to re-run.

create table if not exists meal_cost_requests (
  id uuid primary key default gen_random_uuid(),
  cottage_id uuid not null references cottages(id) on delete cascade,
  user_id uuid not null references profiles(id),
  entry_date date not null,
  amount numeric(10, 2) not null check (amount > 0),
  description text,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'cancelled')),
  reviewed_by uuid references profiles(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists meal_cost_requests_cottage_idx on meal_cost_requests (cottage_id, status);

alter table meal_cost_requests enable row level security;

drop policy if exists "meal_cost_requests_select" on meal_cost_requests;
create policy "meal_cost_requests_select" on meal_cost_requests
  for select to authenticated using (
    cottage_id = current_cottage_id()
    and (
      is_super_admin()
      or (select can_add_bazaar from profiles where id = auth.uid())
      or user_id = auth.uid()
    )
  );

drop policy if exists "meal_cost_requests_insert" on meal_cost_requests;
create policy "meal_cost_requests_insert" on meal_cost_requests
  for insert to authenticated with check (
    cottage_id = current_cottage_id() and user_id = auth.uid()
  );

drop policy if exists "meal_cost_requests_update" on meal_cost_requests;
create policy "meal_cost_requests_update" on meal_cost_requests
  for update to authenticated using (
    cottage_id = current_cottage_id()
    and (
      is_super_admin()
      or (select can_add_bazaar from profiles where id = auth.uid())
      or user_id = auth.uid()
    )
  );
