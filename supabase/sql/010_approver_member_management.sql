-- Run this once in the Supabase SQL Editor, after 001-009.
--
-- Backs the new "Members" screen (sidebar item visible to Admins and
-- Approvers only): lets an Approver activate/deactivate accesslevel-3 users
-- in their own office. Admins already have this via 002's "Admins can
-- update all users" policy; the read side (list of users) is likewise
-- already covered by 002's "Admins can view all users" / "Approvers can
-- view office users" -- this migration only adds the missing update policy.

drop policy if exists "Approvers can update office members" on public.users;
create policy "Approvers can update office members"
  on public.users for update
  using (
    public.current_access_level() = 2
    and officeid = public.current_office_id()
    and accesslevel = 3
  )
  with check (
    public.current_access_level() = 2
    and officeid = public.current_office_id()
    and accesslevel = 3
  );
