-- A third dashboard role: full access to the Requests page only (all
-- companies, all actions — same request data/permissions as 'admin') but
-- no access to Settings/Employees/Dashboard Users, unlike a true admin.
alter table public.dashboard_profiles drop constraint if exists dashboard_profiles_role_check;
alter table public.dashboard_profiles add constraint dashboard_profiles_role_check
  check (role in ('admin', 'requests_admin', 'company_viewer'));

alter table public.dashboard_profiles drop constraint if exists company_viewer_needs_company;
alter table public.dashboard_profiles add constraint company_viewer_needs_company check (
  (role in ('admin', 'requests_admin')) or
  (role = 'company_viewer' and company_ids is not null and array_length(company_ids, 1) > 0)
);
