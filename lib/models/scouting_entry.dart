class ScoutingEntry {
  final String id;
  final String uniqueKey;
  final String competition;
  final String scouterId;
  final String scouterName;
  final int teamNum;
  final int matchNum;
  final String matchLevel;
  final int matchSet;
  final String startPos;
  final String exitPos;
  final int autoShoot;
  final int autoIntake;
  final int allianceCount;
  final int neutralCount;
  final int opponentCount;
  final int teleopShoot;
  final int teleopIntake;
  final bool robotShowed;
  final int autoCycles;
  final int autoFuelsDelivered;
  final int autoIntakeSpeed;
  final int autoPerformance;
  final bool teleopCanShootMoving;
  final int teleopCycles;
  final int teleopFuelsDelivered;
  final int teleopIntakeSpeed;
  final int teleopAccuracy;
  final int teleopPerformance;
  final bool playedDefense;
  final int defenseRating;
  final bool dealtWithDefense;
  final int defenseResilience;
  final bool climbed;
  final String climbLevel;
  final int climbTimeSeconds;
  final int doingDefence;
  final int standDefence;
  final int driverSkill;
  final String notes;
  final int durationSeconds;
  final String createdAt;
  final bool isSynced;

  const ScoutingEntry({
    required this.id,
    required this.uniqueKey,
    required this.competition,
    required this.scouterId,
    required this.scouterName,
    required this.teamNum,
    required this.matchNum,
    this.matchLevel = 'qm',
    this.matchSet = 1,
    required this.startPos,
    required this.exitPos,
    required this.autoShoot,
    required this.autoIntake,
    required this.allianceCount,
    required this.neutralCount,
    required this.opponentCount,
    required this.teleopShoot,
    required this.teleopIntake,
    this.robotShowed = true,
    this.autoCycles = 0,
    this.autoFuelsDelivered = 0,
    this.autoIntakeSpeed = 0,
    this.autoPerformance = 0,
    this.teleopCanShootMoving = false,
    this.teleopCycles = 0,
    this.teleopFuelsDelivered = 0,
    this.teleopIntakeSpeed = 0,
    this.teleopAccuracy = 0,
    this.teleopPerformance = 0,
    this.playedDefense = false,
    this.defenseRating = 0,
    this.dealtWithDefense = false,
    this.defenseResilience = 0,
    this.climbed = false,
    this.climbLevel = '',
    this.climbTimeSeconds = 0,
    required this.doingDefence,
    required this.standDefence,
    required this.driverSkill,
    required this.notes,
    required this.durationSeconds,
    required this.createdAt,
    this.isSynced = true,
  });

  static String buildUniqueKey({
    required String competition,
    required int teamNum,
    required int matchNum,
    String matchLevel = 'qm',
    int matchSet = 1,
    required String scouterId,
  }) =>
      matchLevel == 'qm' && matchSet == 1
          ? '${competition.trim()}_${teamNum}_${matchNum}_${scouterId.trim()}'
          : '${competition.trim()}_${teamNum}_${matchLevel}_'
              '${matchSet}_${matchNum}_${scouterId.trim()}';

  DateTime get createdAtTime =>
      DateTime.tryParse(createdAt)?.toUtc() ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  ScoutingEntry copyWith({bool? isSynced}) => ScoutingEntry(
        id: id,
        uniqueKey: uniqueKey,
        competition: competition,
        scouterId: scouterId,
        scouterName: scouterName,
        teamNum: teamNum,
        matchNum: matchNum,
        matchLevel: matchLevel,
        matchSet: matchSet,
        startPos: startPos,
        exitPos: exitPos,
        autoShoot: autoShoot,
        autoIntake: autoIntake,
        allianceCount: allianceCount,
        neutralCount: neutralCount,
        opponentCount: opponentCount,
        teleopShoot: teleopShoot,
        teleopIntake: teleopIntake,
        robotShowed: robotShowed,
        autoCycles: autoCycles,
        autoFuelsDelivered: autoFuelsDelivered,
        autoIntakeSpeed: autoIntakeSpeed,
        autoPerformance: autoPerformance,
        teleopCanShootMoving: teleopCanShootMoving,
        teleopCycles: teleopCycles,
        teleopFuelsDelivered: teleopFuelsDelivered,
        teleopIntakeSpeed: teleopIntakeSpeed,
        teleopAccuracy: teleopAccuracy,
        teleopPerformance: teleopPerformance,
        playedDefense: playedDefense,
        defenseRating: defenseRating,
        dealtWithDefense: dealtWithDefense,
        defenseResilience: defenseResilience,
        climbed: climbed,
        climbLevel: climbLevel,
        climbTimeSeconds: climbTimeSeconds,
        doingDefence: doingDefence,
        standDefence: standDefence,
        driverSkill: driverSkill,
        notes: notes,
        durationSeconds: durationSeconds,
        createdAt: createdAt,
        isSynced: isSynced ?? this.isSynced,
      );

  /// Exactly the columns of the Supabase "Scouting" table.
  Map<String, dynamic> toSupabaseMap() => {
        'ID': id,
        'uniqueKey': uniqueKey,
        'competition': competition,
        'scouterId': scouterId,
        'scouterName': scouterName,
        'teamNum': teamNum,
        'matchNum': matchNum,
        'matchLevel': matchLevel,
        'matchSet': matchSet,
        'startPos': startPos,
        'exitPos': exitPos,
        'autoShoot': autoShoot,
        'autoIntake': autoIntake,
        'allianceCount': allianceCount,
        'neutralCount': neutralCount,
        'opponentCount': opponentCount,
        'teleopShoot': teleopShoot,
        'teleopIntake': teleopIntake,
        'robotShowed': robotShowed,
        'autoCycles': autoCycles,
        'autoFuelsDelivered': autoFuelsDelivered,
        'autoIntakeSpeed': autoIntakeSpeed,
        'autoPerformance': autoPerformance,
        'teleopCanShootMoving': teleopCanShootMoving,
        'teleopCycles': teleopCycles,
        'teleopFuelsDelivered': teleopFuelsDelivered,
        'teleopIntakeSpeed': teleopIntakeSpeed,
        'teleopAccuracy': teleopAccuracy,
        'teleopPerformance': teleopPerformance,
        'playedDefense': playedDefense,
        'defenseRating': defenseRating,
        'dealtWithDefense': dealtWithDefense,
        'defenseResilience': defenseResilience,
        'climbed': climbed,
        'climbLevel': climbLevel,
        'climbTimeSeconds': climbTimeSeconds,
        'doingDefence': doingDefence,
        'standDefence': standDefence,
        'driverSkill': driverSkill,
        'notes': notes,
        'durationSeconds': durationSeconds,
        'createdAt': createdAt,
      };

  Map<String, dynamic> toSqliteMap() => {
        ...toSupabaseMap(),
        'robotShowed': robotShowed ? 1 : 0,
        'teleopCanShootMoving': teleopCanShootMoving ? 1 : 0,
        'playedDefense': playedDefense ? 1 : 0,
        'dealtWithDefense': dealtWithDefense ? 1 : 0,
        'climbed': climbed ? 1 : 0,
        'isSynced': isSynced ? 1 : 0,
      };

  factory ScoutingEntry.fromMap(
    Map<String, dynamic> m, {
    bool? overrideSynced,
  }) {
    int i(String k, int d) => (m[k] as num?)?.toInt() ?? d;
    bool b(String k, bool d) {
      final value = m[k];
      if (value is bool) return value;
      if (value is num) return value != 0;
      return d;
    }

    return ScoutingEntry(
      id: (m['ID'] ?? m['id'] ?? '').toString(),
      uniqueKey: (m['uniqueKey'] ?? '').toString(),
      competition: (m['competition'] ?? '').toString(),
      scouterId: (m['scouterId'] ?? '').toString(),
      scouterName: (m['scouterName'] ?? 'Unknown').toString(),
      teamNum: i('teamNum', 0),
      matchNum: i('matchNum', 0),
      matchLevel: (m['matchLevel'] ?? 'qm').toString(),
      matchSet: i('matchSet', 1),
      startPos: (m['startPos'] ?? '').toString(),
      exitPos: (m['exitPos'] ?? '').toString(),
      autoShoot: i('autoShoot', 0),
      autoIntake: i('autoIntake', 0),
      allianceCount: i('allianceCount', 0),
      neutralCount: i('neutralCount', 0),
      opponentCount: i('opponentCount', 0),
      teleopShoot: i('teleopShoot', 0),
      teleopIntake: i('teleopIntake', 0),
      robotShowed: b('robotShowed', true),
      autoCycles: i('autoCycles', 0),
      autoFuelsDelivered: i('autoFuelsDelivered', 0),
      autoIntakeSpeed: i('autoIntakeSpeed', 0),
      autoPerformance: i('autoPerformance', 0),
      teleopCanShootMoving: b('teleopCanShootMoving', false),
      teleopCycles: i('teleopCycles', 0),
      teleopFuelsDelivered: i('teleopFuelsDelivered', 0),
      teleopIntakeSpeed: i('teleopIntakeSpeed', 0),
      teleopAccuracy: i('teleopAccuracy', 0),
      teleopPerformance: i('teleopPerformance', 0),
      playedDefense: b('playedDefense', false),
      defenseRating: i('defenseRating', 0),
      dealtWithDefense: b('dealtWithDefense', false),
      defenseResilience: i('defenseResilience', 0),
      climbed: b('climbed', false),
      climbLevel: (m['climbLevel'] ?? '').toString(),
      climbTimeSeconds: i('climbTimeSeconds', 0),
      doingDefence: i('doingDefence', 1),
      standDefence: i('standDefence', 1),
      driverSkill: i('driverSkill', 1),
      notes: (m['notes'] ?? '').toString(),
      durationSeconds: i('durationSeconds', 60),
      createdAt: (m['createdAt'] ?? DateTime.now().toUtc().toIso8601String())
          .toString(),
      isSynced: overrideSynced ?? ((m['isSynced'] ?? 1) == 1),
    );
  }

  Map<String, String> detailRows() => {
        'Competition': competition,
        'Match': matchLevel == 'qm'
            ? 'Qualification $matchNum'
            : '${matchLevel.toUpperCase()} $matchSet-$matchNum',
        'Team': '$teamNum',
        'Scouter': scouterName,
        'Start position': startPos,
        'Exit path': exitPos,
        'Robot showed up': robotShowed ? 'Yes' : 'No',
        'Autonomous fuels shot': '$autoShoot',
        'Autonomous cycles': '$autoCycles',
        'Autonomous fuels delivered': '$autoFuelsDelivered',
        'Autonomous intake speed': '$autoIntakeSpeed/10',
        'Autonomous performance': '$autoPerformance/5',
        'Shoots while moving': teleopCanShootMoving ? 'Yes' : 'No',
        'Teleop fuels shot': '$teleopShoot',
        'Teleop cycles': '$teleopCycles',
        'Teleop fuels delivered': '$teleopFuelsDelivered',
        'Teleop intake speed': '$teleopIntakeSpeed/10',
        'Teleop accuracy': '$teleopAccuracy/5',
        'Teleop performance': '$teleopPerformance/10',
        'Played defense': playedDefense ? 'Yes' : 'No',
        'Defense rating': '$defenseRating/5',
        'Dealt with defense': dealtWithDefense ? 'Yes' : 'No',
        'Defense resilience': '$defenseResilience/5',
        'Climbed': climbed ? 'Yes' : 'No',
        'Climb level': climbLevel.isEmpty ? '-' : climbLevel,
        'Climb time': '${climbTimeSeconds}s',
        'Auto scored': '$autoShoot',
        'Fuels passed to alliance zone (auto)': '$autoIntake',
        'Teleop scored': '$teleopShoot',
        'Fuels passed to alliance zone (teleop)': '$teleopIntake',
        'Alliance zone (s)': '$allianceCount',
        'Neutral zone (s)': '$neutralCount',
        'Opponent zone (s)': '$opponentCount',
        'Defense played': '$doingDefence/10',
        'Resilience vs defense': '$standDefence/10',
        'Driver skill': '$driverSkill/10',
        'Notes': notes.isEmpty ? '-' : notes,
        'Form time': '${durationSeconds}s',
        'Synced': isSynced ? 'Yes' : 'Waiting for internet',
      };
}
