-- Run this once in the Supabase SQL Editor, after 001-010.
--
-- Special Privilege Leave and Wellness Leave are granted once a year (on
-- the January accrual run) rather than accruing monthly like Vacation/Sick
-- Leave: Special Privilege Leave = 3 days/year, Wellness Leave = 5
-- days/year.
--
-- Reuses els_leave_types.monthly_credit's existing cross-join-every-employee
-- shape from 008 instead of adding a parallel accrual path: a new
-- yearly_credit column holds the annual amount, and
-- accrue_monthly_leave_credits() adds it to that leave type's row only when
-- the run lands in January. Every other leave type keeps yearly_credit = 0,
-- so this is a no-op for them in every month including January.

-- ============================================================================
-- 1. els_leave_types.yearly_credit
-- ============================================================================

alter table public.els_leave_types
  add column if not exists yearly_credit numeric not null default 0;

update public.els_leave_types
set yearly_credit = 3
where leave_name = 'Special Privilege Leave';

insert into public.els_leave_types (leave_name, monthly_credit, yearly_credit)
select 'Wellness Leave', 0, 5
where not exists (
  select 1 from public.els_leave_types existing
  where existing.leave_name = 'Wellness Leave'
);

-- Separate from the insert above: if a "Wellness Leave" row already existed
-- (e.g. added by hand before this migration ran) the insert's WHERE NOT
-- EXISTS made it a no-op, leaving yearly_credit at the column's default of
-- 0. This update covers that case too, same as Special Privilege Leave's
-- above.
update public.els_leave_types
set yearly_credit = 5
where leave_name = 'Wellness Leave';

-- ============================================================================
-- 2. Accrual function -- add yearly_credit in January
-- ============================================================================

create or replace function public.accrue_monthly_leave_credits()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.els_leave_credits (employee_id, leave_type_id, credit_month, earned, remarks)
  select
    e.id,
    lt.id,
    date_trunc('month', now())::date,
    lt.monthly_credit
      + case when extract(month from now()) = 1 then lt.yearly_credit else 0 end,
    'Monthly accrual'
  from public.els_employees e
  join public.users u on u.seqid = e.users_id
  cross join public.els_leave_types lt
  where u.is_active = true
    and u.accesslevel = 3
    and lt.is_active = true
  on conflict (employee_id, leave_type_id, credit_month) do nothing;
end;
$$;

-- ============================================================================
-- 3. Backfill this year's yearly credit
-- ============================================================================
-- The January run for the current year already happened (or, for Wellness
-- Leave, never existed) before this migration added yearly_credit, so
-- active employees would otherwise wait until next January to receive it.
--
-- Can't just insert at credit_month = Jan 1 with on-conflict-do-nothing:
-- Special Privilege Leave already has a Jan 1 row from that regular monthly
-- run (earned = 0, since yearly_credit didn't exist yet), and the unique
-- constraint from 008 is keyed on (employee, leave type, credit_month) --
-- the backfill would collide with it and silently no-op. Instead: dated the
-- 2nd of the current month (the monthly accrual always lands on the 1st, so
-- this never collides with it) and guarded by a NOT EXISTS on a
-- 'Yearly accrual%' row already existing for that employee/leave
-- type/year, so re-running this migration on a later date stays idempotent.

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
  and lt.yearly_credit > 0
  and not exists (
    select 1 from public.els_leave_credits c
    where c.employee_id = e.id
      and c.leave_type_id = lt.id
      and extract(year from c.credit_month) = extract(year from now())
      and c.remarks like 'Yearly accrual%'
  );
