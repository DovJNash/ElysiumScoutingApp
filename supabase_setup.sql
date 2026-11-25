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
  "startPos" text not null,
  "exitPos" text not null,
  "autoShoot" integer not null,
  "autoIntake" integer not null,
  "allianceCount" integer not null,
  "neutralCount" integer not null,
  "opponentCount" integer not null,
  "teleopShoot" integer not null,
  "teleopIntake" integer not null,
  "doingDefence" integer not null,
  "standDefence" integer not null,
  "driverSkill" integer not null,
  notes text not null,
  "durationSeconds" integer not null,
  "createdAt" text not null
);
alter table public."Scouting"
  add column if not exists "matchNum" integer not null default 1;

create table if not exists public."SuperScouting" (
  "ID" text primary key,
  "uniqueKey" text not null unique,
  competition text not null,
  "scouterId" text not null,
  "scouterName" text not null,
  "teamNum" integer not null,
  auto text not null,
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
  "durationSeconds" integer not null,
  "createdAt" text not null
);

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

grant select on public.team_catalog, public.competitions, public.match_schedules,
  public."Scouting", public."SuperScouting", public.pit_scouting
  to anon, authenticated;
grant insert, update, delete on public.competitions, public.match_schedules,
  public.team_catalog to authenticated;
grant insert, update, delete on public."Scouting",
  public."SuperScouting", public.pit_scouting to anon, authenticated;
revoke all on public.app_users from anon, authenticated;

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
    where team_number = p_team_number;
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

  insert into public.app_users(id, name, password, role, team_number, team_name)
  values(p_id, trim(p_name), p_password, v_role, p_team_number, trim(p_team_name));

  return query
  select p_id, trim(p_name), v_role, p_team_number, trim(p_team_name);
end;
$$;

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
  v_team integer;
begin
  select * into v_user from public.app_users where id = p_requester_id;
  if not found then
    return false;
  end if;
  select "teamNum" into v_team from public."Scouting" where "ID" = p_record_id;
  if not found then
    return true;
  end if;
  if v_user.role = 'Leader' and v_team = v_user.team_number then
    delete from public."Scouting" where "ID" = p_record_id;
    return true;
  end if;
  if v_user.role = 'Scouter' then
    delete from public."Scouting" s
    where s."ID" = p_record_id and s."scouterId" = p_requester_id;
    return found;
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
  v_team integer;
begin
  select * into v_user from public.app_users where id = p_requester_id;
  if not found then
    return false;
  end if;
  select "teamNum" into v_team
  from public."SuperScouting" where "ID" = p_record_id;
  if not found then
    return true;
  end if;
  if v_user.role = 'Leader' and v_team = v_user.team_number then
    delete from public."SuperScouting" where "ID" = p_record_id;
    return true;
  end if;
  if v_user.role = 'Strategy' then
    delete from public."SuperScouting" s
    where s."ID" = p_record_id and s."scouterId" = p_requester_id;
    return found;
  end if;
  return false;
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
