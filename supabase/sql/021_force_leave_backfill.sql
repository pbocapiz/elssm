-- Run this once in the Supabase SQL Editor, after 001-020.
--
-- Force Leave (Mandatory) was activated by 017, after this year's January
-- accrual run already happened -- the exact same gap Wellness Leave hit in
-- 011 when it was activated mid-year. Its 5-day yearly_credit was never
-- posted to els_leave_credits for the current year, so its
-- available_balance (and therefore Overall Available Balance on the Leave
-- Balance page, which sums every active leave type) shows 0 instead of 5.
--
-- One-time backfill, same pattern as 011's section 3: dated to the 2nd of
-- the current month (the monthly cron always posts on the 1st, so this
-- never collides with it), guarded by a NOT EXISTS on a 'Yearly accrual%'
-- row already existing this year, so re-running this file is safe. Scoped
-- to Force Leave (Mandatory) specifically -- Special Privilege Leave and
-- Wellness Leave already got their backfill from 011 and shouldn't be
-- touched again.

insert into public.els_leave_credits (employee_id, leave_type_id, credit_month, earned, remarks)
select
  e.id,
  lt.id,
  (date_trunc('month', now()) + interval '1 day')::date,
  lt.yearly_credit,
  'Yearly accrual (backfill)'
from public.els_employees e
join public.users u on u.seqid = e.users_id
cross join public.els_leave_types lt
where u.is_active = true
  and u.accesslevel = 3
  and lt.is_active = true
  and lt.leave_name = 'Force Leave (Mandatory)'
  and lt.yearly_credit > 0
  and not exists (
    select 1 from public.els_leave_credits c
    where c.employee_id = e.id
      and c.leave_type_id = lt.id
      and extract(year from c.credit_month) = extract(year from now())
      and c.remarks like 'Yearly accrual%'
  );
