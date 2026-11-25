#!/usr/bin/env python3
"""Create a local-only JSON roster for manually assigned role access codes."""

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = ROOT / "lib" / "config" / "supabase_config.dart"
PRIVATE_JSON = ROOT / "team_role_codes.private.json"
PRIVATE_SQL = ROOT / "team_role_codes_seed.private.sql"
TEAM_LIST_PATH = "/district/2027isr/teams/simple"


def supabase_config():
    source = CONFIG_PATH.read_text(encoding="utf-8")
    values = {}
    for key in ("url", "publishableKey"):
        match = re.search(
            rf"static const String {key}\s*=\s*String\.fromEnvironment\(.*?"
            rf"defaultValue:\s*'([^']+)'",
            source,
            re.DOTALL,
        )
        if not match:
            raise RuntimeError(f"Could not read {key} from {CONFIG_PATH}")
        values[key] = match.group(1)
    return (
        os.environ.get("SUPABASE_URL", values["url"]).rstrip("/"),
        os.environ.get("SUPABASE_KEY", values["publishableKey"]),
    )


def fetch_teams():
    url, key = supabase_config()
    request = urllib.request.Request(
        f"{url}/functions/v1/tba-proxy",
        data=json.dumps({"path": TEAM_LIST_PATH}).encode("utf-8"),
        headers={
            "apikey": key,
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            teams = json.loads(response.read().decode("utf-8"))
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as error:
        raise RuntimeError(
            "Could not fetch the team roster. Deploy tba-proxy and verify "
            "the Supabase URL/key before generating the private file."
        ) from error

    if not isinstance(teams, list):
        raise RuntimeError(f"TBA proxy returned an unexpected response: {teams}")
    return teams


def read_existing():
    if not PRIVATE_JSON.exists():
        return {}
    try:
        old = json.loads(PRIVATE_JSON.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise RuntimeError(f"{PRIVATE_JSON} is not valid JSON") from error
    rows = old.get("teams") if isinstance(old, dict) else None
    if not isinstance(rows, list):
        raise RuntimeError(f"{PRIVATE_JSON} must contain a 'teams' array")
    return {
        int(row["team_number"]): row
        for row in rows
        if isinstance(row, dict) and str(row.get("team_number", "")).isdigit()
    }


def generate_json():
    existing = read_existing()
    teams = []
    for team in fetch_teams():
        key = str(team.get("key", ""))
        number = team.get("team_number")
        if number is None:
            number = key.removeprefix("frc")
        try:
            number = int(number)
        except (TypeError, ValueError):
            continue
        if number <= 0:
            continue
        old = existing.get(number, {})
        name = str(team.get("nickname") or team.get("name") or f"Team {number}")
        teams.append(
            {
                "team_number": number,
                "team_name": name,
                "strategy_code": str(old.get("strategy_code", "")),
                "leader_code": str(old.get("leader_code", "")),
            }
        )
    teams.sort(key=lambda row: row["team_number"])
    if not teams:
        raise RuntimeError("The TBA proxy returned no Israeli district teams.")

    PRIVATE_JSON.write_text(
        json.dumps({"season": 2027, "teams": teams}, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Created {PRIVATE_JSON} with {len(teams)} teams.")
    print("Existing codes were preserved; new team code fields are blank.")


def sql_quote(value):
    return "'" + str(value).replace("'", "''") + "'"


def generate_sql():
    if not PRIVATE_JSON.exists():
        raise RuntimeError("Generate the private JSON roster first.")
    data = json.loads(PRIVATE_JSON.read_text(encoding="utf-8"))
    teams = data.get("teams") if isinstance(data, dict) else None
    if not isinstance(teams, list) or not teams:
        raise RuntimeError("The private JSON must contain a non-empty teams array.")

    rows = []
    for row in teams:
        if not isinstance(row, dict):
            raise RuntimeError("Each team entry must be a JSON object.")
        number = int(row["team_number"])
        name = str(row["team_name"]).strip()
        strategy_code = str(row["strategy_code"]).strip()
        leader_code = str(row["leader_code"]).strip()
        if number <= 0 or not name or not strategy_code or not leader_code:
            raise RuntimeError(
                f"Complete both role codes and the team name for team {number}."
            )
        rows.append((number, name, strategy_code, leader_code))

    catalog_values = ",\n".join(
        f"  ({number}, {sql_quote(name)})" for number, name, _, _ in rows
    )
    code_values = ",\n".join(
        f"  ({number}, {sql_quote(strategy)}, {sql_quote(leader)})"
        for number, _, strategy, leader in rows
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "action",
        choices=("generate", "sql"),
        help="'generate' creates/refreshes the private roster; 'sql' creates its SQL seed",
    )
    args = parser.parse_args()
    try:
        generate_json() if args.action == "generate" else generate_sql()
    except (OSError, RuntimeError, ValueError, KeyError) as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
