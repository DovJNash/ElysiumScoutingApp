create table if not exists public.app_users (
  id text primary key,
  name text not null unique,
  password text not null,
  role text not null check (role in ('Scouter', 'Strategy', 'Leader')),
  team_number integer not null default 1937,
  team_name text not null default '',
  created_at timestamptz not null default now()
);

alter table public.app_users
  add column if not exists team_number integer not null default 1937;
alter table public.app_users
  add column if not exists team_name text not null default '';

-- Login compares names case-insensitively, so "Dov" and "dov" must not be two
-- different accounts. (If old duplicates exist this only prints a notice;
-- delete the duplicate from app_users and run the script again.)
do $$
begin
  create unique index if not exists app_users_name_lower_key
    on public.app_users (lower(name));
exception when unique_violation then
  raise notice 'app_users has names that differ only by upper/lower case - fix them and run this script again to enforce unique names.';
end $$;

create table if not exists public.team_catalog (
  team_number integer primary key,
  team_name text not null
);
alter table public.team_catalog drop column if exists access_code;

create table if not exists public.team_role_codes (
  team_number integer primary key references public.team_catalog(team_number)
    on delete cascade,
  strategy_code text not null,
  leader_code text not null
);
revoke all on public.team_role_codes from anon, authenticated;

insert into public.team_catalog(team_number, team_name)
values (1937, 'Elysium')
on conflict (team_number) do update
set team_name = excluded.team_name;

create table if not exists public.competitions (
  id text primary key,
  name text not null,
  tba_event_key text,
  team_numbers integer[] not null default '{}',
  created_by text,
  created_at timestamptz not null default now()
);

create table if not exists public.match_schedules (
  id text primary key,
  competition_id text not null references public.competitions(id) on delete cascade,
  match_number integer not null,
  match_level text not null default 'qm',
  set_number integer not null default 1,
  red_team_numbers integer[] not null default '{}',
  blue_team_numbers integer[] not null default '{}',
  scheduled_at timestamptz,
  red_score integer,
  blue_score integer,
  updated_at timestamptz not null default now(),
  unique (competition_id, match_level, set_number, match_number)
);

create table if not exists public."Scouting" (
  "ID" text primary key,
  "uniqueKey" text not null unique,
  competition text not null,
  "scouterId" text not null,
  "scouterName" text not null,
  "teamNum" integer not null,
  "matchNum" integer not null,
  "matchLevel" text not null default 'qm',
  "matchSet" integer not null default 1,
  "startPos" text not null,
  "exitPos" text not null,
  "autoShoot" integer not null,
  "autoIntake" integer not null,
  "allianceCount" integer not null,
  "neutralCount" integer not null,
  "opponentCount" integer not null,
  "teleopShoot" integer not null,
  "teleopIntake" integer not null,
  "robotShowed" boolean not null default true,
  "autoCycles" integer not null default 0,
  "autoFuelsDelivered" integer not null default 0,
  "autoIntakeSpeed" integer not null default 0,
  "autoPerformance" integer not null default 0,
  "teleopCanShootMoving" boolean not null default false,
  "teleopCycles" integer not null default 0,
  "teleopFuelsDelivered" integer not null default 0,
  "teleopIntakeSpeed" integer not null default 0,
  "teleopAccuracy" integer not null default 0,
  "teleopPerformance" integer not null default 0,
  "playedDefense" boolean not null default false,
  "defenseRating" integer not null default 0,
  "dealtWithDefense" boolean not null default false,
  "defenseResilience" integer not null default 0,
  climbed boolean not null default false,
  "climbLevel" text not null default '',
  "climbTimeSeconds" integer not null default 0,
  "doingDefence" integer not null,
  "standDefence" integer not null,
  "driverSkill" integer not null,
  notes text not null,
  "durationSeconds" integer not null,
  "createdAt" text not null
);
alter table public."Scouting"
  add column if not exists "matchNum" integer not null default 1,
  add column if not exists "matchLevel" text not null default 'qm',
  add column if not exists "matchSet" integer not null default 1;
alter table public."Scouting"
  add column if not exists "robotShowed" boolean not null default true,
  add column if not exists "autoCycles" integer not null default 0,
  add column if not exists "autoFuelsDelivered" integer not null default 0,
  add column if not exists "autoIntakeSpeed" integer not null default 0,
  add column if not exists "autoPerformance" integer not null default 0,
  add column if not exists "teleopCanShootMoving" boolean not null default false,
  add column if not exists "teleopCycles" integer not null default 0,
  add column if not exists "teleopFuelsDelivered" integer not null default 0,
  add column if not exists "teleopIntakeSpeed" integer not null default 0,
  add column if not exists "teleopAccuracy" integer not null default 0,
  add column if not exists "teleopPerformance" integer not null default 0,
  add column if not exists "playedDefense" boolean not null default false,
  add column if not exists "defenseRating" integer not null default 0,
  add column if not exists "dealtWithDefense" boolean not null default false,
  add column if not exists "defenseResilience" integer not null default 0,
  add column if not exists climbed boolean not null default false,
  add column if not exists "climbLevel" text not null default '',
  add column if not exists "climbTimeSeconds" integer not null default 0;

create table if not exists public."SuperScouting" (
  "ID" text primary key,
  "uniqueKey" text not null unique,
  competition text not null,
  "scouterId" text not null,
  "scouterName" text not null,
  "teamNum" integer not null,
  auto text not null,
  "autoExitPath" text not null default '',
  bps text not null,
  "shootingLimits" text not null,
  "missPercent" text not null,
  "intakeSpeed" text not null,
  "RobotCap" text not null,
  "robotLimits" text not null,
  "driverSkills" text not null,
  penalties text not null,
  "bumpSpeed" text not null,
  "DriverTechnique" text not null,
  "defenceStyle" text not null,
  "shootingWhileMoving" text not null default '',
  "climbCapability" text not null default '',
  "durationSeconds" integer not null,
  "createdAt" text not null
);
alter table public."SuperScouting"
  add column if not exists "autoExitPath" text not null default '',
  add column if not exists "shootingWhileMoving" text not null default '',
  add column if not exists "climbCapability" text not null default '';

create table if not exists public.pit_scouting (
  id text primary key,
  "uniqueKey" text not null unique,
  competition text not null,
  "scouterId" text not null,
  "scouterName" text not null,
  "teamNum" integer not null,
  autonomous_types text not null default '',
  strengths text not null default '',
  difficulties text not null default '',
  defense text not null default '',
  other_notes text not null default '',
  "durationSeconds" integer not null default 60,
  "createdAt" text not null,
  "isSynced" boolean not null default true
);

create table if not exists public.match_assignments (
  id bigint generated always as identity primary key,
  assigned_to text not null references public.app_users(id) on delete cascade,
  competition_id text not null,
  match_level text not null default 'qm',
  set_number integer not null default 1 check (set_number > 0),
  match_number integer not null check (match_number > 0),
  assigned_by text not null,
  assigned_at timestamptz not null default now(),
  unique (assigned_to, competition_id, match_level, set_number, match_number)
);

grant select on public.team_catalog, public.competitions, public.match_schedules,
  public."Scouting", public."SuperScouting", public.pit_scouting
  to anon, authenticated;
grant insert, update, delete on public.competitions, public.match_schedules,
  public.team_catalog to authenticated;

-- Match / super scouting forms: the app only INSERTs them. Deleting goes
-- through delete_scouting_record / delete_super_scouting_record (which check
-- who is asking), so nobody can edit or wipe rows with the public key.
grant insert on public."Scouting", public."SuperScouting" to anon, authenticated;
revoke update, delete on public."Scouting", public."SuperScouting"
  from anon, authenticated;

-- Pit forms are written with upsert (insert + update), never deleted.
grant insert, update on public.pit_scouting to anon, authenticated;
revoke delete on public.pit_scouting from anon, authenticated;
revoke all on public.app_users from anon, authenticated;
revoke all on public.match_assignments from anon, authenticated;

drop function if exists public.app_login(text, text);
drop function if exists public.app_signup(text, text, text, text, text);
drop function if exists public.app_signup(text, text, text, text, text, integer);
drop function if exists public.app_signup(text, text, text, text, text, integer, text);

create function public.app_login(p_name text, p_password text)
returns table(
  user_id text,
  user_name text,
  user_role text,
  team_number integer,
  team_name text
)
language sql
security definer
set search_path = public
as $$
  select u.id, u.name, u.role, u.team_number, coalesce(u.team_name, '')
  from app_users u
  where lower(u.name) = lower(p_name) and u.password = p_password
  limit 1;
$$;

create function public.app_signup(
  p_id text,
  p_name text,
  p_password text,
  p_role text,
  p_code text default '',
  p_team_number integer default 0,
  p_team_name text default ''
)
returns table(
  user_id text,
  user_name text,
  user_role text,
  team_number integer,
  team_name text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text;
  v_team_role_codes public.team_role_codes%rowtype;
begin
  v_role := case lower(p_role)
    when 'leader' then 'Leader'
    when 'lead' then 'Leader'
    when 'strategy' then 'Strategy'
    else 'Scouter'
  end;

  if p_team_number <= 0 or trim(p_team_name) = '' then
    raise exception 'Select a valid team before registering';
  end if;

  if v_role in ('Strategy', 'Leader') then
    select * into v_team_role_codes
    from public.team_role_codes
    where team_role_codes.team_number = p_team_number;
    if not found then
      raise exception 'This team has not configured Strategy/Leader registration codes';
    end if;
    if (v_role = 'Strategy' and p_code <> v_team_role_codes.strategy_code)
      or (v_role = 'Leader' and p_code <> v_team_role_codes.leader_code) then
      raise exception 'Invalid team-specific role access code';
    end if;
  elsif coalesce(p_code, '') <> '' then
    raise exception 'Scouter registration does not use a role access code';
  end if;

  if exists (
    select 1 from public.app_users where lower(name) = lower(trim(p_name))
  ) then
    raise exception 'This name is already taken. Choose another name, or log in.';
  end if;

  insert into public.app_users(id, name, password, role, team_number, team_name)
  values(p_id, trim(p_name), p_password, v_role, p_team_number, trim(p_team_name));

  return query
  select p_id, trim(p_name), v_role, p_team_number, trim(p_team_name);
end;
$$;

-- Who may delete a form:
--   * the account that submitted it (any role - a Strategy account can also
--     submit match forms), or
--   * a Leader, for forms submitted by an account of the Leader's own team.
-- (This used to compare the SCOUTED robot's number with the leader's team,
-- so a leader could only delete forms about their own robot.)
create or replace function public.delete_scouting_record(
  p_record_id text, p_requester_id text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user public.app_users%rowtype;
  v_owner text;
  v_owner_team integer;
begin
  select * into v_user from public.app_users where id = p_requester_id;
  if not found then
    return false;
  end if;
  select "scouterId" into v_owner from public."Scouting" where "ID" = p_record_id;
  if not found then
    return true;
  end if;
  if v_owner = p_requester_id then
    delete from public."Scouting" where "ID" = p_record_id;
    return true;
  end if;
  if v_user.role = 'Leader' then
    select team_number into v_owner_team from public.app_users where id = v_owner;
    if v_owner_team is not null and v_owner_team = v_user.team_number then
      delete from public."Scouting" where "ID" = p_record_id;
      return true;
    end if;
  end if;
  return false;
end;
$$;

create or replace function public.delete_super_scouting_record(
  p_record_id text, p_requester_id text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user public.app_users%rowtype;
  v_owner text;
  v_owner_team integer;
begin
  select * into v_user from public.app_users where id = p_requester_id;
  if not found then
    return false;
  end if;
  select "scouterId" into v_owner
  from public."SuperScouting" where "ID" = p_record_id;
  if not found then
    return true;
  end if;
  if v_owner = p_requester_id then
    delete from public."SuperScouting" where "ID" = p_record_id;
    return true;
  end if;
  if v_user.role = 'Leader' then
    select team_number into v_owner_team from public.app_users where id = v_owner;
    if v_owner_team is not null and v_owner_team = v_user.team_number then
      delete from public."SuperScouting" where "ID" = p_record_id;
      return true;
    end if;
  end if;
  return false;
end;
$$;

drop function if exists public.create_competition(text, text, text, integer[]);
create or replace function public.create_competition(
  p_requester_id text,
  p_password text,
  p_id text,
  p_name text,
  p_team_numbers integer[]
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user public.app_users%rowtype;
begin
  select * into v_user
  from public.app_users
  where id = p_requester_id and password = p_password;
  if not found or v_user.role <> 'Leader' then
    raise exception 'Only a verified Leader can create a competition';
  end if;
  if trim(coalesce(p_id, '')) = ''
     or trim(coalesce(p_name, '')) = ''
     or coalesce(array_length(p_team_numbers, 1), 0) = 0
     or exists (select 1 from unnest(p_team_numbers) n where n <= 0) then
    raise exception 'Enter a competition ID, name, and at least one valid team';
  end if;
  insert into public.competitions(id, name, team_numbers, created_by)
  values (
    trim(p_id),
    trim(p_name),
    array(select distinct n from unnest(p_team_numbers) n order by n),
    p_requester_id
  );
  return true;
end;
$$;

revoke all on function public.app_login(text, text) from public;
revoke all on function public.app_signup(text, text, text, text, text, integer, text)
  from public;
grant execute on function public.app_login(text, text) to anon, authenticated;
grant execute on function public.app_signup(text, text, text, text, text, integer, text)
  to anon, authenticated;
grant execute on function public.delete_scouting_record(text, text)
  to anon, authenticated;
grant execute on function public.delete_super_scouting_record(text, text)
  to anon, authenticated;
revoke all on function public.create_competition(text, text, text, text, integer[])
  from public;
grant execute on function public.create_competition(text, text, text, text, integer[])
  to anon, authenticated;

create or replace function public.leader_update_team_role_codes(
  p_requester_id text,
  p_password text,
  p_strategy_code text,
  p_leader_code text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user public.app_users%rowtype;
begin
  select * into v_user
  from public.app_users
  where id = p_requester_id and password = p_password;
  if not found or v_user.role <> 'Leader' then
    raise exception 'Only a verified Leader can change team access codes';
  end if;
  if trim(coalesce(p_strategy_code, '')) = ''
     or trim(coalesce(p_leader_code, '')) = ''
     or trim(p_strategy_code) = trim(p_leader_code) then
    raise exception 'Enter two different, non-empty access codes';
  end if;
  update public.team_role_codes
  set strategy_code = trim(p_strategy_code),
      leader_code = trim(p_leader_code)
  where team_number = v_user.team_number;
  if not found then
    raise exception 'This team has not configured role access codes';
  end if;
  return true;
end;
$$;

create or replace function public.leader_team_members(
  p_requester_id text,
  p_password text
)
returns table(user_id text, user_name text, user_role text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user public.app_users%rowtype;
begin
  select * into v_user
  from public.app_users
  where id = p_requester_id and password = p_password;
  if not found or v_user.role <> 'Leader' then
    raise exception 'Only a verified Leader can view team members';
  end if;
  return query
  select u.id, u.name, u.role
  from public.app_users u
  where u.team_number = v_user.team_number
  order by u.name;
end;
$$;

create or replace function public.leader_set_match_assignment(
  p_requester_id text,
  p_password text,
  p_assigned_to text,
  p_competition_id text,
  p_match_level text,
  p_set_number integer,
  p_match_number integer,
  p_assigned boolean
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_leader public.app_users%rowtype;
  v_assignee public.app_users%rowtype;
begin
  select * into v_leader
  from public.app_users
  where id = p_requester_id and password = p_password;
  if not found or v_leader.role <> 'Leader' then
    raise exception 'Only a verified Leader can assign matches';
  end if;
  select * into v_assignee
  from public.app_users
  where id = p_assigned_to and team_number = v_leader.team_number;
  if not found or v_assignee.role not in ('Scouter', 'Strategy') then
    raise exception 'Choose a Scouter or Strategy user from your team';
  end if;
  if trim(coalesce(p_competition_id, '')) = ''
     or p_match_number <= 0
     or p_set_number <= 0
     or p_match_level not in ('qm', 'ef', 'qf', 'sf', 'f') then
    raise exception 'Invalid match assignment';
  end if;
  if p_assigned then
    insert into public.match_assignments(
      assigned_to, competition_id, match_level, set_number, match_number, assigned_by
    ) values (
      p_assigned_to, p_competition_id, p_match_level, p_set_number, p_match_number, p_requester_id
    )
    on conflict (assigned_to, competition_id, match_level, set_number, match_number)
    do update set assigned_by = excluded.assigned_by, assigned_at = now();
  else
    delete from public.match_assignments a
    where a.assigned_to = p_assigned_to
      and a.competition_id = p_competition_id
      and a.match_level = p_match_level
      and a.set_number = p_set_number
      and a.match_number = p_match_number
      and exists (
        select 1 from public.app_users u
        where u.id = a.assigned_to and u.team_number = v_leader.team_number
      );
  end if;
  return true;
end;
$$;

create or replace function public.my_match_assignments(
  p_user_id text,
  p_password text
)
returns table(
  competition_id text,
  match_level text,
  set_number integer,
  match_number integer
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.app_users u
    where u.id = p_user_id and u.password = p_password
  ) then
    raise exception 'Invalid account credentials';
  end if;
  return query
  select a.competition_id, a.match_level, a.set_number, a.match_number
  from public.match_assignments a
  where a.assigned_to = p_user_id
  order by a.competition_id, a.match_level, a.set_number, a.match_number;
end;
$$;

create or replace function public.leader_member_match_assignments(
  p_requester_id text,
  p_password text,
  p_assigned_to text
)
returns table(
  competition_id text,
  match_level text,
  set_number integer,
  match_number integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_leader public.app_users%rowtype;
begin
  select * into v_leader
  from public.app_users
  where id = p_requester_id and password = p_password;
  if not found or v_leader.role <> 'Leader' then
    raise exception 'Only a verified Leader can view team assignments';
  end if;
  if not exists (
    select 1 from public.app_users u
    where u.id = p_assigned_to and u.team_number = v_leader.team_number
  ) then
    raise exception 'The selected user is not a member of your team';
  end if;
  return query
  select a.competition_id, a.match_level, a.set_number, a.match_number
  from public.match_assignments a
  where a.assigned_to = p_assigned_to
  order by a.competition_id, a.match_level, a.set_number, a.match_number;
end;
$$;

create or replace function public.profile_update(
  p_user_id text,
  p_current_password text,
  p_new_name text,
  p_new_password text
)
returns table(user_id text, user_name text, user_role text, team_number integer, team_name text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user public.app_users%rowtype;
  v_name text := trim(coalesce(p_new_name, ''));
begin
  select * into v_user
  from public.app_users
  where id = p_user_id and password = p_current_password;
  if not found then
    raise exception 'Current password is incorrect';
  end if;
  if v_name = '' or trim(coalesce(p_new_password, '')) = '' then
    raise exception 'Name and password cannot be empty';
  end if;
  update public.app_users
  set name = v_name, password = p_new_password
  where id = p_user_id;
  return query
  select u.id, u.name, u.role, u.team_number, coalesce(u.team_name, '')
  from public.app_users u where u.id = p_user_id;
exception
  when unique_violation then
    raise exception 'This name is already taken. Choose another name.';
end;
$$;

create or replace function public.profile_delete_account(
  p_user_id text,
  p_password text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.app_users u
    where u.id = p_user_id and u.password = p_password
  ) then
    raise exception 'Current password is incorrect';
  end if;
  delete from public."Scouting" where "scouterId" = p_user_id;
  delete from public."SuperScouting" where "scouterId" = p_user_id;
  delete from public.pit_scouting where "scouterId" = p_user_id;
  delete from public.match_assignments where assigned_by = p_user_id;
  delete from public.app_users where id = p_user_id;
  return true;
end;
$$;

revoke all on function public.leader_update_team_role_codes(text, text, text, text)
  from public;
revoke all on function public.leader_team_members(text, text) from public;
revoke all on function public.leader_set_match_assignment(text, text, text, text, text, integer, integer, boolean)
  from public;
revoke all on function public.my_match_assignments(text, text) from public;
revoke all on function public.leader_member_match_assignments(text, text, text)
  from public;
revoke all on function public.profile_update(text, text, text, text) from public;
revoke all on function public.profile_delete_account(text, text) from public;
grant execute on function public.leader_update_team_role_codes(text, text, text, text)
  to anon, authenticated;
grant execute on function public.leader_team_members(text, text)
  to anon, authenticated;
grant execute on function public.leader_set_match_assignment(text, text, text, text, text, integer, integer, boolean)
  to anon, authenticated;
grant execute on function public.my_match_assignments(text, text)
  to anon, authenticated;
grant execute on function public.leader_member_match_assignments(text, text, text)
  to anon, authenticated;
grant execute on function public.profile_update(text, text, text, text)
  to anon, authenticated;
grant execute on function public.profile_delete_account(text, text)
  to anon, authenticated;

select routine_name
from information_schema.routines
where routine_schema = 'public'
  and routine_name in (
    'app_login',
    'app_signup',
    'delete_scouting_record',
    'delete_super_scouting_record',
    'create_competition',
    'leader_update_team_role_codes',
    'leader_team_members',
    'leader_set_match_assignment',
    'my_match_assignments',
    'leader_member_match_assignments',
    'profile_update',
    'profile_delete_account'
  )
order by routine_name;
