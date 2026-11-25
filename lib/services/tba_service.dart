import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TbaTeam {
  final int number;
  final String name;
  final String country;
  final String logoUrl;

  const TbaTeam({
    required this.number,
    required this.name,
    this.country = '',
    this.logoUrl = '',
  });

  factory TbaTeam.fromJson(Map<String, dynamic> json) {
    final key = json['key']?.toString() ?? '';
    final number = int.tryParse(key.replaceFirst('frc', '')) ?? 0;
    return TbaTeam(
      number: number,
      name: json['nickname']?.toString() ?? 'Team $number',
      country: json['country']?.toString() ?? '',
      logoUrl: json['logoUrl']?.toString() ??
          'https://www.thebluealliance.com/avatar/2027/frc$number.png',
    );
  }

  Map<String, dynamic> toJson() => {
        'key': 'frc$number',
        'nickname': name,
        'country': country,
        'logoUrl': logoUrl,
      };
}

class TbaMatch {
  final String key;
  final String competitionKey;
  final String matchLevel;
  final int matchNumber;
  final int setNumber;
  final List<int> redTeams;
  final List<int> blueTeams;
  final DateTime? scheduledAt;
  final int? redScore;
  final int? blueScore;

  const TbaMatch({
    required this.key,
    required this.competitionKey,
    required this.matchLevel,
    required this.matchNumber,
    required this.setNumber,
    required this.redTeams,
    required this.blueTeams,
    required this.scheduledAt,
    required this.redScore,
    required this.blueScore,
  });

  factory TbaMatch.fromJson(Map<String, dynamic> json) {
    int matchNum(Map<String, dynamic> m) =>
        (m['match_number'] as num?)?.toInt() ?? 0;
    int setNum(Map<String, dynamic> m) =>
        (m['set_number'] as num?)?.toInt() ?? 1;
    List<int> alliance(Map<String, dynamic> alliances, String color) {
      final teamKeys =
          (alliances[color]?['team_keys'] as List<dynamic>? ?? const []);
      return teamKeys
          .map((key) =>
              int.tryParse(key.toString().replaceFirst('frc', '')) ?? 0)
          .where((number) => number > 0)
          .toList();
    }

    final alliances = json['alliances'] as Map<String, dynamic>? ?? {};
    final time = (json['time'] as num?)?.toInt();
    final predicted = (json['predicted_time'] as num?)?.toInt();
    final timestamp = time ?? predicted;
    final redScore = json['alliances'] is Map
        ? (json['alliances']['red']?['score'] as num?)?.toInt()
        : null;
    final blueScore = json['alliances'] is Map
        ? (json['alliances']['blue']?['score'] as num?)?.toInt()
        : null;

    return TbaMatch(
      key: json['key']?.toString() ?? '',
      competitionKey: json['event_key']?.toString() ?? '',
      matchLevel: json['comp_level']?.toString() ?? '',
      matchNumber: matchNum(json),
      setNumber: setNum(json),
      redTeams: alliance(alliances, 'red'),
      blueTeams: alliance(alliances, 'blue'),
      scheduledAt: timestamp == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(timestamp * 1000),
      redScore: redScore,
      blueScore: blueScore,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'event_key': competitionKey,
        'comp_level': matchLevel,
        'match_number': matchNumber,
        'set_number': setNumber,
        'alliances': {
          'red': {
            'team_keys': redTeams.map((n) => 'frc$n').toList(),
            'score': redScore,
          },
          'blue': {
            'team_keys': blueTeams.map((n) => 'frc$n').toList(),
            'score': blueScore,
          },
        },
      };
}

class TbaService {
  TbaService._();
  static final instance = TbaService._();

  static const _baseUrl = 'https://www.thebluealliance.com/api/v3';
  static const _apiKey =
      String.fromEnvironment('TBA_API_KEY', defaultValue: '');

  bool get isConfigured => _apiKey.isNotEmpty;

  Map<String, String> get _headers => {
        'X-TBA-App-Id': 'elysium1937.scouting.app',
        if (_apiKey.isNotEmpty) 'X-TBA-Auth-Key': _apiKey,
      };

  Future<List<TbaTeam>> teamsAtEvent(String eventKey) async {
    final result = await _get('/event/$eventKey/teams/simple');
    final teams =
        (result as List).map((e) => TbaTeam.fromJson(e as Map<String, dynamic>));
    final list = teams.where((team) => team.number > 0).toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    await _cache('teams_$eventKey', list
        .map((team) => {'key': 'frc${team.number}', 'nickname': team.name})
        .toList());
    return list;
  }

  Future<List<TbaTeam>> israeliTeams({int year = 2027}) async {
    final cached = await cachedIsraeliTeams(year: year);
    if (!isConfigured) {
      if (cached.isNotEmpty) return cached;
      throw Exception('TBA_API_KEY is not configured');
    }

    final teams = <TbaTeam>[];
    for (var page = 0; page < 20; page++) {
      final result = await _get('/teams/$year/$page');
      final pageTeams = (result as List)
          .map((row) => TbaTeam.fromJson(row as Map<String, dynamic>))
          .toList();
      teams.addAll(pageTeams.where(
        (team) => team.number > 0 && team.country.toLowerCase() == 'israel',
      ));
      if (pageTeams.length < 500) break;
    }
    teams.sort((a, b) => a.number.compareTo(b.number));
    if (teams.isEmpty && cached.isNotEmpty) return cached;
    await _cache('israeli_teams_$year',
        teams.map((team) => team.toJson()).toList());
    return teams;
  }

  Future<List<TbaTeam>> cachedIsraeliTeams({int year = 2027}) async =>
      (await _readCache('israeli_teams_$year'))
          .map(TbaTeam.fromJson)
          .toList();

  Future<List<TbaMatch>> matchesAtEvent(String eventKey) async {
    final result = await _get('/event/$eventKey/matches/simple');
    final matches = (result as List)
        .map((e) => TbaMatch.fromJson(e as Map<String, dynamic>))
        .toList();
    matches.sort((a, b) => a.matchNumber.compareTo(b.matchNumber));
    await _cache('matches_$eventKey',
        matches.map((match) => match.toJson()).toList());
    return matches;
  }

  Future<List<TbaTeam>> cachedTeams(String eventKey) async =>
      (await _readCache('teams_$eventKey'))
          .map((e) => TbaTeam.fromJson(e))
          .toList();

  Future<List<TbaMatch>> cachedMatches(String eventKey) async =>
      (await _readCache('matches_$eventKey'))
          .map((e) => TbaMatch.fromJson(e))
          .toList();

  Future<dynamic> _get(String path) async {
    if (!isConfigured) throw Exception('TBA_API_KEY is not configured');
    final response = await http
        .get(Uri.parse('$_baseUrl$path'), headers: _headers)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('TBA request failed (${response.statusCode})');
    }
    return json.decode(response.body);
  }

  Future<void> _cache(String key, List<Map<String, dynamic>> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tba_$key', json.encode(value));
  }

  Future<List<Map<String, dynamic>>> _readCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('tba_$key');
    if (raw == null || raw.isEmpty) return [];
    return List<Map<String, dynamic>>.from(json.decode(raw) as List);
  }
}
