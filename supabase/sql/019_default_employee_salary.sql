-- Run this once in the Supabase SQL Editor, after 001-018.
--
-- Adds a default monthly salary per employee, so Payroll no longer starts
-- every month blank -- unentered months pre-fill 1st/2nd Quincena as half
-- the default salary each, and whoever enters payroll just edits it down
-- for that month's deduction instead of typing the full amount every time.
--
-- Only Admins and Approvers (for their own office) may set it -- unlike
-- gsis_no/tin_no/etc, which the employee edits about themselves (007),
-- salary isn't self-service. els_employees has no general Approver "for
-- all"/update policy today (only the employee's own self-service update
-- from 007, and Admins' `for all` from 002), so rather than widen that to
-- every column, this is a narrowly-scoped security definer function that
-- only ever touches monthly_salary.

-- ============================================================================
-- 1. New column
-- ============================================================================

alter table public.els_employees
  add column if not exists monthly_salary numeric;

-- ============================================================================
-- 2. Security definer setter, scoped to Admins (any employee) and
--    Approvers (their own office's accesslevel-3 employees only)
-- ============================================================================

create or replace function public.set_employee_salary(
  p_employee_id bigint,
  p_salary numeric
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1
    from public.els_employees e
    join public.users u on u.seqid = e.users_id
    where e.id = p_employee_id
      and u.accesslevel = 3
      and (
        public.current_access_level() = 1
        or (
          public.current_access_level() = 2
          and u.officeid = public.current_office_id()
        )
      )
  ) then
    raise exception 'Not authorized to set salary for this employee';
  end if;

  update public.els_employees
  set monthly_salary = p_salary
  where id = p_employee_id;
end;
$$;

revoke all on function public.set_employee_salary(bigint, numeric) from public;
grant execute on function public.set_employee_salary(bigint, numeric) to authenticated;

-- ============================================================================
-- 3. Extend office_employees() (018) with the new column, so the Payroll
--    screen's employee picker also gets each employee's default salary.
-- ============================================================================
-- `create or replace function` can't change a function's return columns
-- (only views allow appending columns like this) -- it has to be dropped
-- and recreated, which also drops its grants, so those are reapplied below.

drop function if exists public.office_employees();

create function public.office_employees()
returns table (
  employee_id bigint,
  full_name text,
  employee_no character varying,
  monthly_salary numeric
)
language sql
stable
as $$
  select
    e.id as employee_id,
    trim(concat_ws(' ', u.firstname, u.middlename, u.lastname)) as full_name,
    e.employee_no,
    e.monthly_salary
  from public.els_employees e
  join public.users u on u.seqid = e.users_id
  where u.accesslevel = 3
  order by u.lastname, u.firstname;
$$;

grant execute on function public.office_employees() to authenticated;
