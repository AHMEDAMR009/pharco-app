-- Pharco Expenses — initial schema
-- Rebuilds the domain from the decompiled ABP backend (Pharco.Application.dll)
-- as a Postgres schema for Supabase.

-- ============================================================
-- Lookup / geography tables
-- ============================================================

create table public.governorates (
  id bigint generated always as identity primary key,
  name_en text not null,
  name_ar text
);

create table public.cities (
  id bigint generated always as identity primary key,
  governorate_id bigint not null references public.governorates(id),
  name_en text not null,
  name_ar text,
  latitude double precision not null,
  longitude double precision not null
);

create table public.companies (
  id bigint generated always as identity primary key,
  name text not null
);

create table public.lines (
  id bigint generated always as identity primary key,
  company_id bigint not null references public.companies(id),
  name text not null
);

create table public.territories (
  id bigint generated always as identity primary key,
  line_id bigint not null references public.lines(id),
  name text not null,
  code_box text
);

-- monthly_limitation = max travel requests/month for employees in this brick
create table public.bricks (
  id bigint generated always as identity primary key,
  name text not null,
  code text,
  monthly_limitation int not null default 14,
  brick_type smallint not null default 0
);

create table public.territory_bricks (
  id bigint generated always as identity primary key,
  territory_id bigint not null references public.territories(id) on delete cascade,
  brick_id bigint not null references public.bricks(id) on delete cascade,
  unique (territory_id, brick_id)
);

create table public.titles (
  id bigint generated always as identity primary key,
  name text not null,
  meal_cost numeric(10,2) not null default 0
);

-- Global reimbursement policy (kept as a single-row table, distinct from
-- the per-brick monthly_limitation above).
create table public.reimbursement_policy (
  id bigint generated always as identity primary key,
  minimum_km numeric(10,2) not null default 27,
  price_per_km numeric(10,2) not null default 1
);
insert into public.reimbursement_policy (minimum_km, price_per_km) values (27, 2.75);

-- ============================================================
-- Employees (1:1 with an auth.users row)
-- ============================================================

create table public.employees (
  id uuid primary key references auth.users(id) on delete cascade,
  code text unique not null,
  full_name text not null,
  email text, -- real contact email, optional; login uses `code`, not this field
  phone text,
  title_id bigint references public.titles(id),
  territory_id bigint references public.territories(id),
  governorate_id bigint references public.governorates(id),
  manager_id uuid references public.employees(id),
  -- 0 = individual rep (no direct reports), 1 = first-line manager,
  -- 2 = second-level manager, 3 = direct/top-level manager
  manager_type smallint not null default 0,
  home_latitude double precision,
  home_longitude double precision,
  validate_location boolean,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create index employees_manager_id_idx on public.employees(manager_id);

-- ============================================================
-- Distance cache (mirrors the Distance memoization table)
-- ============================================================

create table public.distances (
  id bigint generated always as identity primary key,
  from_city_id bigint references public.cities(id),
  to_city_id bigint references public.cities(id),
  employee_id uuid references public.employees(id), -- set when one endpoint is the employee's home
  kms numeric(10,2) not null,
  created_at timestamptz not null default now()
);

-- ============================================================
-- Requests (the core travel/expense claim)
-- ============================================================

-- request_type: 1 FieldVisit, 2 Training, 3 GroupMeeting, 4 Standalone, 5 OfficeMeeting
-- request_status: 1 Pending, 2 Approved, 3 Declined, 5 PendingSecondApproval
--   (there is no "Draft" status here — Create() and Confirm() from the
--   original two-step mobile flow are combined into one atomic submit)
create table public.requests (
  id bigint generated always as identity primary key,
  employee_id uuid not null references public.employees(id),
  request_type smallint not null,
  request_status smallint not null default 1,

  first_from_city_id bigint references public.cities(id),
  first_to_city_id bigint references public.cities(id),
  first_date_travel date not null,

  second_from_city_id bigint references public.cities(id),
  second_to_city_id bigint references public.cities(id),
  second_date_travel date not null,

  travel_distance numeric(10,2) not null default 0,
  return_distance numeric(10,2) not null default 0,
  final_distance numeric(10,2) not null default 0,

  meals_count int not null default 0,
  extra_cost numeric(10,2) not null default 0,
  request_amount numeric(10,2) not null default 0,

  notes text, -- decline/rejection reason
  approval_or_decline_time timestamptz,

  is_deleted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index requests_employee_id_idx on public.requests(employee_id);
create index requests_status_idx on public.requests(request_status);

-- extra_cost_type: 1 CarParking, 2 TollGate, 3 Tickets, 4 Allowance, 5 UberReceipts
create table public.request_extra_costs (
  id bigint generated always as identity primary key,
  request_id bigint not null references public.requests(id) on delete cascade,
  extra_cost_type smallint not null,
  extra_cost numeric(10,2) not null,
  invoice_image text, -- storage object path
  is_checked boolean not null default true, -- manager accepts/rejects this line at approval time
  created_at timestamptz not null default now()
);

create index request_extra_costs_request_id_idx on public.request_extra_costs(request_id);

-- ============================================================
-- Helper functions for the manager-approval hierarchy
-- ============================================================

create or replace function public.current_employee_id()
returns uuid language sql stable as $$
  select auth.uid();
$$;

-- true if `manager` (by employee id) can see/act on requests belonging to `emp`
-- `security definer` is required: this function queries the RLS-protected
-- `employees` table, and without it, evaluating the employees/requests
-- policies would re-trigger this same function recursively (Postgres error
-- "stack depth limit exceeded"). Running as the function's owner (who owns
-- the table) bypasses RLS inside this function only.
create or replace function public.is_manager_of(manager uuid, emp uuid)
returns boolean language sql stable security definer set search_path = public as $$
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

-- ============================================================
-- Row Level Security
-- ============================================================

alter table public.employees enable row level security;
alter table public.requests enable row level security;
alter table public.request_extra_costs enable row level security;
alter table public.governorates enable row level security;
alter table public.cities enable row level security;
alter table public.companies enable row level security;
alter table public.lines enable row level security;
alter table public.territories enable row level security;
alter table public.bricks enable row level security;
alter table public.territory_bricks enable row level security;
alter table public.titles enable row level security;
alter table public.reimbursement_policy enable row level security;
alter table public.distances enable row level security;

-- Lookups: readable by any authenticated user
create policy "lookups readable" on public.governorates for select using (auth.role() = 'authenticated');
create policy "lookups readable" on public.cities for select using (auth.role() = 'authenticated');
create policy "lookups readable" on public.companies for select using (auth.role() = 'authenticated');
create policy "lookups readable" on public.lines for select using (auth.role() = 'authenticated');
create policy "lookups readable" on public.territories for select using (auth.role() = 'authenticated');
create policy "lookups readable" on public.bricks for select using (auth.role() = 'authenticated');
create policy "lookups readable" on public.territory_bricks for select using (auth.role() = 'authenticated');
create policy "lookups readable" on public.titles for select using (auth.role() = 'authenticated');
create policy "lookups readable" on public.reimbursement_policy for select using (auth.role() = 'authenticated');
create policy "distances readable" on public.distances for select using (auth.role() = 'authenticated');
create policy "distances insertable" on public.distances for insert with check (auth.role() = 'authenticated');

-- Employees: can read own row, own manager chain, and reports (direct + indirect for tier-2 managers)
create policy "employee reads self" on public.employees
  for select using (
    id = auth.uid()
    or public.is_manager_of(auth.uid(), id)
  );

create policy "employee updates self" on public.employees
  for update using (id = auth.uid());

-- Requests: employee sees/creates own; managers see + update their reports' requests
create policy "own requests select" on public.requests
  for select using (
    employee_id = auth.uid()
    or public.is_manager_of(auth.uid(), employee_id)
  );

create policy "own requests insert" on public.requests
  for insert with check (employee_id = auth.uid());

create policy "own requests update" on public.requests
  for update using (
    employee_id = auth.uid()
    or public.is_manager_of(auth.uid(), employee_id)
  );

-- Extra costs follow the parent request's visibility
create policy "extra costs select" on public.request_extra_costs
  for select using (
    exists (
      select 1 from public.requests r
      where r.id = request_id
        and (r.employee_id = auth.uid() or public.is_manager_of(auth.uid(), r.employee_id))
    )
  );

create policy "extra costs insert" on public.request_extra_costs
  for insert with check (
    exists (
      select 1 from public.requests r
      where r.id = request_id and r.employee_id = auth.uid()
    )
  );

create policy "extra costs update" on public.request_extra_costs
  for update using (
    exists (
      select 1 from public.requests r
      where r.id = request_id
        and (r.employee_id = auth.uid() or public.is_manager_of(auth.uid(), r.employee_id))
    )
  );

-- Storage bucket for receipt images
insert into storage.buckets (id, name, public) values ('receipts', 'receipts', true)
  on conflict (id) do nothing;

create policy "receipts read" on storage.objects for select using (bucket_id = 'receipts');
create policy "receipts upload" on storage.objects for insert with check (bucket_id = 'receipts' and auth.role() = 'authenticated');
