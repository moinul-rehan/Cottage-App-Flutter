-- Every table added before migration 0010 references cottages(id) WITHOUT
-- on delete cascade (everything from 0010 onward already has it). A real
-- "delete cottage" from platform admin needs every child row to cascade
-- cleanly, so this re-points each of those foreign keys at ON DELETE
-- CASCADE. Looks up each table's actual (auto-generated) constraint name
-- via pg_constraint rather than guessing it, so this is safe to run
-- regardless of exactly how Postgres named it.
--
-- Run after 0001-0032. Safe to re-run.

do $$
declare
  t text;
  cname text;
  tables text[] := array[
    'profiles', 'expenses', 'rent_assignments', 'settlements',
    'month_closures', 'cottage_balance_transactions', 'meal_months',
    'bazaar_entries', 'meal_deposits', 'daily_meals', 'utility_carry_ins',
    'notifications'
  ];
begin
  foreach t in array tables loop
    select con.conname into cname
    from pg_constraint con
    join pg_class rel on rel.oid = con.conrelid
    join pg_attribute att on att.attrelid = con.conrelid and att.attnum = any(con.conkey)
    where rel.relname = t and con.contype = 'f' and att.attname = 'cottage_id';

    if cname is not null then
      execute format('alter table %I drop constraint %I', t, cname);
    end if;

    execute format(
      'alter table %I add constraint %I foreign key (cottage_id) references cottages(id) on delete cascade',
      t, t || '_cottage_id_fkey'
    );
  end loop;
end $$;
