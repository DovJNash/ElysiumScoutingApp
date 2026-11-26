/// ---------------------------------------------------------------------------
///  THE BLUE ALLIANCE (TBA) SETTINGS
///
///  The app talks to TBA directly - no Supabase Edge Function or Supabase
///  secret is needed any more. The read key is stored here as plain text.
///
///  To use another key, either edit [apiKey] below or run with
///    flutter run --dart-define=TBA_KEY=your_key_here
///
///  NOTE: anyone who can open the app / this repository can read this key.
///  It is a read-only key, so the worst case is that somebody uses up your
///  TBA quota; if that happens create a new key at
///  https://www.thebluealliance.com/account and paste it here.
/// ---------------------------------------------------------------------------
class TbaConfig {
  static const String apiKey = String.fromEnvironment(
    'TBA_KEY',
    defaultValue:
        'XUkbdwh639sR03hBcLvAQ8WboJUL5iinN66B7oWgvAiLlfT4WhhcQvxtVNKIRMjC',
  );

  static const String baseUrl = 'https://www.thebluealliance.com/api/v3';

  /// Sent as X-TBA-Auth-Key on every request.
  static const String authHeader = 'X-TBA-Auth-Key';
}
