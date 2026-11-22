# Elysium 1937 Scouting App  (Flutter + Supabase)

FRC Elysium 1937 (Team 1937) scouting app, built with Flutter and Supabase for Android, iOS, web and desktop.
The app is **offline-first**: it works without an internet connection, and syncs data when a connection is available. It has three roles: Scouter, Strategy (super scouting + live data) and Leader (scout rankings + moderation).

## Setup

### 1. Supabase (once per Supabase project)
1. Dashboard -> *SQL Editor* -> *New query* -> paste ALL of `supabase_setup.sql` -> *Run*.
   The last result must list **4 functions** (`app_login`, `app_signup`,
   `delete_scouting_record`, `delete_super_scouting_record`). If you get an error,
   or the list is shorter, the setup did not finish.
2. Left-over tables from older versions? Run `supabase_reset.sql` first
   (it deletes all data/accounts), then run `supabase_setup.sql` again.
3. Change the two sign-up codes inside `app_signup` (`ELYSIUM-LEAD-1937`,
   `ELYSIUM-STRAT-1937`) before you give the app to the team.
4. Put the project's URL and publishable key in `lib/config/supabase_config.dart`
   (Dashboard -> Project Settings -> API). They must belong to the same project
   where you ran the SQL.

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
Scouter deletes only his own forms, Strategy only his own reports, Leader any form
(enforced in the database by the `delete_*_record` functions).


# Future features
- [ ] Use data from The Blue Alliance (TBA) to pre-fill team numbers and match schedules.
- [ ] Add a "match schedule" page for Strategy and Leader roles, with live match data.
- [ ] Add an "Overall Rankings" page for Leader role, with live data from all teams from all competitions.


