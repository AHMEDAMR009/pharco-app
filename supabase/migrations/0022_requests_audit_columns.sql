-- Audit trail columns for dashboard-driven changes to a request. The
-- mobile app's own approve/decline flow doesn't stamp who acted (only
-- approval_or_decline_time), so these are populated going forward only
-- when the admin dashboard corrects a status or deletes a request —
-- existing rows will show these as null, which is honest: we don't have
-- that history.
alter table public.requests
  add column if not exists updated_at timestamptz,
  add column if not exists updated_by text,
  add column if not exists deleted_at timestamptz,
  add column if not exists deleted_by text;
