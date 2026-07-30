-- Run this once in the Supabase SQL Editor, after 001-014.
--
-- public.v_leave_balances cross-joins every els_leave_types row with no
-- is_active filter, unlike leave_credit_report (009) which already has
-- `where lt.is_active`. That's why the employee's own Leave Balance page
-- (LeaveService.fetchCurrentEmployeeBalances, lib/services/leave_service.dart)
-- lists every leave type, including inactive ones like Adoption Leave and
-- Solo Parent Leave that were never meant to be employee-facing. Adding the
-- same filter here brings it in line with leave_credit_report.
--
-- Otherwise identical to 014's version of this view (the credit_month
-- usage-delay filter stays).

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
    and credit_month < date_trunc('month', now())
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
