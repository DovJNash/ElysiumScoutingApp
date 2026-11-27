import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../services/tba_service.dart';

class TeamInfo {
  final int number;
  final String name;
  final String logoUrl;

  const TeamInfo({
    required this.number,
    required this.name,
    required this.logoUrl,
  });

  factory TeamInfo.fromJson(Map<String, dynamic> json) {
    final number = (json['number'] as num).toInt();
    final custom = json['logoUrl'] as String?;
    return TeamInfo(
      number: number,
      name: json['name'] as String? ?? 'Team $number',
      logoUrl: (custom != null && custom.isNotEmpty)
          ? custom
          : SupabaseConfig.avatarUrl(number),
    );
  }

  /// Team that is not in competitions.json (typed in manually).
  factory TeamInfo.unlisted(int number) => TeamInfo(
        number: number,
        name: 'Team $number',
        logoUrl: SupabaseConfig.avatarUrl(number),
      );

  factory TeamInfo.fromTba({
    required int number,
    required String name,
    required String logoUrl,
  }) =>
      TeamInfo(number: number, name: name, logoUrl: logoUrl);
}

class CompetitionInfo {
  final String id;
  final String name;
  final List<TeamInfo> teams;

  const CompetitionInfo({
    required this.id,
    required this.name,
    required this.teams,
  });

  factory CompetitionInfo.fromJson(Map<String, dynamic> json) {
    final rawTeams = json['teams'] as List<dynamic>? ?? [];
    return CompetitionInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      teams: rawTeams
          .map((t) => TeamInfo.fromJson(t as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CompetitionRepository {
  static List<CompetitionInfo>? _cached;

  /// When [_cached] was last downloaded from TBA. Every screen asks for the
  /// competitions when it opens; within this time they share one download
  /// instead of each sending a request per event to The Blue Alliance.
  static DateTime? _fetchedAt;
  static const Duration _freshFor = Duration(minutes: 3);

  /// Competitions a Leader created (a custom set of teams). They are stored
  /// in Supabase (`competitions` table) so every device sees them, and cached
  /// on the device so they also work offline.
  static final List<CompetitionInfo> _custom = [];
  static DateTime? _customFetchedAt;
  static const String _customPrefsKey = 'elysium_custom_competitions';

  static void addCompetition(CompetitionInfo competition) {
    _custom
      ..removeWhere((item) => item.id == competition.id)
      ..add(competition);
  }

  /// Saves a new competition in Supabase (only a Leader is allowed to). Throws
  /// when the server refuses or cannot be reached.
  static Future<void> createCompetition({
    required String requesterId,
    required CompetitionInfo competition,
  }) async {
    await Supabase.instance.client.rpc('create_competition', params: {
      'p_requester_id': requesterId,
      'p_id': competition.id,
      'p_name': competition.name,
      'p_team_numbers': competition.teams.map((t) => t.number).toList(),
    }).timeout(const Duration(seconds: 20));
    addCompetition(competition);
    await _saveCustomCache([
      for (final item in _custom)
        {
          'id': item.id,
          'name': item.name,
          'team_numbers': item.teams.map((t) => t.number).toList(),
        }
    ]);
  }

  static Future<void> _saveCustomCache(List<Map<String, dynamic>> rows) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_customPrefsKey, json.encode(rows));
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> _readCustomCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_customPrefsKey);
      if (raw == null || raw.isEmpty) return [];
      return (json.decode(raw) as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Refreshes [_custom] from Supabase (or from the device cache when offline).
  static Future<void> _refreshCustom() async {
    final fetchedAt = _customFetchedAt;
    if (fetchedAt != null && DateTime.now().difference(fetchedAt) < _freshFor) {
      return;
    }
    List<Map<String, dynamic>> rows;
    var fromServer = false;
    try {
      final result = await Supabase.instance.client
          .from('competitions')
          .select('id, name, team_numbers, created_by')
          .timeout(const Duration(seconds: 15));
      rows = List<Map<String, dynamic>>.from(result)
          // rows without created_by are not Leader-made competitions
          .where((row) => (row['created_by'] ?? '').toString().isNotEmpty)
          .toList();
      fromServer = true;
      await _saveCustomCache(rows
          .map((row) => {
                'id': row['id'],
                'name': row['name'],
                'team_numbers': row['team_numbers'],
              })
          .toList());
    } catch (_) {
      rows = await _readCustomCache();
    }
    if (rows.isEmpty && !fromServer) return; // keep what is in memory

    final known = <int, TbaTeam>{};
    try {
      for (final team in await TbaService.instance.cachedIsraeliTeams()) {
        known[team.number] = team;
      }
    } catch (_) {}

    final loaded = <CompetitionInfo>[];
    for (final row in rows) {
      final numbers = ((row['team_numbers'] as List?) ?? const [])
          .map((n) => (n as num).toInt())
          .toList();
      loaded.add(CompetitionInfo(
        id: row['id'].toString(),
        name: row['name'].toString(),
        teams: [
          for (final number in numbers)
            known[number] == null
                ? TeamInfo.unlisted(number)
                : TeamInfo.fromTba(
                    number: number,
                    name: known[number]!.name,
                    logoUrl: known[number]!.logoUrl,
                  ),
        ],
      ));
    }
    // Competitions created on this device a moment ago stay until the server
    // list contains them.
    final serverIds = loaded.map((c) => c.id).toSet();
    final localOnly = _custom.where((c) => !serverIds.contains(c.id)).toList();
    _custom
      ..clear()
      ..addAll(loaded)
      ..addAll(localOnly);
    _customFetchedAt = DateTime.now();
  }

  static Future<List<CompetitionInfo>> _fromTbaEvents(
      List<TbaEvent> events) async {
    final competitions = await Future.wait(events.map((event) async {
      List<TbaTeam> teams;
      try {
        teams = await TbaService.instance.teamsAtEvent(event.key);
      } catch (_) {
        teams = await TbaService.instance.cachedTeams(event.key);
      }
      return CompetitionInfo(
        id: event.key,
        name: event.label,
        teams: teams
            .map((team) => TeamInfo.fromTba(
                  number: team.number,
                  name: team.name,
                  logoUrl: team.logoUrl,
                ))
            .toList(),
      );
    }));
    _cached = competitions;
    _fetchedAt = DateTime.now();
    return competitions;
  }

  /// TBA events (or the bundled list) plus the competitions Leaders created.
  static Future<List<CompetitionInfo>> loadCompetitions(
      {int year = 2027}) async {
    final base = await _loadBase(year: year);
    try {
      await _refreshCustom();
    } catch (_) {}
    final ids = base.map((c) => c.id).toSet();
    return [...base, ..._custom.where((c) => !ids.contains(c.id))];
  }

  static Future<List<CompetitionInfo>> _loadBase({int year = 2027}) async {
    final fetchedAt = _fetchedAt;
    if (fetchedAt != null &&
        _cached != null &&
        _cached!.isNotEmpty &&
        DateTime.now().difference(fetchedAt) < _freshFor) {
      return _cached!;
    }
    List<TbaEvent> events = [];
    try {
      events = await TbaService.instance.israeliDistrictEvents(year: year);
    } catch (_) {
      events =
          await TbaService.instance.cachedIsraeliDistrictEvents(year: year);
    }

    if (events.isNotEmpty) return _fromTbaEvents(events);
    if (_cached != null && _cached!.isNotEmpty) return _cached!;
    final jsonString = await rootBundle.loadString('assets/competitions.json');
    final decoded = json.decode(jsonString) as Map<String, dynamic>;
    final list = decoded['competitions'] as List<dynamic>;
    _cached = list
        .map((c) => CompetitionInfo.fromJson(c as Map<String, dynamic>))
        .toList();
    return _cached!;
  }
}
