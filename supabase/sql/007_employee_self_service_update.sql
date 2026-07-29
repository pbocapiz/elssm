-- Run this once in the Supabase SQL Editor, after 001-006.
--
-- Lets a signed-in employee edit their own els_employees record (Employee
-- No., Employment Status, Civil Status, GSIS No., TIN No., Date Hired) from
-- the app's Profile screen, and adds the two columns that form needs but
-- didn't exist yet.

-- ============================================================================
-- 1. New columns
-- ============================================================================

alter table public.els_employees
  add column if not exists gsis_no character varying;

alter table public.els_employees
  add column if not exists tin_no character varying;

-- ============================================================================
-- 2. RLS: employees can update their own record
-- ============================================================================
-- "Admins can manage employees" (002) already covers admins via `for all`.
-- This adds the matching self-service update, mirroring the `using` clause
-- from 002's "Employees can view own record" select policy.

drop policy if exists "Employees can update own record" on public.els_employees;
create policy "Employees can update own record"
  on public.els_employees for update
  using (users_id = (select seqid from public.users where id = auth.uid()))
  with check (users_id = (select seqid from public.users where id = auth.uid()));

-- ============================================================================
-- 3. Extend public.v_user_profiles with the two new columns
-- ============================================================================
-- Appended at the end, not inserted earlier -- see 006's header comment for
-- why `create or replace view` requires this.

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
  e.date_hired,
  e.gsis_no,
  e.tin_no
from public.users u
left join public.gl_offices o on o.officeid = u.officeid
left join public.els_employees e on e.users_id = u.seqid;
