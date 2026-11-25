create table if not exists public.app_users (
  id text primary key,
  name text not null unique,
  password text not null,
  role text not null check (role in ('Scouter','Strategy','Leader')),
  team_number integer not null,
  team_name text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.team_catalog (
  team_number integer primary key,
  team_name text not null,
  access_code text not null unique
);

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

alter table public.app_users add column if not exists team_number integer;
alter table public.app_users add column if not exists team_name text default '';

insert into public.team_catalog(team_number, team_name, access_code)
values
  (1937, 'Elysium', 'ELYSIUM-TEAM-1937')
on conflict (team_number) do update
set team_name = excluded.team_name;

grant select on public.app_users, public.team_catalog, public.competitions,
  public.match_schedules, public."Scouting", public."SuperScouting", public.pit_scouting
  to anon, authenticated;
grant insert, update, delete on public.competitions, public.match_schedules,
  public.team_catalog to authenticated;
grant insert, update, delete on public."Scouting",
  public."SuperScouting", public.pit_scouting to anon, authenticated;

create or replace function public.app_login(p_name text, p_password text)
returns table(user_id text, user_name text, user_role text,
              team_number integer, team_name text)
language sql security definer set search_path = public as $$
  select u.id, u.name, u.role, u.team_number,
         coalesce(u.team_name, t.team_name, '')
  from app_users u
  left join team_catalog t on t.team_number = u.team_number
  where lower(u.name) = lower(p_name) and u.password = p_password
  limit 1;
$$;

create or replace function public.app_signup(
  p_id text, p_name text, p_password text, p_role text,
  p_code text default '', p_team_number integer default 0,
  p_team_code text default ''
)
returns table(user_id text, user_name text, user_role text,
              team_number integer, team_name text)
language plpgsql security definer set search_path = public as $$
declare
  v_role text;
  v_team public.team_catalog%rowtype;
begin
  v_role := case lower(p_role)
    when 'leader' then 'Leader'
    when 'lead' then 'Leader'
    when 'strategy' then 'Strategy'
    else 'Scouter'
  end;

  select * into v_team from team_catalog
  where team_number = p_team_number and access_code = p_team_code;
  if not found then
    raise exception 'Invalid team number or team access code';
  end;

  if v_role = 'Strategy' and p_code <> 'ELYSIUM-STRAT-1937' then
    raise exception 'Invalid Strategy access code';
  end;
  if v_role = 'Leader' and p_code <> 'ELYSIUM-LEAD-1937' then
    raise exception 'Invalid Leader access code';
  end;

  insert into app_users(id, name, password, role, team_number, team_name)
  values(p_id, trim(p_name), p_password, v_role, p_team_number, v_team.team_name);

  return query select p_id, trim(p_name), v_role, p_team_number, v_team.team_name;
end;
$$;

create or replace function public.delete_scouting_record(
  p_record_id text, p_requester_id text
)
returns boolean language plpgsql security definer set search_path = public as $$
declare v_user app_users%rowtype; v_team integer;
begin
  select * into v_user from app_users where id = p_requester_id;
  if not found then return false; end;
  select "teamNum" into v_team from "Scouting" where "ID" = p_record_id;
  if not found then return true; end;
  if v_user.role = 'Leader' and v_team is not null
     and v_team = v_user.team_number then
    delete from "Scouting" where "ID" = p_record_id;
    return true;
  end;
  if v_user.role = 'Scouter' then
    delete from "Scouting" s
    where s."ID" = p_record_id and s."scouterId" = p_requester_id;
    return found;
  end;
  return false;
end;
$$;

create or replace function public.delete_super_scouting_record(
  p_record_id text, p_requester_id text
)
returns boolean language plpgsql security definer set search_path = public as $$
declare v_user app_users%rowtype; v_team integer;
begin
  select * into v_user from app_users where id = p_requester_id;
  if not found then return false; end;
  select "teamNum" into v_team from "SuperScouting" where "ID" = p_record_id;
  if v_user.role = 'Leader' and v_team = v_user.team_number then
    delete from "SuperScouting" where "ID" = p_record_id;
    return true;
  end;
  if v_user.role = 'Strategy' then
    delete from "SuperScouting" s
    where s."ID" = p_record_id and s."scouterId" = p_requester_id;
    return found;
  end;
  return false;
end;
$$;

revoke all on function public.app_login(text,text) from public;
revoke all on function public.app_signup(text,text,text,text,text,integer,text) from public;
grant execute on function public.app_login(text,text) to anon, authenticated;
grant execute on function public.app_signup(text,text,text,text,text,integer,text) to anon, authenticated;
grant execute on function public.delete_scouting_record(text,text) to anon, authenticated;
grant execute on function public.delete_super_scouting_record(text,text) to anon, authenticated;
