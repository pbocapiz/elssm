-- Run this once in the Supabase SQL Editor, after 001-017.
--
-- New Payroll screen: per employee, per year, a 12-row table (Jan-Dec) of
-- 1st/2nd quincena (half-month pay period) amounts, plus their total.
-- Employees can only view their own; Approvers/Admins can enter it.

-- ============================================================================
-- 1. public.els_payroll
-- ============================================================================

create table if not exists public.els_payroll (
  id bigint generated always as identity primary key,
  employee_id bigint not null references public.els_employees (id),
  year bigint not null,
  month smallint not null check (month between 1 and 12),
  first_quincena numeric not null default 0,
  second_quincena numeric not null default 0,
  created_at timestamptz not null default now(),
  unique (employee_id, year, month)
);

alter table public.els_payroll enable row level security;

-- ============================================================================
-- 2. RLS: employees view their own rows; approvers view + enter rows for
--    accesslevel-3 employees in their own office; admins manage all --
--    same three-tier shape as every other leave-ledger table (002).
-- ============================================================================

drop policy if exists "Employees can view own payroll" on public.els_payroll;
create policy "Employees can view own payroll"
  on public.els_payroll for select
  using (employee_id = public.current_employee_id());

drop policy if exists "Approvers can view office payroll" on public.els_payroll;
create policy "Approvers can view office payroll"
  on public.els_payroll for select
  using (
    public.current_access_level() = 2
    and employee_id in (
      select e.id from public.els_employees e
      join public.users u on u.seqid = e.users_id
      where u.officeid = public.current_office_id()
    )
  );

drop policy if exists "Approvers can enter office payroll" on public.els_payroll;
create policy "Approvers can enter office payroll"
  on public.els_payroll for insert
  with check (
    public.current_access_level() = 2
    and employee_id in (
      select e.id from public.els_employees e
      join public.users u on u.seqid = e.users_id
      where u.officeid = public.current_office_id()
        and u.accesslevel = 3
    )
  );

drop policy if exists "Approvers can update office payroll" on public.els_payroll;
create policy "Approvers can update office payroll"
  on public.els_payroll for update
  using (
    public.current_access_level() = 2
    and employee_id in (
      select e.id from public.els_employees e
      join public.users u on u.seqid = e.users_id
      where u.officeid = public.current_office_id()
        and u.accesslevel = 3
    )
  )
  with check (
    public.current_access_level() = 2
    and employee_id in (
      select e.id from public.els_employees e
      join public.users u on u.seqid = e.users_id
      where u.officeid = public.current_office_id()
        and u.accesslevel = 3
    )
  );

drop policy if exists "Admins can manage payroll" on public.els_payroll;
create policy "Admins can manage payroll"
  on public.els_payroll for all
  using (public.current_access_level() = 1)
  with check (public.current_access_level() = 1);

-- ============================================================================
-- 3. Helper function: employees the caller can enter payroll for (their own
--    office if an Approver, every office if an Admin -- enforced by RLS on
--    els_employees/users, not by this query, same pattern as
--    office_employee_opening_balances in 003).
-- ============================================================================

create or replace function public.office_employees()
returns table (
  employee_id bigint,
  full_name text,
  employee_no character varying
)
language sql
stable
as $$
  select
    e.id as employee_id,
    trim(concat_ws(' ', u.firstname, u.middlename, u.lastname)) as full_name,
    e.employee_no
  from public.els_employees e
  join public.users u on u.seqid = e.users_id
  where u.accesslevel = 3
  order by u.lastname, u.firstname;
$$;

grant execute on function public.office_employees() to authenticated;
