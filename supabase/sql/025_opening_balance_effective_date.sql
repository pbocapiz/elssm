-- Run this once in the Supabase SQL Editor, after 001-024.
--
-- Starting Credits previously only recorded a balance_year (e.g. "2026")
-- for each opening balance -- there was no way to say what specific date
-- the figure was accurate as of. This adds a real effective_date column
-- that an Approver/Admin must pick per employee row before they can save
-- that row's starting credit.

-- ============================================================================
-- 1. els_leave_opening_balance.effective_date
-- ============================================================================
-- Nullable: existing rows (saved before this migration) have no effective
-- date yet, and the app treats that as "not yet set" -- Save stays
-- disabled for a row until an Approver/Admin explicitly picks one, even if
-- re-editing an old row.

alter table public.els_leave_opening_balance
  add column if not exists effective_date date;

-- ============================================================================
-- 2. office_employee_opening_balances: also return effective_date
-- ============================================================================
-- Changing a table-returning function's output columns requires dropping it
-- first -- create or replace only works when the signature is unchanged
-- (same pattern used in 019/020 for office_employees).

drop function if exists public.office_employee_opening_balances(bigint, bigint);

create function public.office_employee_opening_balances(
  p_leave_type_id bigint,
  p_year bigint
)
returns table (
  employee_id bigint,
  full_name text,
  employee_no character varying,
  opening_balance numeric,
  effective_date date
)
language sql
stable
as $$
  select
    e.id as employee_id,
    trim(concat_ws(' ', u.firstname, u.middlename, u.lastname)) as full_name,
    e.employee_no,
    coalesce(ob.opening_balance, 0) as opening_balance,
    ob.effective_date
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
