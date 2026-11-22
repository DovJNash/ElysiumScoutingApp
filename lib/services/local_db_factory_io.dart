import 'dart:io' show Platform;
import 'local_db_prefs.dart';
import 'local_db_service.dart';
import 'local_db_sqlite.dart';

/// SQLite where it is built in (Android, iOS, macOS). Windows / Linux use the
/// JSON store so no extra native sqlite3 library has to be installed.
LocalDbService createLocalDb() {
  if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
    return SqliteLocalDb();
  }
  return PrefsLocalDb();
}
