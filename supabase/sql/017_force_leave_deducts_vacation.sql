-- Run this once in the Supabase SQL Editor, after 001-016.
--
-- Activates "Force Leave (Mandatory)" -- the CSC-mandated 5 days/year an
-- employee may optionally use, which, unlike every other leave type, isn't
-- paid out of its own credit pool: using it deducts from Vacation Leave
-- instead. Whatever isn't used by year-end is what CSC forms call
-- "unavailed forced leave" -- that's just this leave type's own remaining
-- balance (5 - approved days used), so no separate tracking is needed for
-- it; v_leave_balances/leave_credit_report already compute it for free once
-- this type is active.
--
-- Two things this needs beyond the usual "add a leave type" steps (011 did
-- the same shape for Special Privilege Leave / Wellness Leave, but those
-- both pay out of their own pool):
--   1. The pre-insert balance check must also confirm Vacation Leave has
--      enough balance, not just Force Leave's own 5-day cap.
--   2. Approving a Force Leave application must post a Vacation Leave
--      deduction -- Force Leave's own applied-days tracking only enforces
--      the 5-day cap, it was never meant to represent what's actually
--      being spent.

-- ============================================================================
-- 1. Activate the leave type
-- ============================================================================

update public.els_leave_types
set is_active = true,
    yearly_credit = 5
where leave_name = 'Force Leave (Mandatory)';

-- ============================================================================
-- 2. Balance check: Force Leave applications also need enough Vacation
--    Leave balance, since that's what actually gets spent on approval
-- ============================================================================
-- Everything else about check_leave_application_balance (from 012, updated
-- by 014) is unchanged -- this only adds a second check that's a no-op for
-- every leave type other than Force Leave (Mandatory).

create or replace function public.check_leave_application_balance()
returns trigger
language plpgsql
as $$
declare
  v_available numeric;
  v_force_leave_type_id bigint;
  v_vacation_leave_type_id bigint;
  v_vacation_available numeric;
begin
  select
    coalesce(ob.opening_balance, 0)
      + coalesce(credits.total_earned, 0)
      - coalesce(deductions.total_deducted, 0)
      - coalesce(apps.total_applied, 0)
  into v_available
  from (select 1) as dummy
  left join lateral (
    select sum(opening_balance) as opening_balance
    from public.els_leave_opening_balance
    where employee_id = new.employee_id
      and leave_type_id = new.leave_type_id
      and balance_year = extract(year from new.leave_date)
  ) ob on true
  left join lateral (
    select sum(earned) as total_earned
    from public.els_leave_credits
    where employee_id = new.employee_id
      and leave_type_id = new.leave_type_id
      and extract(year from credit_month) = extract(year from new.leave_date)
      and credit_month < date_trunc('month', now())
  ) credits on true
  left join lateral (
    select sum(amount) as total_deducted
    from public.els_leave_deductions
    where employee_id = new.employee_id
      and leave_type_id = new.leave_type_id
      and extract(year from deduction_date) = extract(year from new.leave_date)
  ) deductions on true
  left join lateral (
    select sum(days) as total_applied
    from public.els_leave_applications
    where employee_id = new.employee_id
      and leave_type_id = new.leave_type_id
      and status = 'APPROVED'
      and extract(year from leave_date) = extract(year from new.leave_date)
  ) apps on true;

  if new.days > coalesce(v_available, 0) then
    raise exception
      'Insufficient leave balance: % day(s) requested, % day(s) available',
      new.days, coalesce(v_available, 0)
      using errcode = '23514'; -- check_violation
  end if;

  select id into v_force_leave_type_id
  from public.els_leave_types
  where leave_name = 'Force Leave (Mandatory)';

  if new.leave_type_id = v_force_leave_type_id then
    select id into v_vacation_leave_type_id
    from public.els_leave_types
    where leave_name = 'Vacation Leave';

    select
      coalesce(ob.opening_balance, 0)
        + coalesce(credits.total_earned, 0)
        - coalesce(deductions.total_deducted, 0)
        - coalesce(apps.total_applied, 0)
    into v_vacation_available
    from (select 1) as dummy
    left join lateral (
      select sum(opening_balance) as opening_balance
      from public.els_leave_opening_balance
      where employee_id = new.employee_id
        and leave_type_id = v_vacation_leave_type_id
        and balance_year = extract(year from new.leave_date)
    ) ob on true
    left join lateral (
      select sum(earned) as total_earned
      from public.els_leave_credits
      where employee_id = new.employee_id
        and leave_type_id = v_vacation_leave_type_id
        and extract(year from credit_month) = extract(year from new.leave_date)
        and credit_month < date_trunc('month', now())
    ) credits on true
    left join lateral (
      select sum(amount) as total_deducted
      from public.els_leave_deductions
      where employee_id = new.employee_id
        and leave_type_id = v_vacation_leave_type_id
        and extract(year from deduction_date) = extract(year from new.leave_date)
    ) deductions on true
    left join lateral (
      select sum(days) as total_applied
      from public.els_leave_applications
      where employee_id = new.employee_id
        and leave_type_id = v_vacation_leave_type_id
        and status = 'APPROVED'
        and extract(year from leave_date) = extract(year from new.leave_date)
    ) apps on true;

    if new.days > coalesce(v_vacation_available, 0) then
      raise exception
        'Force Leave is deducted from Vacation Leave: % day(s) requested, '
        'but only % Vacation Leave day(s) available',
        new.days, coalesce(v_vacation_available, 0)
        using errcode = '23514'; -- check_violation
    end if;
  end if;

  return new;
end;
$$;

-- ============================================================================
-- 3. On approval, post a Vacation Leave deduction for Force Leave
--    applications
-- ============================================================================
-- Not security definer: runs as whoever approved it (an Approver for their
-- own office, or an Admin), and both already have insert rights on
-- els_leave_deductions for that employee -- Approvers via 013's "Approvers
-- can create office deductions", Admins via 002's "Admins can manage
-- deductions" `for all`. No new access needed.

create or replace function public.deduct_vacation_leave_for_force_leave()
returns trigger
language plpgsql
as $$
declare
  v_force_leave_type_id bigint;
  v_vacation_leave_type_id bigint;
begin
  select id into v_force_leave_type_id
  from public.els_leave_types
  where leave_name = 'Force Leave (Mandatory)';

  if new.leave_type_id = v_force_leave_type_id then
    select id into v_vacation_leave_type_id
    from public.els_leave_types
    where leave_name = 'Vacation Leave';

    insert into public.els_leave_deductions
      (employee_id, leave_type_id, deduction_date, amount, remarks)
    values (
      new.employee_id,
      v_vacation_leave_type_id,
      new.leave_date,
      new.days,
      'Force Leave (Mandatory) applied -- deducted from Vacation Leave'
    );
  end if;

  return new;
end;
$$;

-- Split into an INSERT trigger and an UPDATE trigger rather than one
-- combined "after insert or update" trigger -- a WHEN clause can't
-- reference OLD for the INSERT case, so a single combined trigger can't
-- express "fire on UPDATE only when status actually changed" safely.

drop trigger if exists deduct_vacation_leave_for_force_leave_insert on public.els_leave_applications;
create trigger deduct_vacation_leave_for_force_leave_insert
  after insert on public.els_leave_applications
  for each row
  -- Applications are always submitted as PENDING (see
  -- LeaveApplicationService.submitApplication), so this is just a safety
  -- net in case a row is ever inserted already APPROVED.
  when (new.status = 'APPROVED')
  execute function public.deduct_vacation_leave_for_force_leave();

drop trigger if exists deduct_vacation_leave_for_force_leave_update on public.els_leave_applications;
create trigger deduct_vacation_leave_for_force_leave_update
  after update on public.els_leave_applications
  for each row
  -- old.status is distinct from new.status: fire once, exactly on the
  -- transition into APPROVED, not on every later edit to an already-
  -- approved row.
  when (new.status = 'APPROVED' and old.status is distinct from new.status)
  execute function public.deduct_vacation_leave_for_force_leave();
