-- Run this once in the Supabase SQL Editor, after 001-021.
--
-- Adds Edit/Remove on the Leave Records screen (Admin/Approver) for every
-- transaction type: OPENING_BALANCE, CREDIT, DEDUCTION, and APPLICATION.
-- Admins already had full CRUD on all four source tables via 002's blanket
-- "for all" policies -- this migration is entirely about giving Approvers
-- (accesslevel = 2) matching update/delete rights on their own office's
-- rows, and about exposing each row's id through v_leave_transactions so
-- the app has something to target.
--
-- This supersedes 013's "insert-only, no update/delete" decision for
-- deductions and the read-only stance on credits/opening-balance/
-- application edits -- product now wants full management from the Leave
-- Records card, not just offsetting entries.

-- ============================================================================
-- 1. v_leave_transactions: expose the source row id for every transaction
--    type, not just APPLICATION.
-- ============================================================================
-- `create or replace view` can only append columns, but source_id already
-- exists as the last column from 005, so we're just replacing the
-- `null::bigint` placeholders with the real id -- no column shuffling.

create or replace view public.v_leave_transactions
with (security_invoker = true)
as
select
  e.id as employee_id,
  lt.id as leave_type_id,
  lt.leave_name as leave_type_name,
  'OPENING_BALANCE' as transaction_type,
  make_date(ob.balance_year::int, 1, 1) as transaction_date,
  ob.opening_balance as amount,
  null::character varying as status,
  ('Starting balance for ' || ob.balance_year) as remarks,
  trim(concat_ws(' ', u.firstname, u.middlename, u.lastname)) as employee_name,
  ob.id as source_id
from public.els_leave_opening_balance ob
join public.els_employees e on e.id = ob.employee_id
join public.users u on u.seqid = e.users_id
join public.els_leave_types lt on lt.id = ob.leave_type_id

union all

select
  e.id as employee_id,
  lt.id as leave_type_id,
  lt.leave_name as leave_type_name,
  'CREDIT' as transaction_type,
  c.credit_month as transaction_date,
  c.earned as amount,
  null::character varying as status,
  c.remarks,
  trim(concat_ws(' ', u.firstname, u.middlename, u.lastname)) as employee_name,
  c.id as source_id
from public.els_leave_credits c
join public.els_employees e on e.id = c.employee_id
join public.users u on u.seqid = e.users_id
join public.els_leave_types lt on lt.id = c.leave_type_id

union all

select
  e.id as employee_id,
  lt.id as leave_type_id,
  lt.leave_name as leave_type_name,
  'DEDUCTION' as transaction_type,
  d.deduction_date as transaction_date,
  -d.amount as amount,
  null::character varying as status,
  d.remarks,
  trim(concat_ws(' ', u.firstname, u.middlename, u.lastname)) as employee_name,
  d.id as source_id
from public.els_leave_deductions d
join public.els_employees e on e.id = d.employee_id
join public.users u on u.seqid = e.users_id
join public.els_leave_types lt on lt.id = d.leave_type_id

union all

select
  e.id as employee_id,
  lt.id as leave_type_id,
  lt.leave_name as leave_type_name,
  'APPLICATION' as transaction_type,
  a.leave_date as transaction_date,
  -a.days as amount,
  a.status,
  a.remarks,
  trim(concat_ws(' ', u.firstname, u.middlename, u.lastname)) as employee_name,
  a.id as source_id
from public.els_leave_applications a
join public.els_employees e on e.id = a.employee_id
join public.users u on u.seqid = e.users_id
join public.els_leave_types lt on lt.id = a.leave_type_id;

-- ============================================================================
-- 2. RLS: approvers can update/delete their own office's rows
-- ============================================================================
-- Scope matches each table's existing write policy: opening balance and
-- deductions were already scoped to accesslevel-3 subordinates (003, 013),
-- so the new update/delete policies keep that same boundary. Applications
-- already had an office-wide (not accesslevel-3-only) update policy from
-- 002, so its new delete policy matches that same, wider scope. Credits had
-- no approver write policy at all yet, so it gets the accesslevel-3 scope
-- to match its closest sibling (deductions).

drop policy if exists "Approvers can update office credits" on public.els_leave_credits;
create policy "Approvers can update office credits"
  on public.els_leave_credits for update
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

drop policy if exists "Approvers can delete office credits" on public.els_leave_credits;
create policy "Approvers can delete office credits"
  on public.els_leave_credits for delete
  using (
    public.current_access_level() = 2
    and employee_id in (
      select e.id from public.els_employees e
      join public.users u on u.seqid = e.users_id
      where u.officeid = public.current_office_id()
        and u.accesslevel = 3
    )
  );

drop policy if exists "Approvers can update office deductions" on public.els_leave_deductions;
create policy "Approvers can update office deductions"
  on public.els_leave_deductions for update
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

drop policy if exists "Approvers can delete office deductions" on public.els_leave_deductions;
create policy "Approvers can delete office deductions"
  on public.els_leave_deductions for delete
  using (
    public.current_access_level() = 2
    and employee_id in (
      select e.id from public.els_employees e
      join public.users u on u.seqid = e.users_id
      where u.officeid = public.current_office_id()
        and u.accesslevel = 3
    )
  );

drop policy if exists "Approvers can delete office opening balance" on public.els_leave_opening_balance;
create policy "Approvers can delete office opening balance"
  on public.els_leave_opening_balance for delete
  using (
    public.current_access_level() = 2
    and employee_id in (
      select e.id from public.els_employees e
      join public.users u on u.seqid = e.users_id
      where u.officeid = public.current_office_id()
        and u.accesslevel = 3
    )
  );

drop policy if exists "Approvers can delete office applications" on public.els_leave_applications;
create policy "Approvers can delete office applications"
  on public.els_leave_applications for delete
  using (
    public.current_access_level() = 2
    and employee_id in (
      select e.id from public.els_employees e
      join public.users u on u.seqid = e.users_id
      where u.officeid = public.current_office_id()
    )
  );

-- Note: "Approvers can update office applications" (update, office-wide
-- scope) and "Approvers can update office opening balance" (update,
-- accesslevel-3 scope) already exist from 002 and 003 respectively -- no
-- new update policy needed for those two tables.
