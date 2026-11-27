import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/supabase_config.dart';
import 'local_db_service.dart';

/// JSON-backed offline store (shared_preferences = localStorage on the web).
/// Used on web, Windows and Linux. Same behaviour as the SQLite version.
class PrefsLocalDb extends LocalDbService {
  final Map<LocalTable, Map<String, Map<String, dynamic>>> _rows = {
    LocalTable.scouting: {},
    LocalTable.superScouting: {},
  };
  final Map<String, Map<String, dynamic>> _deletions = {};

  SharedPreferences? _prefs;
  Future<void> _saving = Future<void>.value();

  String get _key => 'frc_local_db_v2_${SupabaseConfig.projectRef}';

  @override
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      final m = json.decode(raw) as Map<String, dynamic>;
      void load(LocalTable t, String name) {
        final list = (m[name] as List<dynamic>? ?? const []);
        for (final r in list) {
          final row = Map<String, dynamic>.from(r as Map);
          _rows[t]![row['ID'].toString()] = row;
        }
      }

      load(LocalTable.scouting, 'scouting');
      load(LocalTable.superScouting, 'superScouting');
      for (final d in (m['deletions'] as List<dynamic>? ?? const [])) {
        final row = Map<String, dynamic>.from(d as Map);
        _deletions[row['recordId'].toString()] = row;
      }
    } catch (_) {
      // Corrupted cache: start empty, the next sync downloads everything.
    }
  }

  Future<void> _persist() {
    final prefs = _prefs;
    if (prefs == null) return Future<void>.value();
    _saving = _saving.then((_) async {
      try {
        await prefs.setString(
          _key,
          json.encode({
            'scouting': _rows[LocalTable.scouting]!.values.toList(),
            'superScouting': _rows[LocalTable.superScouting]!.values.toList(),
            'deletions': _deletions.values.toList(),
          }),
        );
      } catch (_) {}
    });
    return _saving;
  }

  void _removeByUniqueKey(LocalTable t, String uniqueKey, String exceptId) {
    _rows[t]!.removeWhere(
      (id, r) => id != exceptId && r['uniqueKey'] == uniqueKey,
    );
  }

  @override
  Future<void> putRow(LocalTable table, Map<String, dynamic> row) async {
    final id = row['ID'].toString();
    _removeByUniqueKey(table, row['uniqueKey'].toString(), id);
    _rows[table]![id] = Map<String, dynamic>.from(row);
    await _persist();
  }

  @override
  Future<List<Map<String, dynamic>>> getRows(
    LocalTable table, {
    bool unsyncedOnly = false,
  }) async {
    return _rows[table]!
        .values
        .where((r) => !unsyncedOnly || (r['isSynced'] ?? 1) == 0)
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
  }

  @override
  Future<void> setSynced(LocalTable table, String id) async {
    final r = _rows[table]![id];
    if (r == null) return;
    r['isSynced'] = 1;
    await _persist();
  }

  @override
  Future<void> removeRow(LocalTable table, String id) async {
    _rows[table]!.remove(id);
    await _persist();
  }

  @override
  Future<void> removeUserRecords(String userId) async {
    recordLocalWrite();
    _rows[LocalTable.scouting]!.removeWhere(
      (_, row) => row['scouterId'] == userId,
    );
    _rows[LocalTable.superScouting]!.removeWhere(
      (_, row) => row['scouterId'] == userId,
    );
    _deletions.removeWhere((_, row) => row['requesterId'] == userId);
    await _persist();
  }

  @override
  Future<bool> replaceSyncedRows(
    LocalTable table,
    List<Map<String, dynamic>> serverRows,
    int expectedVersion,
  ) async {
    if (writeVersion != expectedVersion) return false;
    final rows = _rows[table]!;

    final unsyncedKeys = rows.values
        .where((r) => (r['isSynced'] ?? 1) == 0)
        .map((r) => r['uniqueKey'].toString())
        .toSet();
    final remoteIds = serverRows.map((r) => r['ID'].toString()).toSet();

    rows.removeWhere(
      (id, r) => (r['isSynced'] ?? 1) == 1 && !remoteIds.contains(id),
    );

    for (final r in serverRows) {
      final id = r['ID'].toString();
      if (id.isEmpty || _deletions.containsKey(id)) continue;
      if (unsyncedKeys.contains(r['uniqueKey'].toString())) continue;
      _removeByUniqueKey(table, r['uniqueKey'].toString(), id);
      rows[id] = Map<String, dynamic>.from(r);
    }
    await _persist();
    return true;
  }

  @override
  Future<void> putDeletion({
    required String recordId,
    required String tableName,
    required String requesterId,
  }) async {
    _deletions[recordId] = {
      'recordId': recordId,
      'tableName': tableName,
      'requesterId': requesterId,
    };
    await _persist();
  }

  @override
  Future<List<Map<String, dynamic>>> getDeletions() async =>
      _deletions.values.map((d) => Map<String, dynamic>.from(d)).toList();

  @override
  Future<void> dropDeletion(String recordId) async {
    _deletions.remove(recordId);
    await _persist();
  }
}
