import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/scouting_entry.dart';
import '../models/super_scouting_entry.dart';
import '../models/user_model.dart';
import 'data_repository.dart';
import 'local_db_service.dart';
import 'pit_scouting_service.dart';

/// Offline-first sync engine.
///  * Every form is saved locally first (always works).
///  * It is uploaded as soon as the internet is available (connectivity
///    listener + 15 s retry timer).
///  * Deletions are queued the same way and are re-checked by role on the
///    server.
class SyncService extends ChangeNotifier {
  static final SyncService instance = SyncService._internal();
  SyncService._internal();

  static const Duration _timeout = Duration(seconds: 20);

  final LocalDbService _localDb = LocalDbService.instance;
  final DataRepository _repo = DataRepository.instance;
  SupabaseClient get _supabase => Supabase.instance.client;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _periodicTimer;

  bool _isOnline = true;
  bool _isSyncing = false;
  bool _runAgain = false;
  Completer<void>? _running;
  int _pendingCount = 0;
  String? _lastError;

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  int get pendingCount => _pendingCount;

  /// Human readable reason of the last failed sync (null = all good).
  String? get lastError => _lastError;

  Future<void> initialize() async {
    try {
      final results = await Connectivity().checkConnectivity();
      _isOnline = _online(results);
    } catch (_) {
      _isOnline = true; // let the real requests decide
    }
    await _refreshPendingCount();

    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((results) async {
      final nowOnline = _online(results);
      final restored = !_isOnline && nowOnline;
      _isOnline = nowOnline;
      notifyListeners();
      if (restored) _repo.subscribe();
      if (nowOnline) await syncAll();
    });

    // Safety net (also covers "connected to Wi-Fi but no internet").
    _periodicTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_isOnline) syncAll();
    });

    if (_isOnline) unawaited(syncAll());
  }

  bool _online(List<ConnectivityResult> r) =>
      r.isNotEmpty && !r.contains(ConnectivityResult.none);

  Future<void> _refreshPendingCount() async {
    final s1 = await _localDb.getUnsyncedScouting();
    final s2 = await _localDb.getUnsyncedSuperScouting();
    final d = await _localDb.getPendingDeletions();
    _pendingCount = s1.length + s2.length + d.length;
    notifyListeners();
  }

  /// Saves locally first (always works), then tries to upload.
  /// Returns true if the record is already on the server.
  Future<bool> submitScouting(ScoutingEntry entry) async {
    await _localDb.upsertScouting(entry.copyWith(isSynced: false));
    await _repo.reload();
    await _refreshPendingCount();
    if (_isOnline) await syncAll();
    final stillPending =
        (await _localDb.getUnsyncedScouting()).any((e) => e.id == entry.id);
    return !stillPending;
  }

  Future<bool> submitSuperScouting(SuperScoutingEntry entry) async {
    await _localDb.upsertSuperScouting(entry.copyWith(isSynced: false));
    await _repo.reload();
    await _refreshPendingCount();
    if (_isOnline) await syncAll();
    final stillPending = (await _localDb.getUnsyncedSuperScouting())
        .any((e) => e.id == entry.id);
    return !stillPending;
  }

  /// Scouter: own Scouting forms only. Leader: any form.
  Future<void> deleteScoutingRecord({
    required ScoutingEntry entry,
    required UserModel requester,
  }) async {
    final isLeader = requester.role == UserRole.leader;
    final isOwner = entry.scouterId == requester.id;
    if (!isLeader && !isOwner) {
      throw Exception('Access denied: you can only delete forms you submitted.');
    }
    await _localDb.deleteScoutingLocal(entry.id);
    await _localDb.queueDeletion(
      recordId: entry.id,
      tableName: 'Scouting',
      requesterId: requester.id,
    );
    await _repo.reload();
    await _refreshPendingCount();
    if (_isOnline) unawaited(syncAll());
  }

  /// Strategy: own Super Scouting forms only. Leader: any form.
  Future<void> deleteSuperScoutingRecord({
    required SuperScoutingEntry entry,
    required UserModel requester,
  }) async {
    final isLeader = requester.role == UserRole.leader;
    final isOwner = entry.scouterId == requester.id;
    if (!isLeader && !isOwner) {
      throw Exception('Access denied: you can only delete your own reports.');
    }
    await _localDb.deleteSuperScoutingLocal(entry.id);
    await _localDb.queueDeletion(
      recordId: entry.id,
      tableName: 'SuperScouting',
      requesterId: requester.id,
    );
    await _repo.reload();
    await _refreshPendingCount();
    if (_isOnline) unawaited(syncAll());
  }

  // --------------------------------------------------------------- helpers
  bool _isPermanentError(Object e) =>
      e is PostgrestException && e.code == '42501';

  String _describe(Object e) {
    if (e is PostgrestException) {
      final code = e.code ?? '';
      if (code == '42P01' || code == 'PGRST205') {
        return 'The tables do not exist in this Supabase project. '
            'Run supabase_setup.sql in the SQL Editor.';
      }
      if (code == 'PGRST202') {
        return 'A database function is missing. '
            'Run supabase_setup.sql in the SQL Editor.';
      }
      if (code == '42501') {
        return 'Permission denied by the database (${e.message}). '
            'Re-run supabase_setup.sql and check the role of this account.';
      }
      return e.message;
    }
    final t = e.toString();
    if (e is TimeoutException) return 'The server did not answer in time.';
    if (t.contains('SocketException') ||
        t.contains('ClientException') ||
        t.contains('Failed host lookup') ||
        t.contains('XMLHttpRequest')) {
      return 'No connection to the server.';
    }
    return t.replaceFirst('Exception: ', '');
  }

  /// Uploads pending deletions + unsynced forms, then pulls fresh server data.
  /// Calling it while a sync is already running waits for that run (and makes
  /// sure it goes round once more), so callers always see the final state.
  Future<void> syncAll() async {
    final running = _running;
    if (running != null) {
      _runAgain = true;
      return running.future;
    }
    final c = _running = Completer<void>();
    _isSyncing = true;
    notifyListeners();

    try {
      do {
        _runAgain = false;
        await _syncOnce();
      } while (_runAgain);
    } catch (e) {
      _lastError = _describe(e);
    } finally {
      _isSyncing = false;
      _running = null;
      try {
        await _refreshPendingCount();
      } catch (_) {}
      c.complete();
    }
  }

  Future<void> _syncOnce() async {
    String? error;

    // 1. Deletions (the role is enforced again by the database function).
    for (final del in await _localDb.getPendingDeletions()) {
      final recordId = del['recordId'] as String;
      final tableName = del['tableName'] as String;
      final requesterId = del['requesterId'] as String;
      try {
        final allowed = await _supabase.rpc(
          tableName == 'Scouting'
              ? 'delete_scouting_record'
              : 'delete_super_scouting_record',
          params: {'p_record_id': recordId, 'p_requester_id': requesterId},
        ).timeout(_timeout);
        await _localDb.removePendingDeletion(recordId);
        if (allowed == false) {
          // The database refused (not your form / not your team). The next
          // download puts the form back, so tell the user why.
          error ??= 'The server did not allow deleting a form '
              '(it belongs to another account or team).';
        }
      } catch (e) {
        // Permission problem -> drop it (the next pull restores the record).
        // Network problem -> keep it and retry later.
        if (_isPermanentError(e)) {
          await _localDb.removePendingDeletion(recordId);
        }
        error ??= _describe(e);
      }
    }

    // 2. Upload forms one by one so a single failure never blocks the rest.
    for (final item in await _localDb.getUnsyncedScouting()) {
      try {
        await _upload(
          table: 'Scouting',
          deleteFunction: 'delete_scouting_record',
          row: item.toSupabaseMap(),
          id: item.id,
          uniqueKey: item.uniqueKey,
          ownerId: item.scouterId,
        );
        await _localDb.markScoutingSynced(item.id);
      } catch (e) {
        error ??= _describe(e);
      }
    }
    for (final item in await _localDb.getUnsyncedSuperScouting()) {
      try {
        await _upload(
          table: 'SuperScouting',
          deleteFunction: 'delete_super_scouting_record',
          row: item.toSupabaseMap(),
          id: item.id,
          uniqueKey: item.uniqueKey,
          ownerId: item.scouterId,
        );
        await _localDb.markSuperScoutingSynced(item.id);
      } catch (e) {
        error ??= _describe(e);
      }
    }

    // 2b. Pit scouting forms that are still waiting for upload.
    final pitError = await PitScoutingService.instance.syncPending();
    if (pitError != null) error ??= _describe(pitError);

    // 3. Refresh the local cache from the server.
    final pullError = await _repo.pullRemote();
    if (pullError != null) error ??= _describe(pullError);

    _lastError = error;
  }

  /// Inserts one form. The table only allows INSERT (nobody can overwrite
  /// somebody else's row), so replacing your own earlier form for the same
  /// team/match is done as "delete my old row, insert the new one".
  Future<void> _upload({
    required String table,
    required String deleteFunction,
    required Map<String, dynamic> row,
    required String id,
    required String uniqueKey,
    required String ownerId,
  }) async {
    try {
      await _supabase.from(table).insert(row).timeout(_timeout);
      return;
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow; // 23505 = unique violation
    }

    final existing = await _supabase
        .from(table)
        .select('ID')
        .eq('uniqueKey', uniqueKey)
        .maybeSingle()
        .timeout(_timeout);

    if (existing != null) {
      final existingId = existing['ID'].toString();
      if (existingId == id) return; // an earlier attempt already arrived
      await _supabase.rpc(
        deleteFunction,
        params: {'p_record_id': existingId, 'p_requester_id': ownerId},
      ).timeout(_timeout);
    }
    await _supabase.from(table).insert(row).timeout(_timeout);
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _periodicTimer?.cancel();
    super.dispose();
  }
}
