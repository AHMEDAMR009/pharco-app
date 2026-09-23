-- Mirrors the audit/soft-delete columns already added to requests
-- (0022_requests_audit_columns.sql) so the Employees page can support the
-- same "Modified By/On", "Deleted By/On" columns and a Delete action that
-- doesn't destroy data other tables (requests, distances, territory
-- assignments) still reference.
alter table public.employees
  add column if not exists updated_at timestamptz,
  add column if not exists updated_by text,
  add column if not exists is_deleted boolean not null default false,
  add column if not exists deleted_at timestamptz,
  add column if not exists deleted_by text;
