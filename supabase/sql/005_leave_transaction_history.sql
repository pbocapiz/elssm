-- Run this once in the Supabase SQL Editor, after 001-004.
--
-- public.v_leave_transactions unifies els_leave_opening_balance,
-- els_leave_credits, els_leave_deductions, and els_leave_applications into
-- one chronological log per employee, for two app views:
--   - the employee's own "Leave Balance" history (filtered to their own
--     employee_id, filterable by leave type)
--   - the Admin/Approver "Leave Records" screen (no employee_id filter --
--     RLS on the source tables scopes it to the caller's office, or every
--     office for Admins), which is why employee_name is included here, and
--     which lets an Admin/Approver approve or reject a PENDING application
--     directly from that screen using source_id (see below).
--
-- Opening balances and credits are positive amounts, deductions and
-- applications are negative (days "spent"). Applications carry their
-- status (PENDING/APPROVED/REJECTED/CANCELLED) so the UI can show it even
-- though this list isn't used for balance math (public.v_leave_balances
-- still only counts APPROVED applications toward the running balance).
--
-- source_id is els_leave_applications.id for APPLICATION rows and null for
-- every other row type -- it's only ever used by the app after filtering
-- to transaction_type = 'APPLICATION', so there's no risk of it colliding
-- with an unrelated row from one of the other three source tables even
-- though their id sequences are independent.
--
-- Approving/rejecting itself needs no new RLS: 002's "Approvers can update
-- office applications" and "Admins can manage applications" policies on
-- els_leave_applications already allow accesslevel 1/2 to change status.
--
-- security_invoker = true means this view has no RLS of its own -- it
-- relies entirely on the existing SELECT policies on the three source
-- tables (own rows for employees, office-scoped for approvers, all for
-- admins), exactly like public.v_leave_balances already does.
--
-- New columns (employee_name, source_id) are appended as the LAST columns
-- rather than inserted earlier, because `create or replace view` can only
-- add columns at the end of the column list in Postgres -- inserting one
-- earlier shifts every later column's position, which Postgres treats as
-- an invalid rename and rejects.

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
  null::bigint as source_id
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
  null::bigint as source_id
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
  null::bigint as source_id
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
