-- Run this once in the Supabase SQL Editor, after 001-019.
--
-- Splits 019's single monthly_salary into two separate defaults --
-- default_first_quincena and default_second_quincena -- instead of always
-- halving one number evenly. Real payroll isn't split 50/50: government
-- contribution deductions (GSIS, PhilHealth, Pag-IBIG, tax) are typically
-- taken out of one quincena and not the other, so the two halves need
-- independent defaults.
--
-- 019 only just introduced monthly_salary and nothing depends on it yet,
-- so it's dropped outright rather than kept alongside the new columns.

-- ============================================================================
-- 1. Replace monthly_salary with the two split columns
-- ============================================================================

alter table public.els_employees
  add column if not exists default_first_quincena numeric;

alter table public.els_employees
  add column if not exists default_second_quincena numeric;

alter table public.els_employees
  drop column if exists monthly_salary;

-- ============================================================================
-- 2. Replace set_employee_salary with a two-value setter
-- ============================================================================

drop function if exists public.set_employee_salary(bigint, numeric);

create function public.set_employee_payroll_defaults(
  p_employee_id bigint,
  p_first_quincena numeric,
  p_second_quincena numeric
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
    raise exception 'Not authorized to set payroll defaults for this employee';
  end if;

  update public.els_employees
  set default_first_quincena = p_first_quincena,
      default_second_quincena = p_second_quincena
  where id = p_employee_id;
end;
$$;

revoke all on function public.set_employee_payroll_defaults(bigint, numeric, numeric) from public;
grant execute on function public.set_employee_payroll_defaults(bigint, numeric, numeric) to authenticated;

-- ============================================================================
-- 3. office_employees(): swap monthly_salary for the two split columns
-- ============================================================================

drop function if exists public.office_employees();

create function public.office_employees()
returns table (
  employee_id bigint,
  full_name text,
  employee_no character varying,
  default_first_quincena numeric,
  default_second_quincena numeric
)
language sql
stable
as $$
  select
    e.id as employee_id,
    trim(concat_ws(' ', u.firstname, u.middlename, u.lastname)) as full_name,
    e.employee_no,
    e.default_first_quincena,
    e.default_second_quincena
  from public.els_employees e
  join public.users u on u.seqid = e.users_id
  where u.accesslevel = 3
  order by u.lastname, u.firstname;
$$;

grant execute on function public.office_employees() to authenticated;
