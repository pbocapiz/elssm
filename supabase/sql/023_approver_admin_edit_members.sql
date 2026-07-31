-- Run this once in the Supabase SQL Editor, after 001-022.
--
-- Lets an Approver (accesslevel = 2) edit Position, Access Level, and
-- Status for accesslevel-3 Employees in their own office, from the Members
-- screen's edit card. Admins already had full access to every user via
-- 002's "Admins can update all users" policy.
--
-- Deliberately narrow, same reasoning as 003/013's approver policies:
--   - USING only matches rows that are CURRENTLY accesslevel = 3, so an
--     Approver can't touch another Approver's or Admin's row at all, even
--     if they happen to share an office.
--   - WITH CHECK only allows the NEW accesslevel to be 2 or 3, so an
--     Approver can promote a subordinate to Approver but never to Admin --
--     closing off the privilege-escalation path a blanket "for all" policy
--     would have opened.
-- The app additionally only offers Employee/Approver in the Access Level
-- dropdown when the signed-in user isn't an Admin, but that's a UX nicety,
-- not the security boundary -- this policy is.

drop policy if exists "Approvers can update office employees" on public.users;
create policy "Approvers can update office employees"
  on public.users for update
  using (
    public.current_access_level() = 2
    and officeid = public.current_office_id()
    and accesslevel = 3
  )
  with check (
    public.current_access_level() = 2
    and officeid = public.current_office_id()
    and accesslevel in (2, 3)
  );
