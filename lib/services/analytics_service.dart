import 'dart:math';
import '../models/scouting_entry.dart';
import '../models/super_scouting_entry.dart';
import '../models/team_model.dart';

class TeamStandingSummary {
  final int teamNum;
  final String teamName;
  final String logoUrl;
  final int matchesScouted;
  final int superReportsCount;
  final double avgAutoShoot;
  final double avgAutoIntake;
  final double avgTeleopShoot;
  final double avgTeleopIntake;
  final double avgAllianceTime;
  final double avgNeutralTime;
  final double avgOpponentTime;
  final double avgDoingDefence;
  final double avgStandDefence;
  final double avgDriverSkill;
  final double estimatedBps;
  final double estimatedMissPercent;
  final double compositeRating;
  final List<SuperScoutingEntry> superEntries;

  const TeamStandingSummary({
    required this.teamNum,
    required this.teamName,
    required this.logoUrl,
    required this.matchesScouted,
    required this.superReportsCount,
    required this.avgAutoShoot,
    required this.avgAutoIntake,
    required this.avgTeleopShoot,
    required this.avgTeleopIntake,
    required this.avgAllianceTime,
    required this.avgNeutralTime,
    required this.avgOpponentTime,
    required this.avgDoingDefence,
    required this.avgStandDefence,
    required this.avgDriverSkill,
    required this.estimatedBps,
    required this.estimatedMissPercent,
    required this.compositeRating,
    required this.superEntries,
  });
}

class ScoutPerformanceSummary {
  final String scouterId;
  final String scouterName;
  final int sessionCount;

  /// null = nobody else scouted the same team, so accuracy cannot be judged yet.
  final double? accuracyPercent;
  final double avgDurationSeconds;
  final double performanceScore;
  final int peerVerifiedMatches;

  const ScoutPerformanceSummary({
    required this.scouterId,
    required this.scouterName,
    required this.sessionCount,
    required this.accuracyPercent,
    required this.avgDurationSeconds,
    required this.performanceScore,
    required this.peerVerifiedMatches,
  });
}

class AnalyticsService {
  static List<TeamStandingSummary> computeTeamStandings({
    required CompetitionInfo competition,
    required List<ScoutingEntry> scoutingEntries,
    required List<SuperScoutingEntry> superEntries,
  }) {
    final compScouting =
        scoutingEntries.where((e) => e.competition == competition.id).toList();
    final compSuper =
        superEntries.where((e) => e.competition == competition.id).toList();

    final Map<int, TeamInfo> catalog = {
      for (final t in competition.teams) t.number: t
    };
    final allTeams = <int>{
      ...catalog.keys,
      ...compScouting.map((e) => e.teamNum),
      ...compSuper.map((e) => e.teamNum),
    };

    final summaries = <TeamStandingSummary>[];

    for (final teamNum in allTeams) {
      final info = catalog[teamNum] ?? TeamInfo.unlisted(teamNum);
      final rows = compScouting.where((e) => e.teamNum == teamNum).toList();
      final supers = compSuper.where((e) => e.teamNum == teamNum).toList();

      double avg(num Function(ScoutingEntry) f) => rows.isEmpty
          ? 0.0
          : rows.map(f).reduce((a, b) => a + b) / rows.length;

      final autoShoot = avg((e) => e.estimatedFuelValue(e.autoShoot));
      final autoIntake = avg((e) => e.estimatedFuelValue(e.autoIntake));
      final teleShoot = avg((e) => e.estimatedFuelValue(e.teleopShoot));
      final teleIntake = avg((e) => e.estimatedFuelValue(e.teleopIntake));
      final doingDef = avg((e) => e.doingDefence);
      final standDef = avg((e) => e.standDefence);
      final driver = avg((e) => e.driverSkill);

      double meanOf(List<double> v) =>
          v.isEmpty ? 0.0 : v.reduce((a, b) => a + b) / v.length;

      final estBps = meanOf(supers
          .map((s) => _firstNumber(s.bps))
          .whereType<double>()
          .toList());
      final estMiss = meanOf(supers
          .map((s) => _firstNumber(s.missPercent))
          .whereType<double>()
          .toList());

      // Teams with no scouted match yet get 0 (no invented ratings).
      final composite = rows.isEmpty
          ? 0.0
          : (autoShoot * 3.0) +
              (autoIntake * 1.2) +
              (teleShoot * 2.0) +
              (teleIntake * 0.8) +
              (driver * 2.5) +
              (doingDef * 1.2) +
              (standDef * 1.0) +
              (estBps * 2.0) -
              (estMiss * 0.15);

      summaries.add(TeamStandingSummary(
        teamNum: teamNum,
        teamName: info.name,
        logoUrl: info.logoUrl,
        matchesScouted: rows.length,
        superReportsCount: supers.length,
        avgAutoShoot: autoShoot,
        avgAutoIntake: autoIntake,
        avgTeleopShoot: teleShoot,
        avgTeleopIntake: teleIntake,
        avgAllianceTime: avg((e) => e.allianceCount),
        avgNeutralTime: avg((e) => e.neutralCount),
        avgOpponentTime: avg((e) => e.opponentCount),
        avgDoingDefence: doingDef,
        avgStandDefence: standDef,
        avgDriverSkill: driver,
        estimatedBps: estBps,
        estimatedMissPercent: estMiss,
        compositeRating: max(0.0, composite),
        superEntries: supers, // already newest-first
      ));
    }

    summaries.sort((a, b) => b.compositeRating.compareTo(a.compositeRating));
    return summaries;
  }

  /// Leader ranking = Accuracy 55% + Volume 25% + Speed 20%.
  ///
  /// Accuracy: each form is compared with the MEDIAN of the OTHER scouters who
  /// scouted the same (match, team). If nobody else scouted that match, the
  /// median of the other scouters' forms for that team in the event is used.
  /// A form with no outside reference is simply not judged (it can no longer
  /// score a free 100% by being compared with itself).
  static List<ScoutPerformanceSummary> computeScoutLeaderboard({
    required String competitionId,
    required List<ScoutingEntry> scoutingEntries,
    required List<SuperScoutingEntry> superEntries,
  }) {
    final compScouting =
        scoutingEntries.where((e) => e.competition == competitionId).toList();
    final compSuper =
        superEntries.where((e) => e.competition == competitionId).toList();

    final matchGroups = <String, List<ScoutingEntry>>{};
    final teamGroups = <int, List<ScoutingEntry>>{};
    for (final e in compScouting) {
      matchGroups.putIfAbsent('${e.matchNum}_${e.teamNum}', () => []).add(e);
      teamGroups.putIfAbsent(e.teamNum, () => []).add(e);
    }

    final names = <String, String>{};
    for (final e in compScouting) {
      names[e.scouterId] = e.scouterName;
    }
    for (final e in compSuper) {
      names[e.scouterId] = e.scouterName;
    }

    final results = <ScoutPerformanceSummary>[];

    for (final n in names.entries) {
      final sId = n.key;
      final mine = compScouting.where((e) => e.scouterId == sId).toList();
      final mySuper = compSuper.where((e) => e.scouterId == sId).toList();
      final sessions = mine.length + mySuper.length;
      if (sessions == 0) continue;

      final durations = [
        ...mine.map((e) => e.durationSeconds),
        ...mySuper.map((e) => e.durationSeconds),
      ];
      final avgDuration = durations.reduce((a, b) => a + b) / durations.length;

      double? accuracy;
      var peerVerified = 0;

      if (mine.isEmpty) {
        // Super-scouting only: completeness of the 12 qualitative fields.
        var total = 0.0;
        for (final s in mySuper) {
          final filled = [
            s.auto, s.bps, s.shootingLimits, s.missPercent, s.intakeSpeed,
            s.robotCap, s.robotLimits, s.driverSkills, s.penalties,
            s.bumpSpeed, s.driverTechnique, s.defenceStyle,
          ].where((f) => f.trim().isNotEmpty).length;
          total += filled / 12.0 * 100.0;
        }
        accuracy = total / mySuper.length;
      } else {
        var sum = 0.0;
        var judged = 0;
        for (final sub in mine) {
          final samematch = (matchGroups['${sub.matchNum}_${sub.teamNum}'] ?? [])
              .where((e) => e.scouterId != sId)
              .toList();
          List<ScoutingEntry> ref = samematch;
          if (samematch.isNotEmpty) {
            peerVerified++;
          } else {
            ref = (teamGroups[sub.teamNum] ?? [])
                .where((e) => e.scouterId != sId)
                .toList();
          }
          if (ref.isEmpty) continue;

          double err(int actual, Iterable<int> vals, double floor) =>
              _normalizedError(actual.toDouble(), _median(vals), floor);
          double fuelErr(
            int actual,
            int Function(ScoutingEntry) select,
            double floor,
          ) =>
              _normalizedError(
                sub.estimatedFuelValue(actual),
                _median(
                  ref.map((entry) => entry.estimatedFuelValue(select(entry))),
                ),
                floor,
              );

          final meanErr = (fuelErr(sub.autoShoot, (e) => e.autoShoot, 10) +
                  fuelErr(sub.autoIntake, (e) => e.autoIntake, 10) +
                  fuelErr(sub.teleopShoot, (e) => e.teleopShoot, 20) +
                  fuelErr(sub.teleopIntake, (e) => e.teleopIntake, 20) +
                  err(sub.driverSkill, ref.map((e) => e.driverSkill), 10) +
                  err(sub.doingDefence, ref.map((e) => e.doingDefence), 10)) /
              6.0;
          sum += (100.0 * (1.0 - meanErr)).clamp(0.0, 100.0);
          judged++;
        }
        accuracy = judged == 0 ? null : sum / judged;
      }

      // Speed = time from opening the form to Submit. Best around one match
      // (~2 min); very rushed or very slow forms score lower.
      final speedScore =
          (100.0 - ((avgDuration - 120.0).abs() * 0.25)).clamp(40.0, 100.0);
      final volumeScore = min(100.0, sessions * 12.5);
      final accForScore = accuracy ?? 60.0; // neutral until verifiable

      results.add(ScoutPerformanceSummary(
        scouterId: sId,
        scouterName: n.value,
        sessionCount: sessions,
        accuracyPercent: accuracy,
        avgDurationSeconds: avgDuration,
        performanceScore:
            accForScore * 0.55 + volumeScore * 0.25 + speedScore * 0.20,
        peerVerifiedMatches: peerVerified,
      ));
    }

    results.sort((a, b) => b.performanceScore.compareTo(a.performanceScore));
    return results;
  }

  static double _median(Iterable<num> values) {
    final sorted = values.map((value) => value.toDouble()).toList()..sort();
    if (sorted.isEmpty) return 0.0;
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid].toDouble();
    return (sorted[mid - 1] + sorted[mid]) / 2.0;
  }

  static double _normalizedError(double actual, double target, double floor) {
    final denom = max(target.abs(), floor);
    return ((actual - target).abs() / denom).clamp(0.0, 1.0);
  }

  static double? _firstNumber(String text) {
    final m = RegExp(r'(\d+(\.\d+)?)').firstMatch(text);
    return m == null ? null : double.tryParse(m.group(1)!);
  }
}
