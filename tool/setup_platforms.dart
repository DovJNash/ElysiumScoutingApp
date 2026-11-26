// One-time platform setup for "Elysium 1937 Scouting App".
//
// Run it from the root of your Flutter project (the folder with pubspec.yaml):
//
//     dart tool/setup_platforms.dart
//     dart tool/setup_platforms.dart --bundle-id=com.elysium1937.scouting   (iOS id, optional)
//
// What it does (safe to run again - it only changes what is not set yet):
//   * Android : app name, launcher icon reference (fixes "resource
//               drawable/icon_512 not found"), INTERNET permission (required
//               for release builds, otherwise login/sync fail)
//   * iOS     : app name, export-compliance flag, minimum iOS 13 (Podfile + project)
//   * Web     : page title, PWA name, theme colors
//   * Windows : window title + file description
//   * macOS   : app name + network permission (sandbox)
//
// If the android / ios / web / windows folders of your project are missing or
// incomplete it first runs `flutter create` to rebuild them (your lib/ code is
// never touched), then installs the Elysium icons from native_icons/.
import 'dart:io';

const String appName = 'Elysium 1937 Scouting App';
const String shortName = 'Elysium 1937';
const String description =
    'Offline-first FRC scouting, strategy and lead analytics for Elysium 1937.';

void main(List<String> args) {
  if (!File('pubspec.yaml').existsSync() || !Directory('lib').existsSync()) {
    stderr.writeln(
        'Run this from the root of your Flutter project (the folder that contains pubspec.yaml).');
    exit(1);
  }
  String? bundleId;
  for (final a in args) {
    if (a.startsWith('--bundle-id=')) bundleId = a.substring('--bundle-id='.length);
  }
  print('Setting up platform files for "$appName"\n');
  _ensureNativeProjects();
  _installIcons();
  _android();
  _ios(bundleId);
  _web();
  _windows();
  _macos();
  print('\nDone. Now run:   flutter clean   and then   flutter pub get');
}

// ------------------------------------------------- native project + icons
String _pubspecName() {
  final m = RegExp(r'^name:\s*(\S+)', multiLine: true)
      .firstMatch(File('pubspec.yaml').readAsStringSync());
  return m?[1] ?? 'frc_scouting_app';
}

/// Rebuilds missing native project files with `flutter create` (existing files
/// and everything in lib/ are left alone).
void _ensureNativeProjects() {
  final missing = <String>[];
  if (!File('android/app/src/main/AndroidManifest.xml').existsSync()) {
    missing.add('android');
  }
  if (!File('ios/Runner/Info.plist').existsSync()) missing.add('ios');
  if (!File('web/index.html').existsSync()) missing.add('web');
  if (!File('windows/runner/main.cpp').existsSync()) missing.add('windows');
  if (missing.isEmpty) return;

  print('Missing native project files for: ${missing.join(', ')}');
  print('Running flutter create to rebuild them (this takes a minute)...\n');
  final result = Process.runSync(
    'flutter',
    [
      'create',
      '--platforms=${missing.join(',')}',
      '--org',
      'com.elysium1937',
      '--project-name',
      _pubspecName(),
      '.',
    ],
    runInShell: true,
  );
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    print('\n! flutter create failed. Run this yourself and then run this script again:');
    print('    flutter create --platforms=${missing.join(',')} --org com.elysium1937 .');
    exit(1);
  }

  // flutter create adds a sample test that does not fit this app.
  final t = File('test/widget_test.dart');
  if (t.existsSync() && t.readAsStringSync().contains('MyApp')) {
    t.deleteSync();
  }
  print('');
}

/// Copies native_icons/<platform>/... into the matching place of the project.
void _installIcons() {
  final src = Directory('native_icons');
  if (!src.existsSync()) {
    print('  ! native_icons folder not found - copy it from the ZIP.');
    return;
  }
  var count = 0;
  for (final e in src.listSync(recursive: true)) {
    if (e is! File) continue;
    final rel = e.path.substring(src.path.length + 1);
    final platform = rel.split(RegExp(r'[\\/]')).first;
    if (!Directory(platform).existsSync()) continue; // platform not in project
    final target = File(rel);
    target.parent.createSync(recursive: true);
    e.copySync(target.path);
    count++;
  }
  print('Elysium icons: $count files installed\n');
}

// ---------------------------------------------------------------- helpers
void _edit(String path, String label, String Function(String) change) {
  final f = File(path);
  if (!f.existsSync()) {
    print('  - $label: skipped ($path not found)');
    return;
  }
  try {
    final before = f.readAsStringSync();
    final after = change(before);
    if (after == before) {
      print('  = $label: already OK');
    } else {
      f.writeAsStringSync(after);
      print('  + $label');
    }
  } catch (e) {
    print('  ! $label: FAILED ($e) - do this step by hand (see README)');
  }
}

String _plistString(String s, String key, String value) {
  final re = RegExp('(<key>$key</key>\\s*<string>)[^<]*(</string>)');
  if (re.hasMatch(s)) {
    return s.replaceAllMapped(re, (m) => '${m[1]}$value${m[2]}');
  }
  final i = s.lastIndexOf('</dict>');
  if (i < 0) return s;
  return '${s.substring(0, i)}\t<key>$key</key>\n\t<string>$value</string>\n${s.substring(i)}';
}

String _plistBool(String s, String key, bool value) {
  final tag = value ? '<true/>' : '<false/>';
  final re = RegExp('(<key>$key</key>\\s*)<(?:true|false)\\s*/>');
  if (re.hasMatch(s)) {
    return s.replaceAllMapped(re, (m) => '${m[1]}$tag');
  }
  final i = s.lastIndexOf('</dict>');
  if (i < 0) return s;
  return '${s.substring(0, i)}\t<key>$key</key>\n\t$tag\n${s.substring(i)}';
}

// ---------------------------------------------------------------- Android
void _android() {
  print('Android');
  _edit('android/app/src/main/AndroidManifest.xml',
      'AndroidManifest.xml (name, icon, internet)', (s) {
    s = s.replaceAll(RegExp(r'android:label="[^"]*"'), 'android:label="$appName"');

    // Old broken reference from earlier attempts.
    s = s.replaceAll('@drawable/icon_512', '@mipmap/ic_launcher');

    final iconAttr = RegExp(r'android:icon="[^"]*"');
    if (iconAttr.hasMatch(s)) {
      s = s.replaceAll(iconAttr, 'android:icon="@mipmap/ic_launcher"');
    } else {
      s = s.replaceFirst(
          '<application', '<application\n        android:icon="@mipmap/ic_launcher"');
    }

    final roundAttr = RegExp(r'android:roundIcon="[^"]*"');
    if (roundAttr.hasMatch(s)) {
      s = s.replaceAll(roundAttr, 'android:roundIcon="@mipmap/ic_launcher_round"');
    } else {
      s = s.replaceFirst('<application',
          '<application\n        android:roundIcon="@mipmap/ic_launcher_round"');
    }

    // Android "v2 embedding" (the v1 embedding was deleted from Flutter; a
    // manifest without this entry fails with "use of deleted Android v1 embedding").
    s = s.replaceAll('io.flutter.app.FlutterApplication', r'${applicationName}');
    final embed = RegExp(r'<meta-data[^>]*android:name="flutterEmbedding"[^>]*>');
    if (embed.hasMatch(s)) {
      s = s.replaceAllMapped(embed,
          (m) => m[0]!.replaceAll('android:value="1"', 'android:value="2"'));
    } else {
      final end = s.lastIndexOf('</application>');
      if (end >= 0) {
        s = '${s.substring(0, end)}    <meta-data\n            android:name="flutterEmbedding"\n            android:value="2" />\n    ${s.substring(end)}';
      }
    }

    if (!s.contains('android.permission.INTERNET')) {
      final i = s.indexOf('<application');
      if (i >= 0) {
        s = '${s.substring(0, i)}<uses-permission android:name="android.permission.INTERNET"/>\n    ${s.substring(i)}';
      }
    }
    return s;
  });
  _checkAndroidSources();
}

/// Warns when MainActivity is still written for the deleted v1 embedding.
void _checkAndroidSources() {
  final dir = Directory('android/app/src/main');
  if (!dir.existsSync()) return;
  var found = false;
  var old = false;
  for (final e in dir.listSync(recursive: true)) {
    if (e is! File) continue;
    if (!(e.path.endsWith('.kt') || e.path.endsWith('.java'))) continue;
    final text = e.readAsStringSync();
    if (text.contains('FlutterActivity')) found = true;
    if (text.contains('io.flutter.app.FlutterActivity') ||
        text.contains('registerWith(this)') ||
        text.contains('registerWith(FlutterEngine')) {
      old = true;
    }
  }
  if (!found || old) {
    print('  ! MainActivity is missing or still uses the old Android v1 code.');
    print('    Fix: delete the android folder, run   flutter create --platforms=android .');
    print('    then copy this ZIP over the project again and re-run this script.');
  }
}

// -------------------------------------------------------------------- iOS
void _ios(String? bundleId) {
  print('iOS');
  _edit('ios/Runner/Info.plist', 'Info.plist (name, export compliance)', (s) {
    s = _plistString(s, 'CFBundleDisplayName', appName);
    s = _plistString(s, 'CFBundleName', appName);
    s = _plistBool(s, 'ITSAppUsesNonExemptEncryption', false);
    return s;
  });
  _edit('ios/Podfile', 'Podfile (iOS 13)', (s) {
    final re = RegExp(r'^#?\s*platform :ios,.*$', multiLine: true);
    if (re.hasMatch(s)) {
      return s.replaceFirst(re, "platform :ios, '13.0'");
    }
    return "platform :ios, '13.0'\n$s";
  });
  if (bundleId != null && bundleId.isNotEmpty) {
    _edit('ios/Runner.xcodeproj/project.pbxproj', 'project.pbxproj (bundle id)',
        (s) {
      return s.replaceAllMapped(RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);'),
          (m) {
        final id = m[1]!.contains('RunnerTests') ? '$bundleId.RunnerTests' : bundleId;
        return 'PRODUCT_BUNDLE_IDENTIFIER = $id;';
      });
    });
  }
  _edit('ios/Runner.xcodeproj/project.pbxproj', 'project.pbxproj (iOS 13)', (s) {
    return s.replaceAll(RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;'),
        'IPHONEOS_DEPLOYMENT_TARGET = 13.0;');
  });
  _edit('ios/Flutter/AppFrameworkInfo.plist', 'AppFrameworkInfo.plist (iOS 13)',
      (s) {
    return s.replaceAllMapped(
        RegExp(r'(<key>MinimumOSVersion</key>\s*<string>)[^<]*(</string>)'),
        (m) => '${m[1]}13.0${m[2]}');
  });
}

// -------------------------------------------------------------------- Web
void _web() {
  print('Web');
  _edit('web/index.html', 'index.html (title)', (s) {
    s = s.replaceFirst(RegExp(r'<title>[^<]*</title>'), '<title>$appName</title>');
    s = s.replaceAllMapped(
        RegExp(r'(<meta name="apple-mobile-web-app-title" content=")[^"]*(")'),
        (m) => '${m[1]}$appName${m[2]}');
    s = s.replaceAllMapped(
        RegExp(r'(<meta name="description" content=")[^"]*(")'),
        (m) => '${m[1]}$description${m[2]}');
    return s;
  });
  _edit('web/manifest.json', 'manifest.json (name, colors)', (s) {
    s = s.replaceFirst(RegExp(r'"name"\s*:\s*"[^"]*"'), '"name": "$appName"');
    s = s.replaceFirst(
        RegExp(r'"short_name"\s*:\s*"[^"]*"'), '"short_name": "$shortName"');
    s = s.replaceFirst(
        RegExp(r'"description"\s*:\s*"[^"]*"'), '"description": "$description"');
    s = s.replaceFirst(RegExp(r'"background_color"\s*:\s*"[^"]*"'),
        '"background_color": "#FFFFFF"');
    s = s.replaceFirst(
        RegExp(r'"theme_color"\s*:\s*"[^"]*"'), '"theme_color": "#0164CC"');
    return s;
  });
}

// ---------------------------------------------------------------- Windows
void _windows() {
  print('Windows');
  _edit('windows/runner/main.cpp', 'main.cpp (window title)', (s) {
    return s.replaceAllMapped(
        RegExp(r'(window\.Create\(L")[^"]*(")'), (m) => '${m[1]}$appName${m[2]}');
  });
  _edit('windows/runner/Runner.rc', 'Runner.rc (file description)', (s) {
    return s.replaceAllMapped(
        RegExp(r'(VALUE "(?:FileDescription|ProductName)", ")[^"]*(")'),
        (m) => '${m[1]}$appName${m[2]}');
  });
}

// ------------------------------------------------------------------ macOS
void _macos() {
  print('macOS');
  _edit('macos/Runner/Info.plist', 'Info.plist (name)', (s) {
    return _plistString(s, 'CFBundleDisplayName', appName);
  });
  for (final f in ['DebugProfile', 'Release']) {
    _edit('macos/Runner/$f.entitlements', '$f.entitlements (network)', (s) {
      return _plistBool(s, 'com.apple.security.network.client', true);
    });
  }
}
