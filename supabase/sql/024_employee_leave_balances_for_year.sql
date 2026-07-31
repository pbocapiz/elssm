-- Run this once in the Supabase SQL Editor, after 001-023.
--
-- public.v_leave_balances (from 002) is hardcoded to the current calendar
-- year (extract(year from now())), which is fine for the Dashboard's
-- "Total Leave Credits Earned" card and the Apply Leave balance check, but
-- the Leave Balance screen's "Recent Activity" table now has a Year filter
-- (matching the transaction list next to it) and needs the same breakdown
-- for an arbitrary past/future year.
--
-- This function is the same shape and math as v_leave_balances, just with
-- p_year substituted for "now()", and scoped to the caller's own employee
-- record only (self-service, not the office-wide picker pattern used by
-- 003/013's office_employee_* functions). It's deliberately NOT security
-- definer -- it runs as the calling user, so the existing "Employees can
-- view own X" SELECT policies on the four source tables apply exactly as
-- they already do everywhere else, and public.current_employee_id() scopes
-- every join to the caller regardless.

create or replace function public.current_employee_leave_balances_for_year(
  p_year bigint
)
returns table (
  leave_type_id bigint,
  leave_type_name character varying,
  monthly_credit numeric,
  opening_balance numeric,
  total_earned numeric,
  total_deducted numeric,
  total_applied numeric,
  available_balance numeric
)
language sql
stable
as $$
  select
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
  from public.els_leave_types lt
  left join lateral (
    select sum(opening_balance) as opening_balance
    from public.els_leave_opening_balance
    where employee_id = public.current_employee_id()
      and leave_type_id = lt.id
      and balance_year = p_year
  ) ob on true
  left join lateral (
    select sum(earned) as total_earned
    from public.els_leave_credits
    where employee_id = public.current_employee_id()
      and leave_type_id = lt.id
      and extract(year from credit_month) = p_year
  ) credits on true
  left join lateral (
    select sum(amount) as total_deducted
    from public.els_leave_deductions
    where employee_id = public.current_employee_id()
      and leave_type_id = lt.id
      and extract(year from deduction_date) = p_year
  ) deductions on true
  left join lateral (
    select sum(days) as total_applied
    from public.els_leave_applications
    where employee_id = public.current_employee_id()
      and leave_type_id = lt.id
      and status = 'APPROVED'
      and extract(year from leave_date) = p_year
  ) applications on true
  where lt.is_active
    and lt.leave_name <> 'Force Leave (Mandatory)'
  order by lt.id;
$$;

grant execute on function public.current_employee_leave_balances_for_year(bigint) to authenticated;
