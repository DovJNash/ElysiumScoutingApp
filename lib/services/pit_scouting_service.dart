import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pit_scouting_entry.dart';

class PitScoutingService extends ChangeNotifier {
  PitScoutingService._();
  static final instance = PitScoutingService._();

  static const _cacheKey = 'elysium_pit_scouting_cache';
  final List<PitScoutingEntry> entries = [];

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> initialize() async {
    await reloadLocal();
  }

  Future<void> reloadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    entries.clear();
    if (raw != null && raw.isNotEmpty) {
      try {
        final rows = (json.decode(raw) as List).cast<Map<String, dynamic>>();
        entries.addAll(
          rows.map((row) => PitScoutingEntry.fromMap(row)).toList(),
        );
      } catch (_) {}
    }
    notifyListeners();
  }

  /// Saves locally first (so nothing is lost offline), then uploads.
  Future<void> submit(PitScoutingEntry entry) async {
    await _save(entry.copyWith(isSynced: false));
    await syncPending();
  }

  /// Uploads every pit form that is still waiting and refreshes the cache.
  /// Called after each submit and by SyncService whenever it syncs.
  /// Returns null on success, otherwise the error (e.g. offline).
  Future<Object?> syncPending() async {
    Object? error;
    var uploaded = 0;
    for (final entry in entries.where((e) => !e.isSynced).toList()) {
      try {
        // uniqueKey is unique per scouter + team + competition, so a second
        // form for the same team REPLACES the first one instead of failing.
        await _client
            .from('pit_scouting')
            .upsert(
              entry.copyWith(isSynced: true).toSupabaseMap(),
              onConflict: 'uniqueKey',
            )
            .timeout(const Duration(seconds: 20));
        uploaded++;
        // Only mark it synced if the user did not replace it meanwhile.
        if (entries.any((e) => e.id == entry.id)) {
          await _save(entry.copyWith(isSynced: true));
        }
      } catch (e) {
        error ??= e;
      }
    }
    if (uploaded == 0) return error;
    return error ?? await pull();
  }

  Future<Object?> pull() async {
    try {
      final rows = await _client
          .from('pit_scouting')
          .select()
          .timeout(const Duration(seconds: 20));
      final remote = List<Map<String, dynamic>>.from(rows)
          .map((row) => PitScoutingEntry.fromMap(row, overrideSynced: true))
          .toList();
      final unsynced = entries.where((entry) => !entry.isSynced).toList();
      final unsyncedKeys = unsynced.map((e) => e.uniqueKey).toSet();
      final all = <String, PitScoutingEntry>{
        for (final entry in remote)
          if (!unsyncedKeys.contains(entry.uniqueKey)) entry.id: entry,
        for (final entry in unsynced) entry.id: entry,
      };
      await _writeCache(all.values.toList());
      return null;
    } catch (e) {
      return e;
    }
  }

  Future<void> _save(PitScoutingEntry entry) async {
    // Same id, or same uniqueKey (= a newer form for the same team) replaces
    // the old row.
    final next = [
      for (final e in entries)
        if (e.id != entry.id && e.uniqueKey != entry.uniqueKey) e,
      entry,
    ];
    await _writeCache(next);
  }

  Future<void> _writeCache(List<PitScoutingEntry> value) async {
    // Copy first: callers may pass [entries] itself, and clear() would empty
    // it before addAll() ran (this used to wipe every pit form on save).
    final copy = List<PitScoutingEntry>.of(value);
    entries
      ..clear()
      ..addAll(copy);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey,
      json.encode(
        copy
            .map(
              (entry) => {...entry.toSupabaseMap(), 'isSynced': entry.isSynced},
            )
            .toList(),
      ),
    );
    notifyListeners();
  }

  Future<void> removeUserData(String userId) async {
    await _writeCache(
      entries.where((entry) => entry.scouterId != userId).toList(),
    );
  }
}

extension _PitCopy on PitScoutingEntry {
  PitScoutingEntry copyWith({bool? isSynced}) => PitScoutingEntry(
        id: id,
        uniqueKey: uniqueKey,
        competition: competition,
        scouterId: scouterId,
        scouterName: scouterName,
        teamNum: teamNum,
        autonomousTypes: autonomousTypes,
        strengths: strengths,
        difficulties: difficulties,
        defense: defense,
        otherNotes: otherNotes,
        durationSeconds: durationSeconds,
        createdAt: createdAt,
        isSynced: isSynced ?? this.isSynced,
      );
}
