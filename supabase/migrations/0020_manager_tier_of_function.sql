-- RLS on public.employees only lets an employee read their own row or their
-- reports' rows (see "employee reads self" in 0001_init.sql) — not their own
-- manager's row. That silently broke the "does my chain need a second
-- approval?" check for anyone who isn't themselves a manager: the client-side
-- lookup of their manager's manager_type came back empty, not an error, so
-- the two-tier "First Approved" tab and the review-page ordering guard never
-- kicked in for plain employees.
--
-- security definer bypasses RLS the same way is_manager_of() does, but only
-- ever returns a single manager_type value — never the manager's own row.
create or replace function public.manager_tier_of(emp uuid)
returns smallint
language sql
stable
security definer
set search_path = public
as $$
  select m.manager_type
  from public.employees e
  join public.employees m on m.id = e.manager_id
  where e.id = emp;
$$;

grant execute on function public.manager_tier_of(uuid) to authenticated;
