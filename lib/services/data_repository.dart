import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/scouting_entry.dart';
import '../models/super_scouting_entry.dart';
import 'local_db_service.dart';

/// Single source of truth for every screen.
///
/// Screens never talk to Supabase directly: this class keeps the local cache in
/// step with the server (realtime "something changed" signal + paged download)
/// and notifies listeners, so every dashboard also works offline with the
/// last data it received.
class DataRepository extends ChangeNotifier {
  static final DataRepository instance = DataRepository._internal();
  DataRepository._internal();

  static const Duration _timeout = Duration(seconds: 20);

  final LocalDbService _db = LocalDbService.instance;
  SupabaseClient get _client => Supabase.instance.client;

  List<ScoutingEntry> scouting = [];
  List<SuperScoutingEntry> superScouting = [];

  RealtimeChannel? _channel;
  Timer? _debounce;
  bool _pulling = false;
  bool _pullAgain = false;

  Future<void> start() async {
    await reload();
    subscribe();
    unawaited(pullRemote());
  }

  /// (Re)opens the realtime channel. Its payload is only used as a
  /// "something changed" signal; the data itself is downloaded in pages so the
  /// 1000-row API limit can never truncate it.
  void subscribe() {
    _unsubscribe();
    try {
      _channel = _client
          .channel('elysium-live-data')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'Scouting',
            callback: (_) => _schedulePull(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'SuperScouting',
            callback: (_) => _schedulePull(),
          )
          .subscribe();
    } catch (_) {
      // Offline at start-up: the periodic sync downloads the data later.
    }
  }

  void _unsubscribe() {
    final c = _channel;
    _channel = null;
    if (c != null) {
      try {
        unawaited(_client.removeChannel(c).catchError((_) => 'error'));
      } catch (_) {}
    }
  }

  void _schedulePull() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () => pullRemote());
  }

  Future<List<Map<String, dynamic>>> _selectAll(String table) async {
    const page = 1000;
    final all = <Map<String, dynamic>>[];
    var from = 0;
    while (true) {
      final rows = await _client
          .from(table)
          .select()
          .order('ID', ascending: true)
          .range(from, from + page - 1)
          .timeout(_timeout);
      all.addAll(List<Map<String, dynamic>>.from(rows));
      if (rows.length < page) break;
      from += page;
    }
    return all;
  }

  /// Downloads the server state into the local cache.
  /// Returns null on success, otherwise the error (e.g. offline).
  Future<Object?> pullRemote() async {
    if (_pulling) {
      _pullAgain = true; // something changed while we were downloading
      return null;
    }
    _pulling = true;
    Object? error;
    try {
      do {
        _pullAgain = false;
        await _pullOnce();
      } while (_pullAgain);
    } catch (e) {
      error = e; // No connection - keep showing cached data.
    } finally {
      _pulling = false;
    }
    return error;
  }

  Future<void> _pullOnce() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final version = _db.writeVersion;
      final s = await _selectAll('Scouting');
      final ss = await _selectAll('SuperScouting');
      final a = await _db.replaceSyncedScouting(s, version);
      final b = await _db.replaceSyncedSuperScouting(ss, version);
      if (a && b) break; // otherwise a local write happened: download again
    }
    await reload();
  }

  Future<void> reload() async {
    final pending = (await _db.getPendingDeletions())
        .map((e) => e['recordId'] as String)
        .toSet();

    final s = (await _db.getAllScouting())
        .where((e) => !pending.contains(e.id))
        .toList()
      ..sort((a, b) => b.createdAtTime.compareTo(a.createdAtTime));
    final ss = (await _db.getAllSuperScouting())
        .where((e) => !pending.contains(e.id))
        .toList()
      ..sort((a, b) => b.createdAtTime.compareTo(a.createdAtTime));

    scouting = s;
    superScouting = ss;
    notifyListeners();
  }

  @override
  void dispose() {
    _unsubscribe();
    _debounce?.cancel();
    super.dispose();
  }
}
