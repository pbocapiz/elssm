-- Seeds one employee record + a Vacation Leave opening balance + this
-- month's credit accrual, for an existing (signed-up) user.
--
-- Edit v_email below to the account you want to see data for, then run
-- this in the Supabase SQL Editor. Safe to re-run: uses guards instead of
-- inserting duplicates.

do $$
declare
  v_email text := 'REPLACE_WITH_YOUR_TEST_EMAIL@example.com';
  v_seqid bigint;
  v_employee_id bigint;
  v_leave_type_id bigint;
begin
  select seqid into v_seqid from public.users where email = v_email;
  if v_seqid is null then
    raise exception 'No user found in public.users with email %', v_email;
  end if;

  -- 1. Link this user to an employee record (users_id -> users.seqid).
  insert into public.els_employees (users_id, employee_no, employement_status, civil_status, date_hired)
  values (v_seqid, 'EMP-0001', 'Permanent', 'Single', current_date)
  on conflict (users_id) do nothing;

  select id into v_employee_id from public.els_employees where users_id = v_seqid;

  -- 2. Pick a leave type to seed (Vacation Leave, from the standard set).
  select id into v_leave_type_id
  from public.els_leave_types
  where leave_name = 'Vacation Leave';

  if v_leave_type_id is null then
    raise exception 'Vacation Leave not found in els_leave_types -- run 002_esslms_business_schema.sql first';
  end if;

  -- 3. Opening balance for the current year.
  insert into public.els_leave_opening_balance (employee_id, leave_type_id, balance_year, opening_balance)
  select v_employee_id, v_leave_type_id, extract(year from now())::bigint, 15
  where not exists (
    select 1 from public.els_leave_opening_balance
    where employee_id = v_employee_id
      and leave_type_id = v_leave_type_id
      and balance_year = extract(year from now())::bigint
  );

  -- 4. This month's earned credit.
  insert into public.els_leave_credits (employee_id, leave_type_id, credit_month, earned, remarks)
  select v_employee_id, v_leave_type_id, date_trunc('month', now())::date, 1.25, 'Monthly accrual'
  where not exists (
    select 1 from public.els_leave_credits
    where employee_id = v_employee_id
      and leave_type_id = v_leave_type_id
      and credit_month = date_trunc('month', now())::date
  );
end $$;
