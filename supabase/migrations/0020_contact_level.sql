-- Adds a free-text "level" (category/role) field to contacts, e.g.
-- "Landlord", "Electrician", "Plumber", "Emergency".
-- Run after 0019. Safe to re-run.

alter table contacts add column if not exists level text;
