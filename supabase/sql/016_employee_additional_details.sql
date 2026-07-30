-- Run this once in the Supabase SQL Editor, after 001-015.
--
-- Adds four more self-service employment fields (Division/Section,
-- Immediate Supervisor, PhilHealth No., Pag-IBIG No.) to els_employees,
-- alongside the GSIS No./TIN No. pair 007 already added the same way.
--
-- New columns are appended at the end of v_user_profiles's select list, not
-- inserted earlier -- see 006's header comment for why `create or replace
-- view` requires that.

-- ============================================================================
-- 1. New columns
-- ============================================================================

alter table public.els_employees
  add column if not exists division_section character varying;

alter table public.els_employees
  add column if not exists immediate_supervisor character varying;

alter table public.els_employees
  add column if not exists philhealth_no character varying;

alter table public.els_employees
  add column if not exists pagibig_no character varying;

-- ============================================================================
-- 2. Extend public.v_user_profiles with the four new columns
-- ============================================================================

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
  e.tin_no,
  e.division_section,
  e.immediate_supervisor,
  e.philhealth_no,
  e.pagibig_no
from public.users u
left join public.gl_offices o on o.officeid = u.officeid
left join public.els_employees e on e.users_id = u.seqid;
