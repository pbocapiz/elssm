-- Run this once in the Supabase SQL Editor, after 001-011.
--
-- Blocks a leave application at the database level when the employee
-- doesn't have enough available balance for that leave type/year. The app
-- already warns about this in apply_leave_dialog.dart, but that's a
-- client-side hint only -- nothing stopped a direct API call (or a bug in
-- a future screen) from inserting an over-balance application. This makes
-- it an actual constraint.
--
-- Deliberately not security definer, same reasoning as 009's
-- leave_credit_report: it runs as the inserting user, so it only reads
-- through the same RLS-scoped rows (own credits/deductions/opening
-- balance/applications) that user could already query directly -- no new
-- access granted, just enforced at insert time. Mirrors the
-- opening_balance + earned - deducted - approved formula from 002's
-- v_leave_balances, scoped to the new row's leave_date year.

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

drop trigger if exists check_leave_application_balance on public.els_leave_applications;
create trigger check_leave_application_balance
  before insert on public.els_leave_applications
  for each row
  execute function public.check_leave_application_balance();
