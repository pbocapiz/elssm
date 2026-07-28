-- Run this once in the Supabase SQL Editor (Dashboard -> SQL Editor -> paste -> Run).
--
-- public.users already exists (created directly in the Supabase table
-- editor) with columns: id, firstname, middlename, lastname, email,
-- officeid (int4, default 31), accesslevel (int4, default 3), created_at
-- (default now()), seqid (int8), position.
--
-- officeid, accesslevel, seqid, and created_at are intentionally left out
-- of every insert below so their column defaults apply:
--   - officeid    -> defaults to 31 (office picker not wired up yet)
--   - accesslevel -> defaults to 3 (standard self-signup level)
--   - seqid       -> stays NULL (auto-generated / unused for now)
--   - created_at  -> defaults to now()
--
-- Flow:
--   1. Sign-up (auth.users INSERT) stages the form data into
--      public.pending_users, keyed by the new user's id. If a project has
--      email confirmation turned OFF, the row goes straight into
--      public.users instead, since there's no confirmation step to wait for.
--   2. When the user confirms their email (auth.users.email_confirmed_at
--      flips from null to non-null), the staged row is moved into
--      public.users and removed from public.pending_users.
--
-- pending_users has RLS enabled with no client-facing policies: only the
-- security-definer trigger functions below (and the dashboard/service role)
-- can touch it.

create table if not exists public.pending_users (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  firstname text not null,
  middlename text,
  lastname text not null,
  position text not null,
  created_at timestamptz not null default now()
);

alter table public.pending_users enable row level security;

alter table public.users enable row level security;

drop policy if exists "Users can view own row" on public.users;
create policy "Users can view own row"
  on public.users for select
  using (auth.uid() = id);

drop policy if exists "Users can update own row" on public.users;
create policy "Users can update own row"
  on public.users for update
  using (auth.uid() = id);

-- No insert policy on public.users for end users: rows are only ever
-- written by the security definer trigger functions below.

create or replace function public.handle_new_signup()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text := new.email;
  v_firstname text := coalesce(new.raw_user_meta_data ->> 'firstname', '');
  v_middlename text := nullif(new.raw_user_meta_data ->> 'middlename', '');
  v_lastname text := coalesce(new.raw_user_meta_data ->> 'lastname', '');
  v_position text := coalesce(new.raw_user_meta_data ->> 'position', '');
begin
  if new.email_confirmed_at is not null then
    -- Email confirmation is disabled for this project (or an admin created
    -- an already-confirmed user): skip staging, go straight into users.
    insert into public.users (id, email, firstname, middlename, lastname, position)
    values (new.id, v_email, v_firstname, v_middlename, v_lastname, v_position)
    on conflict (id) do update set
      email = excluded.email,
      firstname = excluded.firstname,
      middlename = excluded.middlename,
      lastname = excluded.lastname,
      position = excluded.position;
  else
    insert into public.pending_users (id, email, firstname, middlename, lastname, position)
    values (new.id, v_email, v_firstname, v_middlename, v_lastname, v_position)
    on conflict (id) do update set
      email = excluded.email,
      firstname = excluded.firstname,
      middlename = excluded.middlename,
      lastname = excluded.lastname,
      position = excluded.position;
  end if;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function public.handle_new_signup();

create or replace function public.handle_user_confirmed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.email_confirmed_at is not null and old.email_confirmed_at is null then
    insert into public.users (id, email, firstname, middlename, lastname, position)
    select id, email, firstname, middlename, lastname, position
    from public.pending_users
    where id = new.id
    on conflict (id) do update set
      email = excluded.email,
      firstname = excluded.firstname,
      middlename = excluded.middlename,
      lastname = excluded.lastname,
      position = excluded.position;

    delete from public.pending_users where id = new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists on_auth_user_email_confirmed on auth.users;
create trigger on_auth_user_email_confirmed
  after update of email_confirmed_at on auth.users
  for each row
  execute function public.handle_user_confirmed();
