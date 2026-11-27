# Elysium 1937 Scouting App  (Flutter + Supabase)

FRC Elysium 1937 (Team 1937) scouting app, built with Flutter and Supabase for Android, iOS, web and desktop.
The app is **offline-first**: it works without an internet connection, and syncs data when a connection is available. It has three roles: Scouter, Strategy (super scouting + live data) and Leader (everything: scout rankings, moderation, match / super / pit scouting, data and creating competitions).

## Setup

### 1. Supabase (once per Supabase project)
1. Dashboard -> *SQL Editor* -> *New query* -> paste ALL of `supabase_setup.sql` -> *Run*.
   The last result must list **5 functions** (`app_login`, `app_signup`,
   `delete_scouting_record`, `delete_super_scouting_record`, `create_competition`). If you get an error,
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
app. The proxy only permits the app's 2027 Israeli district team, event, roster,
match, and individual team lookups.

The app caches TBA teams, district events, and match schedules locally for
offline use. Registration loads Israeli district teams for 2027 and shows their
team avatars. Event team pickers and the schedule competition selector use the
2027 Israel district event/roster data from TBA; no event key needs to be
entered manually. Signup also permits manual team selection if TBA is
unavailable.

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
- [ ] the leader can change his team's access codes (strategy and leader) and the new codes will be updated in the database and in the app
- [ ] changes in the normal scouting form: the first screen after choosing the team & match, there will be a screen asking "Did the robot show up to the match?" if the answer is no, the form will be submitted with all the fields empty and a note that the robot didn't show up, if the answer is yes, the form will continue as normal.
- [ ] instead of the current starting position choosing I want to make a photo of the 2026 REBUILT blue alliance zone from the top view (a photo from the internet!), and the user can choose on the photo the starting position of the robot (left trench, left bumper, right bumper, right trench, hub) and the starting position will be saved in the form.
- [ ] the autonomous part in the normal scouting form -  a screen with a slider 1-10 asking "How many fuels did the robot shoot?" and every number will have a description of how many fuels it means, a counter "How many cycles did the robot do?" and every number will have a description of how many cycles it means, and another slider "How many fules did the robot deliver?" and every number will have a description of how many fules it means, and another slider "How fast was the robot intake" and every number will have a description of intake speed it means. + an option to choose the robot exit path (a photo of the 2026 REBUILT blue alliance zone from the top view, and the user can choose on the photo the path the robot took to exit the alliance zone (left trench, left bumper, right bumper, right trench, none) and the path will be saved in the form.) + a slider 1-5 of "Overall autonomous performance" and every number will have a description of how good the robot did in the autonomous.
- [ ] the teleop part in the normal scouting form - a question "Can the robot shoot while moving?" and a yes/no buttons ,a slider 1-10 asking "How many fuels did the robot shoot?" and every number will have a description of how many fuels it means, a counter "How many cycles did the robot do?", another slider "How many fules did the robot deliver?" and every number will have a description of how many fules it means, and another slider "How fast was the robot intake?" and every number will have a description of intake speed it means, a slider "How accurate is the robot shooting?" 1-5 and every number will have a description of how accurate it means, and a slider "Overall teleop performance" 1-10 and every number will have a description of how good the robot did in the teleop.
- [ ] the defence & climb part in the normal scouting form (after the teleop part) - a yes/no question "Did the robot played defence?" if yes, a slider 1-5 asking "How good was the robot in defence?" and every number will have a description of how good it means, another yes/no question "Did the robot was dealing with defence?" if yes, a slider 1-5 asking "How good was the robot in dealing with defence?" and every number will have a description of how good it means, a slider 1-10 of "How good was the driver" and every number will have a description of how good it means, another yes/no question "Did the robot climb?" if yes, a slider (L1, L2, L3) and a counter "How much time did the robot took to climb?" + an option to write notes about the game.
- [ ] the leader can assign to his scouters/strategies a specific match to scout, and the scouter/strategy will see only the match that was assigned to him/her in the app.
- [ ] a profile page for every user, with the user's name, role, team, and a list of all the forms submitted by the user, an option to change their password/name, an option to delete their account, and an option to log out, an option to switch to dark mode, and an option to switch the app language (english/hebrew).
- [ ] find a way to load the team's logo faster, maybe by using a different image format or by caching the images in the app.
- [ ] note that some of the normal scouting changes can be applied to the super scouting form as well, but not all of them, and some of them will be different in the super scouting form.