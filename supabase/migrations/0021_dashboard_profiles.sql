-- Accounts for the new admin/company web dashboard — a separate user pool
-- from public.employees (the mobile app's employee-code logins). These are
-- real people with real emails: you (admin) or a company's point of contact,
-- created by an admin via the dashboard's own "invite user" action, never
-- self-registered.
--
-- 'admin' sees and can edit everything (settings, employees, every request,
-- including correcting a wrongly-approved/declined status).
-- 'company_viewer' can only view/export requests for their own company_id
-- (via employees -> territories -> lines -> companies) — no edit rights.
--
-- The dashboard's Next.js server reads this table with the service-role key
-- and enforces the role/company_id check in application code rather than
-- RLS, since a second RLS dimension on the existing employees/requests
-- tables would complicate policies already shared with the mobile app.
-- RLS is still enabled here so a compromised anon/browser client can only
-- ever read its own profile, never anyone else's.

create table public.dashboard_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  full_name text not null,
  role text not null check (role in ('admin', 'company_viewer')),
  company_id bigint references public.companies(id),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint company_viewer_needs_company check (
    (role = 'admin' and company_id is null) or
    (role = 'company_viewer' and company_id is not null)
  )
);

alter table public.dashboard_profiles enable row level security;

create policy "dashboard profile reads self" on public.dashboard_profiles
  for select using (id = auth.uid());
