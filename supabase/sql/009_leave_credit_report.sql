-- Run this once in the Supabase SQL Editor, after 001-008.
--
-- Backs the new "Leave Credit Report" screen under the sidebar's Leave
-- Credits group: per employee, per (active) leave type, for a year of the
-- caller's choosing, how much credit is left. Same shape as
-- v_leave_balances (002) but parametrized by year instead of hardcoded to
-- the current one, since a view can't take arguments.
--
-- Deliberately NOT security definer, same reasoning as 003's
-- office_employee_opening_balances: it runs as the calling user, so the
-- existing SELECT policies on els_employees/els_leave_credits/etc.
-- (office-scoped for approvers, unrestricted for admins, own-row-only for
-- employees) apply exactly as they already do everywhere else -- this
-- function adds no new access, just reshapes what the caller could already
-- query table-by-table.

create or replace function public.leave_credit_report(p_year bigint)
returns table (
  employee_id bigint,
  employee_no character varying,
  full_name text,
  leave_type_id bigint,
  leave_type_name text,
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
    e.id as employee_id,
    e.employee_no,
    trim(concat_ws(' ', u.firstname, u.middlename, u.lastname)) as full_name,
    lt.id as leave_type_id,
    lt.leave_name as leave_type_name,
    coalesce(ob.opening_balance, 0) as opening_balance,
    coalesce(credits.total_earned, 0) as total_earned,
    coalesce(deductions.total_deducted, 0) as total_deducted,
    coalesce(applications.total_applied, 0) as total_applied,
    coalesce(ob.opening_balance, 0)
      + coalesce(credits.total_earned, 0)
      - coalesce(deductions.total_deducted, 0)
      - coalesce(applications.total_applied, 0) as available_balance
  from public.els_employees e
  join public.users u on u.seqid = e.users_id
  cross join public.els_leave_types lt
  left join lateral (
    select sum(opening_balance) as opening_balance
    from public.els_leave_opening_balance
    where employee_id = e.id
      and leave_type_id = lt.id
      and balance_year = p_year
  ) ob on true
  left join lateral (
    select sum(earned) as total_earned
    from public.els_leave_credits
    where employee_id = e.id
      and leave_type_id = lt.id
      and extract(year from credit_month) = p_year
  ) credits on true
  left join lateral (
    select sum(amount) as total_deducted
    from public.els_leave_deductions
    where employee_id = e.id
      and leave_type_id = lt.id
      and extract(year from deduction_date) = p_year
  ) deductions on true
  left join lateral (
    select sum(days) as total_applied
    from public.els_leave_applications
    where employee_id = e.id
      and leave_type_id = lt.id
      and status = 'APPROVED'
      and extract(year from leave_date) = p_year
  ) applications on true
  where lt.is_active
  order by u.lastname, u.firstname, lt.leave_name;
$$;

grant execute on function public.leave_credit_report(bigint) to authenticated;
