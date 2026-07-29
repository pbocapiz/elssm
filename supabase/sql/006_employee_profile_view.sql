-- Run this once in the Supabase SQL Editor, after 001-005.
--
-- Extends public.v_user_profiles (created in 002, used by the sidebar) with
-- the caller's linked public.els_employees columns, so the app's Profile
-- screen can show one combined record instead of two separate queries.
--
-- left join because accesslevel-3 users may not have a linked els_employees
-- row yet (see EmployeeService.fetchUnlinkedUsers) -- those columns just
-- come back null in that case.
--
-- New columns are appended at the end of the select list, not inserted
-- earlier, because `create or replace view` can only add columns at the end
-- in Postgres -- inserting one earlier shifts every later column's
-- position, which Postgres treats as an invalid rename and rejects (see
-- 005's header comment for the same constraint).

create or replace view public.v_user_profiles
with (security_invoker = true)
as
select
  u.id,
  u.seqid,
  u.firstname,
  u.middlename,
  u.lastname,
  u.email,
  u.position,
  u.officeid,
  o.officename,
  u.accesslevel,
  u.is_active,
  e.id as employee_id,
  e.employee_no,
  e.employement_status,
  e.civil_status,
  e.date_hired
from public.users u
left join public.gl_offices o on o.officeid = u.officeid
left join public.els_employees e on e.users_id = u.seqid;
