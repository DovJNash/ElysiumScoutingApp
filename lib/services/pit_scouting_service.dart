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
        final rows =
            (json.decode(raw) as List).cast<Map<String, dynamic>>();
        entries.addAll(rows
            .map((row) => PitScoutingEntry.fromMap(row))
            .toList());
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> submit(PitScoutingEntry entry) async {
    await _save(entry.copyWith(isSynced: false));
    try {
      await _client
          .from('pit_scouting')
          .upsert(entry.toSupabaseMap())
          .timeout(const Duration(seconds: 20));
      await _save(entry.copyWith(isSynced: true));
      await pull();
    } catch (_) {}
  }

  Future<void> pull() async {
    try {
      final rows = await _client
          .from('pit_scouting')
          .select()
          .timeout(const Duration(seconds: 20));
      final remote = List<Map<String, dynamic>>.from(rows)
          .map((row) => PitScoutingEntry.fromMap(row,
              overrideSynced: true))
          .toList();
      final unsynced = entries.where((entry) => !entry.isSynced).toList();
      final all = <String, PitScoutingEntry>{
        for (final entry in remote) entry.id: entry,
        for (final entry in unsynced) entry.id: entry,
      };
      await _writeCache(all.values.toList());
    } catch (_) {}
  }

  Future<void> _save(PitScoutingEntry entry) async {
    final index = entries.indexWhere((e) => e.id == entry.id);
    if (index >= 0) {
      entries[index] = entry;
    } else {
      entries.add(entry);
    }
    await _writeCache(entries);
  }

  Future<void> _writeCache(List<PitScoutingEntry> value) async {
    entries
      ..clear()
      ..addAll(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey,
      json.encode(value.map((entry) => {
            ...entry.toSupabaseMap(),
            'isSynced': entry.isSynced,
          }).toList()),
    );
    notifyListeners();
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
