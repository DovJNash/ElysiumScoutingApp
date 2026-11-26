import 'dart:convert';
import 'package:flutter/services.dart';
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

  static void addCompetition(CompetitionInfo competition) {
    final current = _cached ?? <CompetitionInfo>[];
    final replaced = current
        .where((item) => item.id != competition.id)
        .toList()
      ..add(competition);
    _cached = replaced;
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

  static Future<List<CompetitionInfo>> loadCompetitions(
      {int year = 2027}) async {
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
