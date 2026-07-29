-- Run this once in the Supabase SQL Editor, after 001-007.
--
-- Automates what seed_test_employee.sql previously did by hand: on the 1st
-- of every month, insert one els_leave_credits row per (active employee,
-- active leave type) worth that leave type's monthly_credit. Uses pg_cron,
-- which ships with Supabase but must be enabled once per project.
--
-- If step 1 fails with a permission error in the SQL Editor, enable it
-- instead via Dashboard -> Database -> Extensions -> search "pg_cron" ->
-- Enable, then re-run steps 2-4 below.

-- ============================================================================
-- 1. Enable pg_cron
-- ============================================================================

create extension if not exists pg_cron;

-- ============================================================================
-- 2. Unique constraint so the accrual can safely no-op on a re-run (e.g. if
--    the scheduled job fires twice, or an Admin re-runs it manually) instead
--    of double-crediting employees. De-duplicate first in case testing
--    already created repeats, then add the constraint -- same pattern as
--    003's els_leave_opening_balance constraint.
-- ============================================================================

delete from public.els_leave_credits a
using public.els_leave_credits b
where a.employee_id = b.employee_id
  and a.leave_type_id = b.leave_type_id
  and a.credit_month = b.credit_month
  and a.id < b.id;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'els_leave_credits_employee_leave_month_key'
  ) then
    alter table public.els_leave_credits
      add constraint els_leave_credits_employee_leave_month_key
      unique (employee_id, leave_type_id, credit_month);
  end if;
end $$;

-- ============================================================================
-- 3. Accrual function
-- ============================================================================
-- security definer so the monthly cron run (which has no auth.uid() /
-- request context) can insert for every employee regardless of RLS.
-- Deliberately NOT granted to authenticated/anon -- see step 4's comment.

create or replace function public.accrue_monthly_leave_credits()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.els_leave_credits (employee_id, leave_type_id, credit_month, earned, remarks)
  select e.id, lt.id, date_trunc('month', now())::date, lt.monthly_credit, 'Monthly accrual'
  from public.els_employees e
  join public.users u on u.seqid = e.users_id
  cross join public.els_leave_types lt
  where u.is_active = true
    and u.accesslevel = 3
    and lt.is_active = true
  on conflict (employee_id, leave_type_id, credit_month) do nothing;
end;
$$;

revoke all on function public.accrue_monthly_leave_credits() from public;

-- ============================================================================
-- 4. Schedule it for 00:00 on the 1st of every month
-- ============================================================================
-- Runs as the role that owns the cron job (postgres), not as any app user,
-- so it isn't reachable from the client the way RPCs granted to
-- `authenticated` are -- there's no way for a signed-in user to trigger it
-- early or repeatedly from the app.

do $$
begin
  if exists (select 1 from cron.job where jobname = 'accrue-monthly-leave-credits') then
    perform cron.unschedule('accrue-monthly-leave-credits');
  end if;
end $$;

select cron.schedule(
  'accrue-monthly-leave-credits',
  '0 0 1 * *',
  $$select public.accrue_monthly_leave_credits();$$
);
