import '../models/scouting_entry.dart';
import '../models/super_scouting_entry.dart';
// Web (and unknown platforms) get the default; every dart:io platform gets the
// io factory, which uses SQLite on Android / iOS / macOS.
import 'local_db_factory_web.dart'
    if (dart.library.io) 'local_db_factory_io.dart';

enum LocalTable { scouting, superScouting }

/// Offline storage. Everything a scout submits is written here FIRST, then
/// uploaded by SyncService when the internet is available.
///
/// Implementations: SQLite (mobile / macOS) and a JSON store (web, Windows,
/// Linux). Screens and services only ever use this abstract class.
abstract class LocalDbService {
  static final LocalDbService instance = createLocalDb();

  // Every local write bumps this number (synchronously, before the write is
  // queued). A server download is only applied if nothing was written locally
  // while it was in flight - this removes the "uploaded row flickers away"
  // race between uploads and downloads.
  int _version = 0;
  int get writeVersion => _version;
  void recordLocalWrite() => _version++;

  Future<void> initialize();

  // ------------------------------------------------ primitives (per backend)
  Future<void> putRow(LocalTable table, Map<String, dynamic> row);
  Future<List<Map<String, dynamic>>> getRows(
    LocalTable table, {
    bool unsyncedOnly = false,
  });
  Future<void> setSynced(LocalTable table, String id);
  Future<void> removeRow(LocalTable table, String id);
  Future<void> removeUserRecords(String userId);

  /// Makes the "synced" rows an exact copy of [serverRows] without touching
  /// rows that wait for upload or deletion. Returns false (and writes nothing)
  /// when a local write happened after [expectedVersion] was read.
  Future<bool> replaceSyncedRows(
    LocalTable table,
    List<Map<String, dynamic>> serverRows,
    int expectedVersion,
  );

  Future<void> putDeletion({
    required String recordId,
    required String tableName,
    required String requesterId,
  });
  Future<List<Map<String, dynamic>>> getDeletions();
  Future<void> dropDeletion(String recordId);

  // ------------------------------------------------------- typed wrappers
  Future<void> upsertScouting(ScoutingEntry e) {
    _version++;
    return putRow(LocalTable.scouting, e.toSqliteMap());
  }

  Future<void> upsertSuperScouting(SuperScoutingEntry e) {
    _version++;
    return putRow(LocalTable.superScouting, e.toSqliteMap());
  }

  Future<List<ScoutingEntry>> getAllScouting() async =>
      (await getRows(LocalTable.scouting))
          .map((r) => ScoutingEntry.fromMap(r))
          .toList();

  Future<List<SuperScoutingEntry>> getAllSuperScouting() async =>
      (await getRows(LocalTable.superScouting))
          .map((r) => SuperScoutingEntry.fromMap(r))
          .toList();

  Future<List<ScoutingEntry>> getUnsyncedScouting() async => (await getRows(
        LocalTable.scouting,
        unsyncedOnly: true,
      ))
          .map((r) => ScoutingEntry.fromMap(r))
          .toList();

  Future<List<SuperScoutingEntry>> getUnsyncedSuperScouting() async =>
      (await getRows(
        LocalTable.superScouting,
        unsyncedOnly: true,
      ))
          .map((r) => SuperScoutingEntry.fromMap(r))
          .toList();

  Future<void> markScoutingSynced(String id) {
    _version++;
    return setSynced(LocalTable.scouting, id);
  }

  Future<void> markSuperScoutingSynced(String id) {
    _version++;
    return setSynced(LocalTable.superScouting, id);
  }

  Future<void> deleteScoutingLocal(String id) {
    _version++;
    return removeRow(LocalTable.scouting, id);
  }

  Future<void> deleteSuperScoutingLocal(String id) {
    _version++;
    return removeRow(LocalTable.superScouting, id);
  }

  Future<bool> replaceSyncedScouting(
    List<Map<String, dynamic>> remote,
    int expectedVersion,
  ) =>
      replaceSyncedRows(
        LocalTable.scouting,
        remote
            .map(
              (r) =>
                  ScoutingEntry.fromMap(r, overrideSynced: true).toSqliteMap(),
            )
            .toList(),
        expectedVersion,
      );

  Future<bool> replaceSyncedSuperScouting(
    List<Map<String, dynamic>> remote,
    int expectedVersion,
  ) =>
      replaceSyncedRows(
        LocalTable.superScouting,
        remote
            .map(
              (r) => SuperScoutingEntry.fromMap(r, overrideSynced: true)
                  .toSqliteMap(),
            )
            .toList(),
        expectedVersion,
      );

  Future<void> queueDeletion({
    required String recordId,
    required String tableName,
    required String requesterId,
  }) {
    _version++;
    return putDeletion(
      recordId: recordId,
      tableName: tableName,
      requesterId: requesterId,
    );
  }

  Future<List<Map<String, dynamic>>> getPendingDeletions() => getDeletions();

  Future<void> removePendingDeletion(String recordId) {
    _version++;
    return dropDeletion(recordId);
  }
}
