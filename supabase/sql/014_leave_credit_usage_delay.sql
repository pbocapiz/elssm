-- Run this once in the Supabase SQL Editor, after 001-013.
--
-- Leave credited in a given month isn't usable until the following month --
-- e.g. an employee whose July accrual just posted can't apply using that
-- July credit until August, even though the row already exists in
-- els_leave_credits. This affects every leave type that accrues via 008's
-- monthly cron (Vacation Leave and Sick Leave every month; Special
-- Privilege Leave and Wellness Leave on their once-a-year January bump from
-- 011) -- the rule is really about credit_month timing, not particular
-- leave types, so it's applied uniformly rather than flagged per type.
--
-- Implementation: every place that sums els_leave_credits.earned into a
-- balance now also requires credit_month < the start of the current
-- calendar month. For a past year this is always true already (every row
-- in a closed-out year necessarily predates "the start of this month"), so
-- it only actually changes anything for the current year's most recent
-- accrual -- no special-casing needed per caller.
--
-- Three call sites duplicate this total_earned subquery (v_leave_balances,
-- leave_credit_report, check_leave_application_balance); all three get the
-- same one-line filter added so the displayed balance and the enforced
-- balance never disagree.

-- ============================================================================
-- 1. public.v_leave_balances (002) -- current employee's own balance page
-- ============================================================================

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
) applications on true;

-- ============================================================================
-- 2. public.leave_credit_report (009) -- Admin/Approver report, any year
-- ============================================================================

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
      and credit_month < date_trunc('month', now())
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

-- ============================================================================
-- 3. public.check_leave_application_balance (012) -- the actual enforcement
-- ============================================================================

create or replace function public.check_leave_application_balance()
returns trigger
language plpgsql
as $$
declare
  v_available numeric;
begin
  select
    coalesce(ob.opening_balance, 0)
      + coalesce(credits.total_earned, 0)
      - coalesce(deductions.total_deducted, 0)
      - coalesce(apps.total_applied, 0)
  into v_available
  from (select 1) as dummy
  left join lateral (
    select sum(opening_balance) as opening_balance
    from public.els_leave_opening_balance
    where employee_id = new.employee_id
      and leave_type_id = new.leave_type_id
      and balance_year = extract(year from new.leave_date)
  ) ob on true
  left join lateral (
    select sum(earned) as total_earned
    from public.els_leave_credits
    where employee_id = new.employee_id
      and leave_type_id = new.leave_type_id
      and extract(year from credit_month) = extract(year from new.leave_date)
      and credit_month < date_trunc('month', now())
  ) credits on true
  left join lateral (
    select sum(amount) as total_deducted
    from public.els_leave_deductions
    where employee_id = new.employee_id
      and leave_type_id = new.leave_type_id
      and extract(year from deduction_date) = extract(year from new.leave_date)
  ) deductions on true
  left join lateral (
    select sum(days) as total_applied
    from public.els_leave_applications
    where employee_id = new.employee_id
      and leave_type_id = new.leave_type_id
      and status = 'APPROVED'
      and extract(year from leave_date) = extract(year from new.leave_date)
  ) apps on true;

  if new.days > coalesce(v_available, 0) then
    raise exception
      'Insufficient leave balance: % day(s) requested, % day(s) available',
      new.days, coalesce(v_available, 0)
      using errcode = '23514'; -- check_violation
  end if;

  return new;
end;
$$;
