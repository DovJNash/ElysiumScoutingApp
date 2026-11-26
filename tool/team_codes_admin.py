#!/usr/bin/env python3
"""Manage the Strategy / Leader registration codes of every team.

  generate  create / refresh team_role_codes.private.json (every Israeli TBA team;
            blank codes get the default  <team name>-LEADER-CODE  and
            <team name>-STRATEGY-CODE)
  push      send the JSON to Supabase - run it after every change of the JSON and
            the new codes are live immediately (needs SUPABASE_SERVICE_KEY)
  sql       alternative to push: write a .sql file to run in the SQL Editor
"""

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SUPABASE_CONFIG_PATH = ROOT / "lib" / "config" / "supabase_config.dart"
TBA_CONFIG_PATH = ROOT / "lib" / "config" / "tba_config.dart"
PRIVATE_JSON = ROOT / "team_role_codes.private.json"
PRIVATE_SQL = ROOT / "team_role_codes_seed.private.sql"
TBA_API = "https://www.thebluealliance.com/api/v3"


def tba_key():
    """The TBA key: TBA_API_KEY env var, else the one in tba_config.dart."""
    key = os.environ.get("TBA_API_KEY", "").strip()
    if key:
        return key
    source = TBA_CONFIG_PATH.read_text(encoding="utf-8")
    match = re.search(
        r"static const String apiKey\s*=\s*String\.fromEnvironment\(.*?"
        r"defaultValue:\s*'([^']+)'",
        source,
        re.DOTALL,
    )
    if not match:
        raise RuntimeError(f"Could not read the TBA key from {TBA_CONFIG_PATH}")
    return match.group(1)


class TbaAuthError(RuntimeError):
    pass


def tba_get(path):
    request = urllib.request.Request(
        f"{TBA_API}{path}",
        headers={
            "X-TBA-Auth-Key": tba_key(),
            "Accept": "application/json",
            "User-Agent": "elysium-scouting-app-admin/1.0",
        },
        method="GET",
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        if error.code in (401, 403):
            raise TbaAuthError(
                f"{path}: HTTP {error.code} - TBA rejected the key in "
                "lib/config/tba_config.dart"
            ) from error
        raise RuntimeError(f"{path}: HTTP {error.code} {error.reason}") from error
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as error:
        raise RuntimeError(f"{path}: {error}") from error


def fetch_teams():
    """All teams of the Israeli district: the teams of EVERY district event of
    the season, merged into one list. Falls back to the district's own team
    list and then to the previous seasons if the season is not published yet."""
    problems = []
    for year in (2027, 2026, 2025):
        teams = {}
        try:
            events = tba_get(f"/district/{year}isr/events/simple")
            for event in events if isinstance(events, list) else []:
                key = event.get("key")
                if not key:
                    continue
                try:
                    for team in tba_get(f"/event/{key}/teams/simple"):
                        teams.setdefault(team.get("key"), team)
                except TbaAuthError:
                    raise
                except RuntimeError as error:
                    problems.append(str(error))
        except TbaAuthError as error:
            raise RuntimeError(str(error)) from error
        except RuntimeError as error:
            problems.append(str(error))

        if not teams:
            try:
                for team in tba_get(f"/district/{year}isr/teams/simple"):
                    teams.setdefault(team.get("key"), team)
            except TbaAuthError as error:
                raise RuntimeError(str(error)) from error
            except RuntimeError as error:
                problems.append(str(error))

        if teams:
            if year != 2027:
                print(f"Note: TBA has no 2027 teams yet - using {year}.")
            return list(teams.values())
        problems.append(f"{year}: no teams found")
    raise RuntimeError(
        "Could not fetch the team roster from The Blue Alliance:\n  "
        + "\n  ".join(problems)
    )


def default_code(team_name, role):
    """Default code, e.g. 'Elysium-LEADER-CODE'."""
    return f"{str(team_name).strip()}-{role}-CODE"


def load_rows(fill_defaults=True):
    """Reads and validates the JSON. Blank codes become the default code."""
    if not PRIVATE_JSON.exists():
        raise RuntimeError(
            "team_role_codes.private.json does not exist yet - run "
            "'python tool/team_codes_admin.py generate' first."
        )
    try:
        data = json.loads(PRIVATE_JSON.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise RuntimeError(f"{PRIVATE_JSON} is not valid JSON: {error}") from error
    rows = data.get("teams") if isinstance(data, dict) else None
    if not isinstance(rows, list) or not rows:
        raise RuntimeError(f"{PRIVATE_JSON} must contain a non-empty 'teams' array.")

    result, seen = [], set()
    for row in rows:
        if not isinstance(row, dict) or not str(row.get("team_number", "")).isdigit():
            raise RuntimeError(f"Every team needs a numeric team_number: {row}")
        number = int(row["team_number"])
        name = str(row.get("team_name", "")).strip()
        if number <= 0 or not name:
            raise RuntimeError(f"Team {number} needs a team_name.")
        if number in seen:
            raise RuntimeError(f"Team {number} appears twice in the JSON.")
        seen.add(number)
        strategy = str(row.get("strategy_code", "")).strip()
        leader = str(row.get("leader_code", "")).strip()
        if fill_defaults:
            strategy = strategy or default_code(name, "STRATEGY")
            leader = leader or default_code(name, "LEADER")
        result.append(
            {
                "team_number": number,
                "team_name": name,
                "strategy_code": strategy,
                "leader_code": leader,
            }
        )
    return result


def write_json(rows):
    PRIVATE_JSON.write_text(
        json.dumps({"season": 2027, "teams": rows}, indent=2, ensure_ascii=False)
        + "\n",
        encoding="utf-8",
    )


def generate_json():
    existing = {}
    if PRIVATE_JSON.exists():
        existing = {row["team_number"]: row for row in load_rows(fill_defaults=False)}

    fetched = {}
    for team in fetch_teams():
        key = str(team.get("key", ""))
        number = team.get("team_number")
        if number is None:
            number = key.removeprefix("frc")
        try:
            number = int(number)
        except (TypeError, ValueError):
            continue
        if number > 0:
            fetched[number] = str(
                team.get("nickname") or team.get("name") or f"Team {number}"
            )
    if not fetched:
        raise RuntimeError("TBA returned no Israeli district teams.")

    rows = []
    # Teams from TBA (keeping codes you already changed) ...
    for number, tba_name in fetched.items():
        old = existing.get(number, {})
        name = old.get("team_name") or tba_name
        rows.append(
            {
                "team_number": number,
                "team_name": name,
                "strategy_code": old.get("strategy_code")
                or default_code(name, "STRATEGY"),
                "leader_code": old.get("leader_code") or default_code(name, "LEADER"),
            }
        )
    # ... plus teams you added to the JSON by hand that TBA does not list.
    for number, old in existing.items():
        if number not in fetched:
            name = old["team_name"]
            rows.append(
                {
                    **old,
                    "strategy_code": old["strategy_code"]
                    or default_code(name, "STRATEGY"),
                    "leader_code": old["leader_code"] or default_code(name, "LEADER"),
                }
            )
    rows.sort(key=lambda row: row["team_number"])
    write_json(rows)
    print(f"Wrote {PRIVATE_JSON} with {len(rows)} teams.")
    print("Edit the codes in that file, then run:  python tool/team_codes_admin.py push")


def sql_quote(value):
    return "'" + str(value).replace("'", "''") + "'"


def generate_sql():
    rows = load_rows()
    catalog_values = ",\n".join(
        f"  ({r['team_number']}, {sql_quote(r['team_name'])})" for r in rows
    )
    code_values = ",\n".join(
        f"  ({r['team_number']}, {sql_quote(r['strategy_code'])}, "
        f"{sql_quote(r['leader_code'])})"
        for r in rows
    )
    sql = f"""begin;

insert into public.team_catalog(team_number, team_name)
values
{catalog_values}
on conflict (team_number) do update
set team_name = excluded.team_name;

insert into public.team_role_codes(team_number, strategy_code, leader_code)
values
{code_values}
on conflict (team_number) do update
set strategy_code = excluded.strategy_code,
    leader_code = excluded.leader_code;

commit;
"""
    PRIVATE_SQL.write_text(sql, encoding="utf-8")
    print(f"Created {PRIVATE_SQL}. Run it in the Supabase SQL editor.")
    print("Keep both private files out of source control and shared folders.")


def supabase_url():
    source = SUPABASE_CONFIG_PATH.read_text(encoding="utf-8")
    match = re.search(
        r"static const String url\s*=\s*String\.fromEnvironment\(.*?"
        r"defaultValue:\s*'([^']+)'",
        source,
        re.DOTALL,
    )
    url = os.environ.get("SUPABASE_URL", "").strip() or (
        match.group(1) if match else ""
    )
    if not url:
        raise RuntimeError(f"Could not read the Supabase URL from {SUPABASE_CONFIG_PATH}")
    return url.rstrip("/")


def rest_upsert(base, key, table, rows):
    headers = {
        "apikey": key,
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates,return=minimal",
    }
    if key.startswith("eyJ"):  # legacy service_role keys are JWTs
        headers["Authorization"] = f"Bearer {key}"
    request = urllib.request.Request(
        f"{base}/rest/v1/{table}?on_conflict=team_number",
        data=json.dumps(rows).encode("utf-8"),
        headers=headers,
        method="POST",
    )
    try:
        urllib.request.urlopen(request, timeout=60).read()
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", "replace")
        raise RuntimeError(f"Supabase refused the update of {table} "
                           f"({error.code}): {detail}") from error
    except (urllib.error.URLError, TimeoutError) as error:
        raise RuntimeError(f"Could not reach Supabase: {error}") from error


def push_codes():
    key = os.environ.get("SUPABASE_SERVICE_KEY", "").strip()
    if not key:
        raise RuntimeError(
            "Set the SUPABASE_SERVICE_KEY environment variable first (Supabase "
            "Dashboard -> Project Settings -> API Keys -> the SECRET / service_role "
            "key). Never put that key in the app or in git. "
            "Without it use the 'sql' action instead."
        )
    rows = load_rows()
    base = supabase_url()
    rest_upsert(
        base,
        key,
        "team_catalog",
        [{"team_number": r["team_number"], "team_name": r["team_name"]} for r in rows],
    )
    rest_upsert(
        base,
        key,
        "team_role_codes",
        [
            {
                "team_number": r["team_number"],
                "strategy_code": r["strategy_code"],
                "leader_code": r["leader_code"],
            }
            for r in rows
        ],
    )
    print(f"Done - {len(rows)} teams updated in Supabase. The new codes work now.")


def main():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("action", choices=("generate", "push", "sql"))
    args = parser.parse_args()
    actions = {"generate": generate_json, "push": push_codes, "sql": generate_sql}
    try:
        actions[args.action]()
    except (OSError, RuntimeError, ValueError, KeyError) as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
