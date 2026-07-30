-- Run this once in the Supabase SQL Editor, after 001-012.
--
-- Lets an Approver (accesslevel = 2) record a leave deduction against
-- accesslevel-3 employees in their own office (e.g. corrections, penalties,
-- non-application usage). Admins (accesslevel = 1) already had full access
-- to this table via 002's "Admins can manage deductions" policy. Same
-- pattern as 003's approver opening-balance access: a narrowly-scoped RLS
-- insert policy plus a helper function for the picker list, instead of
-- widening the blanket "for all" policy.

-- ============================================================================
-- 1. RLS: approvers can insert deductions for accesslevel-3 employees in
--    their own office
-- ============================================================================
-- Deliberately insert-only, no update/delete -- a mis-entered deduction
-- should be corrected with an offsetting entry, not silently edited, same
-- as there's no edit path for credits or applications once recorded.

drop policy if exists "Approvers can create office deductions" on public.els_leave_deductions;
create policy "Approvers can create office deductions"
  on public.els_leave_deductions for insert
  with check (
    public.current_access_level() = 2
    and employee_id in (
      select e.id from public.els_employees e
      join public.users u on u.seqid = e.users_id
      where u.officeid = public.current_office_id()
        and u.accesslevel = 3
    )
  );

-- ============================================================================
-- 2. Helper function: an approver's (or admin's) manageable employees, with
--    their current available balance for a given leave type -- shown in the
--    picker so whoever's recording the deduction can see what's left before
--    entering an amount.
-- ============================================================================
-- Deliberately NOT security definer, same reasoning as 003's
-- office_employee_opening_balances: it runs as the calling user, so the
-- existing SELECT policies (office-scoped for approvers, unrestricted for
-- admins) on els_employees/els_leave_credits/els_leave_deductions/
-- els_leave_opening_balance/els_leave_applications apply exactly as they
-- already do everywhere else -- no new access, just reshaping what the
-- caller could already query table-by-table.

create or replace function public.office_employee_leave_balances(
  p_leave_type_id bigint
)
returns table (
  employee_id bigint,
  full_name text,
  employee_no character varying,
  available_balance numeric
)
language sql
stable
as $$
  select
    e.id as employee_id,
    trim(concat_ws(' ', u.firstname, u.middlename, u.lastname)) as full_name,
    e.employee_no,
    coalesce(ob.opening_balance, 0)
      + coalesce(credits.total_earned, 0)
      - coalesce(deductions.total_deducted, 0)
      - coalesce(applications.total_applied, 0) as available_balance
  from public.els_employees e
  join public.users u on u.seqid = e.users_id
  left join lateral (
    select sum(opening_balance) as opening_balance
    from public.els_leave_opening_balance
    where employee_id = e.id
      and leave_type_id = p_leave_type_id
      and balance_year = extract(year from now())
  ) ob on true
  left join lateral (
    select sum(earned) as total_earned
    from public.els_leave_credits
    where employee_id = e.id
      and leave_type_id = p_leave_type_id
      and extract(year from credit_month) = extract(year from now())
  ) credits on true
  left join lateral (
    select sum(amount) as total_deducted
    from public.els_leave_deductions
    where employee_id = e.id
      and leave_type_id = p_leave_type_id
      and extract(year from deduction_date) = extract(year from now())
  ) deductions on true
  left join lateral (
    select sum(days) as total_applied
    from public.els_leave_applications
    where employee_id = e.id
      and leave_type_id = p_leave_type_id
      and status = 'APPROVED'
      and extract(year from leave_date) = extract(year from now())
  ) applications on true
  where u.accesslevel = 3
  order by u.lastname, u.firstname;
$$;

grant execute on function public.office_employee_leave_balances(bigint) to authenticated;
