-- Run this once in the Supabase SQL Editor, after 001, 002, and 003.
--
-- Lets an Approver (accesslevel = 2) link a not-yet-linked accesslevel-3
-- user in their own office to a new els_employees record (Admins already
-- had this via 002's "Admins can manage employees" policy).

-- ============================================================================
-- 1. RLS: approvers can insert an employee record for their own office
-- ============================================================================

drop policy if exists "Approvers can add office employees" on public.els_employees;
create policy "Approvers can add office employees"
  on public.els_employees for insert
  with check (
    public.current_access_level() = 2
    and users_id in (
      select seqid from public.users
      where officeid = public.current_office_id()
        and accesslevel = 3
    )
  );

-- ============================================================================
-- 2. Helper function: accesslevel-3 users with no els_employees row yet
-- ============================================================================
-- Not security definer: runs as the caller, so the existing SELECT policy
-- on public.users (office-scoped for approvers, unrestricted for admins)
-- scopes the results exactly the same way it already does everywhere else.

create or replace function public.unlinked_employee_users()
returns table (
  seqid bigint,
  id uuid,
  full_name text,
  officeid int
)
language sql
stable
as $$
  select
    u.seqid,
    u.id,
    trim(concat_ws(' ', u.firstname, u.middlename, u.lastname)) as full_name,
    u.officeid
  from public.users u
  where u.accesslevel = 3
    and not exists (
      select 1 from public.els_employees e where e.users_id = u.seqid
    )
  order by u.lastname, u.firstname;
$$;

grant execute on function public.unlinked_employee_users() to authenticated;
