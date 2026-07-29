-- Run this once in the Supabase SQL Editor, after 001 and 002.
--
-- Lets an Approver (accesslevel = 2) set the starting ("opening") leave
-- credit for accesslevel-3 employees in their own office, per leave type,
-- for a year of their choosing. Admins (accesslevel = 1) already had full
-- access to this table via 002's "Admins can manage opening balance" policy.

-- ============================================================================
-- 1. Unique constraint so upserts work
-- ============================================================================
-- els_leave_opening_balance had no way to identify "the balance for this
-- employee/leave type/year" other than the surrogate id, so an upsert from
-- the app has nothing to conflict on. De-duplicate first (keep the most
-- recently created row per combo) in case testing already created repeats,
-- then add the constraint.

delete from public.els_leave_opening_balance a
using public.els_leave_opening_balance b
where a.employee_id = b.employee_id
  and a.leave_type_id = b.leave_type_id
  and a.balance_year = b.balance_year
  and a.id < b.id;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'els_leave_opening_balance_employee_leave_year_key'
  ) then
    alter table public.els_leave_opening_balance
      add constraint els_leave_opening_balance_employee_leave_year_key
      unique (employee_id, leave_type_id, balance_year);
  end if;
end $$;

-- ============================================================================
-- 2. RLS: approvers can insert/update opening balances for accesslevel-3
--    employees in their own office
-- ============================================================================

drop policy if exists "Approvers can set office opening balance" on public.els_leave_opening_balance;
create policy "Approvers can set office opening balance"
  on public.els_leave_opening_balance for insert
  with check (
    public.current_access_level() = 2
    and employee_id in (
      select e.id from public.els_employees e
      join public.users u on u.seqid = e.users_id
      where u.officeid = public.current_office_id()
        and u.accesslevel = 3
    )
  );

drop policy if exists "Approvers can update office opening balance" on public.els_leave_opening_balance;
create policy "Approvers can update office opening balance"
  on public.els_leave_opening_balance for update
  using (
    public.current_access_level() = 2
    and employee_id in (
      select e.id from public.els_employees e
      join public.users u on u.seqid = e.users_id
      where u.officeid = public.current_office_id()
        and u.accesslevel = 3
    )
  )
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
-- 3. Helper function: an approver's (or admin's) manageable employees, with
--    their current opening balance for a given leave type + year
-- ============================================================================
-- Deliberately NOT security definer: it runs as the calling user, so the
-- existing SELECT policies on els_employees/users (office-scoped for
-- approvers, unrestricted for admins) apply exactly as they already do
-- everywhere else.

create or replace function public.office_employee_opening_balances(
  p_leave_type_id bigint,
  p_year bigint
)
returns table (
  employee_id bigint,
  full_name text,
  employee_no character varying,
  opening_balance numeric
)
language sql
stable
as $$
  select
    e.id as employee_id,
    trim(concat_ws(' ', u.firstname, u.middlename, u.lastname)) as full_name,
    e.employee_no,
    coalesce(ob.opening_balance, 0) as opening_balance
  from public.els_employees e
  join public.users u on u.seqid = e.users_id
  left join public.els_leave_opening_balance ob
    on ob.employee_id = e.id
    and ob.leave_type_id = p_leave_type_id
    and ob.balance_year = p_year
  where u.accesslevel = 3
  order by u.lastname, u.firstname;
$$;

grant execute on function public.office_employee_opening_balances(bigint, bigint) to authenticated;
