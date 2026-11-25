class ScoutingEntry {
  final String id;
  final String uniqueKey;
  final String competition;
  final String scouterId;
  final String scouterName;
  final int teamNum;
  final int matchNum;
  final String startPos;
  final String exitPos;
  final int autoShoot;
  final int autoIntake;
  final int allianceCount;
  final int neutralCount;
  final int opponentCount;
  final int teleopShoot;
  final int teleopIntake;
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
    required this.startPos,
    required this.exitPos,
    required this.autoShoot,
    required this.autoIntake,
    required this.allianceCount,
    required this.neutralCount,
    required this.opponentCount,
    required this.teleopShoot,
    required this.teleopIntake,
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
    required String scouterId,
  }) =>
      '${competition.trim()}_${teamNum}_${matchNum}_${scouterId.trim()}';

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
        startPos: startPos,
        exitPos: exitPos,
        autoShoot: autoShoot,
        autoIntake: autoIntake,
        allianceCount: allianceCount,
        neutralCount: neutralCount,
        opponentCount: opponentCount,
        teleopShoot: teleopShoot,
        teleopIntake: teleopIntake,
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
        'startPos': startPos,
        'exitPos': exitPos,
        'autoShoot': autoShoot,
        'autoIntake': autoIntake,
        'allianceCount': allianceCount,
        'neutralCount': neutralCount,
        'opponentCount': opponentCount,
        'teleopShoot': teleopShoot,
        'teleopIntake': teleopIntake,
        'doingDefence': doingDefence,
        'standDefence': standDefence,
        'driverSkill': driverSkill,
        'notes': notes,
        'durationSeconds': durationSeconds,
        'createdAt': createdAt,
      };

  Map<String, dynamic> toSqliteMap() =>
      {...toSupabaseMap(), 'isSynced': isSynced ? 1 : 0};

  factory ScoutingEntry.fromMap(Map<String, dynamic> m,
      {bool? overrideSynced}) {
    int i(String k, int d) => (m[k] as num?)?.toInt() ?? d;
    return ScoutingEntry(
      id: (m['ID'] ?? m['id'] ?? '').toString(),
      uniqueKey: (m['uniqueKey'] ?? '').toString(),
      competition: (m['competition'] ?? '').toString(),
      scouterId: (m['scouterId'] ?? '').toString(),
      scouterName: (m['scouterName'] ?? 'Unknown').toString(),
      teamNum: i('teamNum', 0),
      matchNum: i('matchNum', 0),
      startPos: (m['startPos'] ?? '').toString(),
      exitPos: (m['exitPos'] ?? '').toString(),
      autoShoot: i('autoShoot', 0),
      autoIntake: i('autoIntake', 0),
      allianceCount: i('allianceCount', 0),
      neutralCount: i('neutralCount', 0),
      opponentCount: i('opponentCount', 0),
      teleopShoot: i('teleopShoot', 0),
      teleopIntake: i('teleopIntake', 0),
      doingDefence: i('doingDefence', 1),
      standDefence: i('standDefence', 1),
      driverSkill: i('driverSkill', 1),
      notes: (m['notes'] ?? '').toString(),
      durationSeconds: i('durationSeconds', 60),
      createdAt:
          (m['createdAt'] ?? DateTime.now().toUtc().toIso8601String()).toString(),
      isSynced: overrideSynced ?? ((m['isSynced'] ?? 1) == 1),
    );
  }

  Map<String, String> detailRows() => {
        'Competition': competition,
        'Match': '$matchNum',
        'Team': '$teamNum',
        'Scouter': scouterName,
        'Start position': startPos,
        'Exit path': exitPos,
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
