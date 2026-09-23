-- A company_viewer can now be scoped to more than one company (e.g. one
-- point of contact covering several related companies), so company_id
-- becomes company_ids, an array.
alter table public.dashboard_profiles drop constraint if exists company_viewer_needs_company;

alter table public.dashboard_profiles add column if not exists company_ids bigint[];

update public.dashboard_profiles
set company_ids = array[company_id]
where company_id is not null and company_ids is null;

alter table public.dashboard_profiles drop column if exists company_id;

alter table public.dashboard_profiles add constraint company_viewer_needs_company check (
  (role = 'admin') or
  (role = 'company_viewer' and company_ids is not null and array_length(company_ids, 1) > 0)
);
