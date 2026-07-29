-- Run this once in the Supabase SQL Editor, after 001_users_table_and_confirm_trigger.sql.
--
-- Builds out the ESSLMS business layer on top of the existing tables
-- (public.users, public.gl_offices, public.els_employees,
-- public.els_leave_credits, public.els_leave_applications,
-- public.els_leave_deductions, public.els_leave_opening_balance):
--
--   1. public.els_leave_types      -- was referenced everywhere but never defined
--   2. Missing constraints         -- els_employees.users_id -> users.seqid
--   3. Access-level helper functions (accesslevel: 1=Admin, 2=Approver, 3=Employee)
--   4. Row Level Security policies for every table
--   5. public.v_user_profiles      -- users + resolved office name, for the app's
--                                       sidebar/profile screens
--   6. public.v_leave_balances     -- per employee, per leave type, per year:
--                                       opening_balance + earned - deducted - approved
--
-- Note: users.officeid (int) is joined to gl_offices.officeid (bigint) -- NOT
-- gl_offices.id, which is a separate internal identifier. No FK constraint is
-- added for that link yet since office data may not be fully populated;
-- add one later with `... references gl_offices (officeid) not valid` once
-- you've confirmed every officeid in use has a matching gl_offices row.

-- ============================================================================
-- 1. els_leave_types
-- ============================================================================
-- This table already existed with columns: id, leave_name, monthly_credit,
-- created_at. Only adding is_active (soft-disable a leave type later
-- without deleting historical records that still reference it). No unique
-- constraint exists on leave_name, so the seed insert below guards against
-- duplicates with a NOT EXISTS check instead of ON CONFLICT.

alter table public.els_leave_types
  add column if not exists is_active boolean not null default true;

insert into public.els_leave_types (leave_name, monthly_credit)
select v.leave_name, v.monthly_credit
from (
  values
    ('Vacation Leave', 1.25),
    ('Sick Leave', 1.25),
    ('Special Privilege Leave', 0),
    ('Maternity Leave', 0),
    ('Paternity Leave', 0),
    ('Special Leave Benefits for Women', 0),
    ('Solo Parent Leave', 0),
    ('Study Leave', 0),
    ('Rehabilitation Leave', 0),
    ('Special Emergency (Calamity) Leave', 0),
    ('Adoption Leave', 0),
    ('Force Leave (Mandatory)', 0)
) as v(leave_name, monthly_credit)
where not exists (
  select 1 from public.els_leave_types existing
  where existing.leave_name = v.leave_name
);

-- ============================================================================
-- 2. Missing constraints
-- ============================================================================

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'users_seqid_key') then
    alter table public.users add constraint users_seqid_key unique (seqid);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'els_employees_users_id_fkey'
  ) then
    alter table public.els_employees
      add constraint els_employees_users_id_fkey
      foreign key (users_id) references public.users (seqid) on delete cascade;
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'els_leave_applications_status_check'
  ) then
    alter table public.els_leave_applications
      add constraint els_leave_applications_status_check
      check (status in ('PENDING', 'APPROVED', 'REJECTED', 'CANCELLED'));
  end if;
end $$;

-- ============================================================================
-- 3. Access-level helper functions
-- ============================================================================
-- security definer + fixed search_path so these can be safely called from
-- inside RLS policies without recursing back through RLS themselves.

create or replace function public.current_access_level()
returns int
language sql stable security definer set search_path = public
as $$
  select accesslevel from public.users where id = auth.uid();
$$;

create or replace function public.current_office_id()
returns int
language sql stable security definer set search_path = public
as $$
  select officeid from public.users where id = auth.uid();
$$;

create or replace function public.current_employee_id()
returns bigint
language sql stable security definer set search_path = public
as $$
  select e.id
  from public.els_employees e
  join public.users u on u.seqid = e.users_id
  where u.id = auth.uid();
$$;

grant execute on function public.current_access_level() to authenticated;
grant execute on function public.current_office_id() to authenticated;
grant execute on function public.current_employee_id() to authenticated;

-- ============================================================================
-- 4. Row Level Security
-- ============================================================================

-- public.users: extend the existing "own row" policies (from 001) with
-- office-wide/global visibility for approvers and admins.
alter table public.users enable row level security;

drop policy if exists "Admins can view all users" on public.users;
create policy "Admins can view all users"
  on public.users for select
  using (public.current_access_level() = 1);

drop policy if exists "Admins can update all users" on public.users;
create policy "Admins can update all users"
  on public.users for update
  using (public.current_access_level() = 1);

drop policy if exists "Approvers can view office users" on public.users;
create policy "Approvers can view office users"
  on public.users for select
  using (
    public.current_access_level() = 2
    and officeid = public.current_office_id()
  );

-- public.gl_offices: read-only lookup table for any signed-in user.
alter table public.gl_offices enable row level security;

drop policy if exists "Authenticated users can view offices" on public.gl_offices;
create policy "Authenticated users can view offices"
  on public.gl_offices for select
  using (auth.role() = 'authenticated');

drop policy if exists "Admins can manage offices" on public.gl_offices;
create policy "Admins can manage offices"
  on public.gl_offices for all
  using (public.current_access_level() = 1)
  with check (public.current_access_level() = 1);

-- public.els_leave_types: read-only lookup table for any signed-in user.
alter table public.els_leave_types enable row level security;

drop policy if exists "Authenticated users can view leave types" on public.els_leave_types;
create policy "Authenticated users can view leave types"
  on public.els_leave_types for select
  using (auth.role() = 'authenticated');

drop policy if exists "Admins can manage leave types" on public.els_leave_types;
create policy "Admins can manage leave types"
  on public.els_leave_types for all
  using (public.current_access_level() = 1)
  with check (public.current_access_level() = 1);

-- public.els_employees
alter table public.els_employees enable row level security;

drop policy if exists "Employees can view own record" on public.els_employees;
create policy "Employees can view own record"
  on public.els_employees for select
  using (users_id = (select seqid from public.users where id = auth.uid()));

drop policy if exists "Approvers can view office employees" on public.els_employees;
create policy "Approvers can view office employees"
  on public.els_employees for select
  using (
    public.current_access_level() = 2
    and users_id in (
      select seqid from public.users where officeid = public.current_office_id()
    )
  );

drop policy if exists "Admins can manage employees" on public.els_employees;
create policy "Admins can manage employees"
  on public.els_employees for all
  using (public.current_access_level() = 1)
  with check (public.current_access_level() = 1);

-- Shared policy pattern for the four leave-ledger tables: employees read
-- their own rows, approvers read their office's rows, admins manage all.
-- els_leave_applications additionally lets employees insert their own.

alter table public.els_leave_credits enable row level security;

drop policy if exists "Employees can view own credits" on public.els_leave_credits;
create policy "Employees can view own credits"
  on public.els_leave_credits for select
  using (employee_id = public.current_employee_id());

drop policy if exists "Approvers can view office credits" on public.els_leave_credits;
create policy "Approvers can view office credits"
  on public.els_leave_credits for select
  using (
    public.current_access_level() = 2
    and employee_id in (
      select e.id from public.els_employees e
      join public.users u on u.seqid = e.users_id
      where u.officeid = public.current_office_id()
    )
  );

drop policy if exists "Admins can manage credits" on public.els_leave_credits;
create policy "Admins can manage credits"
  on public.els_leave_credits for all
  using (public.current_access_level() = 1)
  with check (public.current_access_level() = 1);

alter table public.els_leave_deductions enable row level security;

drop policy if exists "Employees can view own deductions" on public.els_leave_deductions;
create policy "Employees can view own deductions"
  on public.els_leave_deductions for select
  using (employee_id = public.current_employee_id());

drop policy if exists "Approvers can view office deductions" on public.els_leave_deductions;
create policy "Approvers can view office deductions"
  on public.els_leave_deductions for select
  using (
    public.current_access_level() = 2
    and employee_id in (
      select e.id from public.els_employees e
      join public.users u on u.seqid = e.users_id
      where u.officeid = public.current_office_id()
    )
  );

drop policy if exists "Admins can manage deductions" on public.els_leave_deductions;
create policy "Admins can manage deductions"
  on public.els_leave_deductions for all
  using (public.current_access_level() = 1)
  with check (public.current_access_level() = 1);

alter table public.els_leave_opening_balance enable row level security;

drop policy if exists "Employees can view own opening balance" on public.els_leave_opening_balance;
create policy "Employees can view own opening balance"
  on public.els_leave_opening_balance for select
  using (employee_id = public.current_employee_id());

drop policy if exists "Approvers can view office opening balance" on public.els_leave_opening_balance;
create policy "Approvers can view office opening balance"
  on public.els_leave_opening_balance for select
  using (
    public.current_access_level() = 2
    and employee_id in (
      select e.id from public.els_employees e
      join public.users u on u.seqid = e.users_id
      where u.officeid = public.current_office_id()
    )
  );

drop policy if exists "Admins can manage opening balance" on public.els_leave_opening_balance;
create policy "Admins can manage opening balance"
  on public.els_leave_opening_balance for all
  using (public.current_access_level() = 1)
  with check (public.current_access_level() = 1);

alter table public.els_leave_applications enable row level security;

drop policy if exists "Employees can view own applications" on public.els_leave_applications;
create policy "Employees can view own applications"
  on public.els_leave_applications for select
  using (employee_id = public.current_employee_id());

drop policy if exists "Employees can create own applications" on public.els_leave_applications;
create policy "Employees can create own applications"
  on public.els_leave_applications for insert
  with check (employee_id = public.current_employee_id());

drop policy if exists "Approvers can view office applications" on public.els_leave_applications;
create policy "Approvers can view office applications"
  on public.els_leave_applications for select
  using (
    public.current_access_level() = 2
    and employee_id in (
      select e.id from public.els_employees e
      join public.users u on u.seqid = e.users_id
      where u.officeid = public.current_office_id()
    )
  );

drop policy if exists "Approvers can update office applications" on public.els_leave_applications;
create policy "Approvers can update office applications"
  on public.els_leave_applications for update
  using (
    public.current_access_level() = 2
    and employee_id in (
      select e.id from public.els_employees e
      join public.users u on u.seqid = e.users_id
      where u.officeid = public.current_office_id()
    )
  );

drop policy if exists "Admins can manage applications" on public.els_leave_applications;
create policy "Admins can manage applications"
  on public.els_leave_applications for all
  using (public.current_access_level() = 1)
  with check (public.current_access_level() = 1);

-- ============================================================================
-- 5. public.v_user_profiles -- users + resolved office name
-- ============================================================================

create or replace view public.v_user_profiles
with (security_invoker = true)
as
select
  u.id,
  u.seqid,
  u.firstname,
  u.middlename,
  u.lastname,
  u.email,
  u.position,
  u.officeid,
  o.officename,
  u.accesslevel,
  u.is_active
from public.users u
left join public.gl_offices o on o.officeid = u.officeid;

-- ============================================================================
-- 6. public.v_leave_balances -- per employee, per leave type, current year
-- ============================================================================
-- available_balance = opening_balance + earned credits - deductions
--                      - days from APPROVED applications, all scoped to the
--                      current calendar year.

create or replace view public.v_leave_balances
with (security_invoker = true)
as
select
  e.id as employee_id,
  e.users_id,
  lt.id as leave_type_id,
  lt.leave_name as leave_type_name,
  lt.monthly_credit,
  coalesce(ob.opening_balance, 0) as opening_balance,
  coalesce(credits.total_earned, 0) as total_earned,
  coalesce(deductions.total_deducted, 0) as total_deducted,
  coalesce(applications.total_applied, 0) as total_applied,
  coalesce(ob.opening_balance, 0)
    + coalesce(credits.total_earned, 0)
    - coalesce(deductions.total_deducted, 0)
    - coalesce(applications.total_applied, 0) as available_balance
from public.els_employees e
cross join public.els_leave_types lt
left join lateral (
  select sum(opening_balance) as opening_balance
  from public.els_leave_opening_balance
  where employee_id = e.id
    and leave_type_id = lt.id
    and balance_year = extract(year from now())::bigint
) ob on true
left join lateral (
  select sum(earned) as total_earned
  from public.els_leave_credits
  where employee_id = e.id
    and leave_type_id = lt.id
    and extract(year from credit_month) = extract(year from now())
) credits on true
left join lateral (
  select sum(amount) as total_deducted
  from public.els_leave_deductions
  where employee_id = e.id
    and leave_type_id = lt.id
    and extract(year from deduction_date) = extract(year from now())
) deductions on true
left join lateral (
  select sum(days) as total_applied
  from public.els_leave_applications
  where employee_id = e.id
    and leave_type_id = lt.id
    and status = 'APPROVED'
    and extract(year from leave_date) = extract(year from now())
) applications on true
where lt.is_active;
