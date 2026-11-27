# Elysium 1937 Scouting App  (Flutter + Supabase)

FRC Elysium 1937 (Team 1937) scouting app, built with Flutter and Supabase for Android, iOS, web and desktop.
The app is **offline-first**: it works without an internet connection, and syncs data when a connection is available. It has three roles: Scouter, Strategy (super scouting + live data) and Leader (everything: scout rankings, moderation, match / super / pit scouting, data and creating competitions).

## Setup

### 1. Supabase (once per Supabase project)
1. Dashboard -> *SQL Editor* -> *New query* -> paste ALL of `supabase_setup.sql` -> *Run*.
   The last result must list **12 functions** (`app_login`, `app_signup`,
   `delete_scouting_record`, `delete_super_scouting_record`, `create_competition`,
   `leader_update_team_role_codes`, `leader_team_members`,
   `leader_set_match_assignment`, `my_match_assignments`,
   `leader_member_match_assignments`, `profile_update`,
   `profile_delete_account`). If you get an error,
   or the list is shorter, the setup did not finish.
2. Left-over tables from older versions? Run `supabase_reset.sql` first
   (it deletes all data/accounts), then run `supabase_setup.sql` again.
3. There is no team access code for Scouter registration. For each team's
   Strategy and Leader registrations, add that team's distinct codes to the
   private `team_role_codes` table (and add the team to `team_catalog`):
   ```sql
   insert into public.team_catalog(team_number, team_name)
   values (1690, 'Orbit')
   on conflict (team_number) do update set team_name = excluded.team_name;

   insert into public.team_role_codes(team_number, strategy_code, leader_code)
   values (1690, 'TEAM_1690_STRATEGY_CODE', 'TEAM_1690_LEADER_CODE')
   on conflict (team_number) do update set
     strategy_code = excluded.strategy_code,
     leader_code = excluded.leader_code;
   ```
   For example, to configure Team 1937:
   ```sql
   insert into public.team_catalog(team_number, team_name)
   values (1937, 'Elysium')
   on conflict (team_number) do update set team_name = excluded.team_name;

   insert into public.team_role_codes(team_number, strategy_code, leader_code)
   values (1937, 'TEAM_1937_STRATEGY_CODE', 'TEAM_1937_LEADER_CODE')
   on conflict (team_number) do update set
     strategy_code = excluded.strategy_code,
     leader_code = excluded.leader_code;
   ```
   Repeat with unique codes per team; never use the example placeholders as
   real access codes. Keep these values in Supabase's private table or another
   admin-only store. Do not bundle role-registration codes in app JSON/assets:
   anyone with the app could read them and register as a Strategy user or Leader.
4. Put the project's URL and publishable key in `lib/config/supabase_config.dart`
   (Dashboard -> Project Settings -> API). They must belong to the same project
   where you ran the SQL.

### 1.1 The Blue Alliance
The TBA key belongs on the server, not in the APK. In Supabase Dashboard, open
**Edge Functions -> Secrets** and add `TBA_API_KEY` with your TBA read key.
Then deploy the read-only, allowlisted proxy from the repository root:
```
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase functions deploy tba-proxy
```
Deploy this once per Supabase project. The app and every installed APK use the
proxy, so users do not need to supply a TBA key and it is not embedded in the
app. The proxy only permits 2026/2027 Israeli events, districts, rosters,
matches, and individual team lookups.
If the app reports that `tba-proxy` was not found, deploy it to the same
Supabase project configured in `lib/config/supabase_config.dart`. Previously
cached event, team, and schedule data remains available while the proxy is
unavailable.

The app caches Israeli TBA events, teams, and match schedules locally for
offline use, and caches team logos on disk. Registration loads Israeli district
teams for 2027 and shows their team avatars. Competition and schedule screens
let users choose 2026 or 2027 and list Israeli TBA events for that year; event
team pickers use the roster from TBA. No event key needs to be entered
manually. Signup also permits manual team selection if TBA is unavailable.

### 1.2 Private team role-code file
The Strategy/Leader codes are not available from TBA; use the codes you assign
to each team. To create a local JSON roster from the 2027 Israeli TBA teams,
after deploying `tba-proxy`, run from the project root:
```
python tool/team_codes_admin.py generate
```
Enter each team's existing Strategy and Leader codes in
`team_role_codes.private.json`. Generate the SQL to seed Supabase:
```
python tool/team_codes_admin.py sql
```
Run `team_role_codes_seed.private.sql` in the Supabase SQL Editor. Both output
files are excluded by `.gitignore`; keep them on your own computer and do not
commit or share them. The generator preserves already-entered codes when it
refreshes the team roster.

### 2. Flutter project
1. In the project folder run, once:
   ```
   dart tool/setup_platforms.dart
   flutter clean
   flutter pub get
   ```
   `setup_platforms.dart`:

2. `flutter run -d chrome`, or `flutter build apk` / `flutter build appbundle`.

Rebuilt native folders use the app id `com.elysium1937.<project name>`
(for example `com.elysium1937.frc_scouting_app`). An app installed earlier under a
different id stays installed as a separate app - uninstall it.

### Manual fallback (if the script reports "FAILED" for a file)
* **Android** `android/app/src/main/AndroidManifest.xml`: in `<application ...>` set
  `android:label="Elysium 1937 Scouting App"`, `android:icon="@mipmap/ic_launcher"`,
  `android:roundIcon="@mipmap/ic_launcher_round"`, and above `<application` add
  `<uses-permission android:name="android.permission.INTERNET"/>`.
* **iOS** `ios/Runner/Info.plist`: set `CFBundleDisplayName` and `CFBundleName` to the name.

## iOS
Building for iPhone/iPad needs macOS + Xcode (Apple does not allow it on Windows).
On a Mac:
```
flutter pub get
dart tool/setup_platforms.dart
cd ios && pod install && cd ..
open ios/Runner.xcworkspace     # Runner -> Signing & Capabilities: choose your Team,
                                # and change the Bundle Identifier from com.example.* to your own
flutter build ipa               # or press Run in Xcode to install on your device
```

## Roles (identical text in the app and in the database)
`Scouter`, `Strategy`, `Leader`.
Every account deletes only the forms it submitted itself; a Leader can also delete forms of accounts of the Leader's own team
(enforced in the database by the `delete_*_record` functions).


# Future features
- [x] Use data from The Blue Alliance (TBA) to pre-fill team numbers and match schedules.
- [x] Add a "match schedule" page for every role, with live match data.
- [x] Add an "Overall Rankings" page for Leader role, with live data from all teams from all competitions.
- [x] When login/signup dont use the internet, download the db and make it work offline
- [x] in scouter form, instead of counting how much the robot intake, change it to how many balls the robot shoot into his aliiance zone and call it "how many fuels the robot pass to his alliance zone"
- [x] in the scout performance ranking, write how do you calcculate it
- [x] for every team that's want to use our app there will be different access code, other teams cant delete other teams forms but they can see them (it's means that in the register screen before the member choose a roll hw need to choose his team)
- [x] the scouter can do only scouting, the stragedy can do scouting, super scouting and data, and leader everything
- [x] in the deleting forms, if the same game have 3 or more forms it will show which forms are more accurate in green and in red which are not so accurate
- [x] the leader can create new competitions with existing teams
- [x] another type of scouting: pit scouting, (first we need to choose to which team we do pit scouting, this scouting type is only for stragety and leader) the questions: What are the autonomus types of the team, hhat they do good, what they difficult with, how they do diffence ect. and all is a phrase
- [x] Add a language swith (english and hebrew, and make the font in hebrew looks good, the font in hebrew will be assistant)

# Future features V2
- [x] the leader has access to: Ranking, Overall, Form, Data, schedule, scouting, super scouting, pit scouting, add competition
- [x] in the add competition when choosing the teams to be in the competition, instead of writing the teams numbers just make it a checklist with all the team in ISR 2027
- [x] in the data, i want to see a list of every team and all of their pit scouting forms data (the team name logo and number, how many forms have been submitted for these teams, and all the forms data organized)

## Leader / V2 notes
- **Leader tabs:** Rankings, Forms, Data, Overall, Schedule, Super Scouting, Pit. The
  *Match Scouting* button in the top bar opens the normal match-scouting flow, and the
  *Create competition* button creates a competition.
- **Create competition:** the Leader enters an ID and a name and ticks the teams from the
  checklist of all Israeli district teams (searchable, with *Select all* / *Clear*).
  The competition is saved in Supabase through the `create_competition` function (only a
  Leader may call it), so every device sees it, and it is cached for offline use. Re-run
  `supabase_setup.sql` once to install that function. If the Leader is offline the
  competition is kept on that device only.
- **Pit data:** in the *Data* tab (Strategy and Leader) switch to *Pit data* to see every team
  of the selected competition with its logo, number, name and how many pit forms were
  submitted for it. Open a team to read the data of all of its forms.

## Future features V3
- [x] Leaders can update their team's Strategy and Leader access codes through the app; codes remain in Supabase's private table.
- [x] Normal scouting asks whether the robot showed up. A no-show is submitted with empty gameplay values and a note.
- [x] Starting location and autonomous exit path are selected on a bundled, original top-view field diagram with tappable locations. The app does not bundle an unlicensed internet image.
- [x] Autonomous scouting records fuels shot, cycles, fuels delivered, intake speed, exit path, and overall performance with descriptions for every scale value.
- [x] Teleop scouting records shooting while moving, fuels shot, cycles, fuels delivered, intake speed, shooting accuracy, and overall performance with descriptions for every scale value.
- [x] Defense and climb scouting records yes/no responses, conditional ratings, driver rating, climb level/time, and notes.
- [x] Leaders can assign specific event matches to their team's Scouter and Strategy accounts; those accounts see only assigned matches.
- [x] Every user has a profile with their details, submitted forms, name/password updates, account deletion, logout, dark mode, and English/Hebrew preferences.
- [x] Team logos are cached on disk for faster repeat loading and offline use.
- [x] Super Scouting includes applicable event-level autonomous exit, shooting-while-moving, and climb-capability observations without adding match-only attendance fields.
- [x] Competition and schedule screens allow choosing 2026 or 2027 and show Israeli TBA events for that year, including off-season events listed by TBA.

### V3 notes
- Run the updated `supabase_setup.sql` against the existing project; its additions are forward-compatible and do not require `supabase_reset.sql`.
- Leader access-code and assignment mutations require an internet connection and are verified by Supabase using the Leader's password. Previously loaded assignments remain available offline, and match scouting continues to save locally before syncing.
- Deleting an account also deletes that account's submitted match, Super Scouting, and Pit forms and its assignments.
