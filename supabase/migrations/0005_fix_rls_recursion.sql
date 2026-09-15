-- Fixes "stack depth limit exceeded" errors on the employees/requests RLS
-- policies. is_manager_of() queries public.employees, which is itself
-- RLS-protected — without `security definer`, evaluating the policy for one
-- row re-triggers the same policy check inside is_manager_of's own query,
-- recursing indefinitely. `security definer` makes it run as the function's
-- owner (which owns the table and therefore bypasses RLS), breaking the loop.

create or replace function public.is_manager_of(manager uuid, emp uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.employees e
    where e.id = emp
      and (
        e.manager_id = manager
        or e.manager_id in (
          select e2.id from public.employees e2 where e2.manager_id = manager
        )
      )
  );
$$;
