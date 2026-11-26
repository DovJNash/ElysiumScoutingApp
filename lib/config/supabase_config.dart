/// ---------------------------------------------------------------------------
///  SUPABASE PROJECT SETTINGS  (this is the ONLY place you need to edit when
///  you move to a different Supabase project)
///
///  Supabase Dashboard -> Project Settings -> API
///    * Project URL        -> [url]
///    * Publishable key    -> [publishableKey]   (starts with sb_publishable_)
///
///  You can also override them without touching code:
///    flutter run -d chrome --dart-define=SUPABASE_URL=https://xxxx.supabase.co
///                          --dart-define=SUPABASE_KEY=sb_publishable_xxx
/// ---------------------------------------------------------------------------
class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ohvudupkcdubheylnemo.supabase.co',
  );

  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_KEY',
    defaultValue: 'sb_publishable_AHhfmLXxTMUmnJnuqEHk6A_A2Xv7-Gk',
  );

  /// Short id of the project, e.g. "ohvudupkcdubheylnemo". The saved login and
  /// the offline database are stored per project, so switching to another
  /// Supabase project never mixes old data/accounts with the new project.
  static String get projectRef {
    final host = Uri.tryParse(url)?.host ?? '';
    final ref = host.split('.').first;
    return ref.isEmpty ? 'default' : ref;
  }

  /// Season used for The Blue Alliance team avatars.
  static const int season = 2027;

  /// If an avatar does not exist the app shows the team number instead.
  static String avatarUrl(int teamNumber, [int? year]) =>
      'https://www.thebluealliance.com/avatar/${year ?? season}/frc$teamNumber.png';
}
