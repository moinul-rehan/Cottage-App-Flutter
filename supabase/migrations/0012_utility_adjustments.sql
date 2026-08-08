-- Utility statement adjustments: admin-entered category/amount lines used to
-- build each member's full utility breakdown before settlement (Utilities →
-- Generate Utility Statement). Signed amount: positive increases the
-- member's due, negative reduces it (a discount, an advance payment, etc).
-- "Paid by Cottage Balance" additionally debits the shared pool; "Paid by
-- a member" / "None" are informational only and don't create a second
-- due-adjustment beyond the signed amount itself.
-- Run after 0001-0011. Safe to re-run.

create table if not exists utility_adjustments (
  id uuid primary key default gen_random_uuid(),
  cottage_id uuid not null references cottages(id) on delete cascade,
  month_key text not null,
  user_id uuid not null references profiles(id) on delete cascade,
  category text not null,
  amount numeric not null,
  payment_source text not null check (payment_source in ('member', 'cottage_balance', 'none')),
  payment_member_id uuid references profiles(id),
  created_by uuid not null references profiles(id),
  created_at timestamptz not null default now()
);

alter table utility_adjustments enable row level security;

create index if not exists utility_adjustments_cottage_month_idx
  on utility_adjustments (cottage_id, month_key);
create index if not exists utility_adjustments_user_idx
  on utility_adjustments (user_id);

drop policy if exists "utility_adjustments_select_own_cottage" on utility_adjustments;
create policy "utility_adjustments_select_own_cottage" on utility_adjustments
  for select to authenticated using (cottage_id = current_cottage_id());

drop policy if exists "utility_adjustments_admin_insert" on utility_adjustments;
create policy "utility_adjustments_admin_insert" on utility_adjustments
  for insert to authenticated with check (
    is_super_admin()
    and cottage_id = current_cottage_id()
    and created_by = auth.uid()
    and not is_month_closed(cottage_id, (month_key || '-01')::date)
  );

drop policy if exists "utility_adjustments_admin_delete" on utility_adjustments;
create policy "utility_adjustments_admin_delete" on utility_adjustments
  for delete to authenticated using (
    is_super_admin()
    and cottage_id = current_cottage_id()
    and not is_month_closed(cottage_id, (month_key || '-01')::date)
  );
