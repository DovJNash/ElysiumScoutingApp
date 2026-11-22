# Elysium 1937 Scouting App  (Flutter + Supabase)

Offline-first FRC scouting app: Scouter, Strategy (super scouting + live data) and
Leader (scout rankings + moderation). Elysium 1937 branding.

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
1. Copy the **contents of this ZIP's folder into your Flutter project folder**
   (`lib/`, `assets/`, `tool/`, `native_icons/`, `pubspec.yaml`, ...).
   The ZIP deliberately has **no** `android/`, `ios/`, `web/` ... folders, so copying it
   can never overwrite or delete your native project files.
2. In the project folder run, once:
   ```
   dart tool/setup_platforms.dart
   flutter clean
   flutter pub get
   ```
   `setup_platforms.dart`:
   * rebuilds missing `android/`, `ios/`, `web/`, `windows/` files with `flutter create`
     (your `lib/` code is never touched),
   * installs the Elysium launcher icons for every platform,
   * sets the app name **"Elysium 1937 Scouting App"**,
   * fixes the Android manifest (icon, INTERNET permission, Flutter v2 embedding),
   * prepares iOS (minimum iOS 13).
   It is safe to run again.
3. `flutter run -d chrome`, or `flutter build apk` / `flutter build appbundle`.

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
Already prepared for you: app name, Elysium icon set (all sizes, no transparency),
iOS 13 minimum, export-compliance flag (the app only uses HTTPS), and the keyboard fix
(tap outside a field closes the keyboard - the iPhone number pad has no "Done" key).

No Mac? Put the project on GitHub and run the workflow in
`.github/workflows/build-ios.yml` (Actions -> *Build iOS (no signing)* -> Run workflow).
That checks that the iOS build compiles. An installable IPA / TestFlight build also
needs an Apple Developer account ($99/year) and signing (e.g. via Codemagic or Xcode).

## Where things are
| What | File |
|---|---|
| Supabase URL / key | `lib/config/supabase_config.dart` |
| Colors / logo / card styles | `lib/theme/elysium_theme.dart` |
| Logos (transparent PNG) | `assets/images/` |
| App icon master (1024 px) / all generated icons | `branding/app_icon_1024.png` / `native_icons/` |
| Competitions + teams | `assets/competitions.json` |
| Form options / super-scouting fields | `lib/models/scouting_form_config.dart` |
| Offline storage | `lib/services/local_db_*.dart` (SQLite on Android/iOS/macOS, JSON store on web/Windows/Linux) |
| Upload / download / connectivity | `lib/services/sync_service.dart`, `data_repository.dart` |

## Roles (identical text in the app and in the database)
`Scouter`, `Strategy`, `Leader`.
Scouter deletes only his own forms, Strategy only his own reports, Leader any form
(enforced in the database by the `delete_*_record` functions).

## Troubleshooting
* **"Could not find the function public.app_signup ... in the schema cache"** - the SQL was
  not run in the project the app points to, or it stopped with an error. Run
  `supabase_setup.sql` again (check the 4-function list at the end), wait ~10 s, retry.
* **Android build: "resource drawable/icon_512 not found"** - run
  `dart tool/setup_platforms.dart`, then `flutter clean`.
* **"Build failed due to use of deleted Android v1 embedding"** - the native `android/`
  files are missing or old (for example after an `android` folder was replaced). Run
  `dart tool/setup_platforms.dart` (it rebuilds them), then `flutter clean`.
  Manual way: `flutter create --platforms=android,ios,web,windows --org com.elysium1937 .`
  then `dart tool/setup_platforms.dart`.
* **Release APK can't log in / sync** - the INTERNET permission is missing
  (the setup script adds it).
* The badge in the top bar shows Live / Syncing / Offline / Problem; tap *Problem* for the reason.
