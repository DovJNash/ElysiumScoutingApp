class SuperScoutingEntry {
  final String id;
  final String uniqueKey;
  final String competition;
  final String scouterId;
  final String scouterName;
  final int teamNum;
  final String auto;
  final String bps;
  final String shootingLimits;
  final String missPercent;
  final String intakeSpeed;
  final String robotCap;
  final String robotLimits;
  final String driverSkills;
  final String penalties;
  final String bumpSpeed;
  final String driverTechnique;
  final String defenceStyle;
  final int durationSeconds;
  final String createdAt;
  final bool isSynced;

  const SuperScoutingEntry({
    required this.id,
    required this.uniqueKey,
    required this.competition,
    required this.scouterId,
    required this.scouterName,
    required this.teamNum,
    required this.auto,
    required this.bps,
    required this.shootingLimits,
    required this.missPercent,
    required this.intakeSpeed,
    required this.robotCap,
    required this.robotLimits,
    required this.driverSkills,
    required this.penalties,
    required this.bumpSpeed,
    required this.driverTechnique,
    required this.defenceStyle,
    required this.durationSeconds,
    required this.createdAt,
    this.isSynced = true,
  });

  static String buildUniqueKey({
    required String competition,
    required int teamNum,
    required String scouterId,
  }) =>
      'SUPER_${competition.trim()}_${teamNum}_${scouterId.trim()}';

  DateTime get createdAtTime =>
      DateTime.tryParse(createdAt)?.toUtc() ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  SuperScoutingEntry copyWith({bool? isSynced}) => SuperScoutingEntry(
        id: id,
        uniqueKey: uniqueKey,
        competition: competition,
        scouterId: scouterId,
        scouterName: scouterName,
        teamNum: teamNum,
        auto: auto,
        bps: bps,
        shootingLimits: shootingLimits,
        missPercent: missPercent,
        intakeSpeed: intakeSpeed,
        robotCap: robotCap,
        robotLimits: robotLimits,
        driverSkills: driverSkills,
        penalties: penalties,
        bumpSpeed: bumpSpeed,
        driverTechnique: driverTechnique,
        defenceStyle: defenceStyle,
        durationSeconds: durationSeconds,
        createdAt: createdAt,
        isSynced: isSynced ?? this.isSynced,
      );

  /// Exactly the columns of the Supabase "SuperScouting" table.
  Map<String, dynamic> toSupabaseMap() => {
        'ID': id,
        'uniqueKey': uniqueKey,
        'competition': competition,
        'scouterId': scouterId,
        'scouterName': scouterName,
        'teamNum': teamNum,
        'auto': auto,
        'bps': bps,
        'shootingLimits': shootingLimits,
        'missPercent': missPercent,
        'intakeSpeed': intakeSpeed,
        'RobotCap': robotCap,
        'robotLimits': robotLimits,
        'driverSkills': driverSkills,
        'penalties': penalties,
        'bumpSpeed': bumpSpeed,
        'DriverTechnique': driverTechnique,
        'defenceStyle': defenceStyle,
        'durationSeconds': durationSeconds,
        'createdAt': createdAt,
      };

  Map<String, dynamic> toSqliteMap() =>
      {...toSupabaseMap(), 'isSynced': isSynced ? 1 : 0};

  factory SuperScoutingEntry.fromMap(Map<String, dynamic> m,
      {bool? overrideSynced}) {
    String s(String k) => (m[k] ?? '').toString();
    return SuperScoutingEntry(
      id: (m['ID'] ?? m['id'] ?? '').toString(),
      uniqueKey: s('uniqueKey'),
      competition: s('competition'),
      scouterId: s('scouterId'),
      scouterName: (m['scouterName'] ?? 'Unknown').toString(),
      teamNum: (m['teamNum'] as num?)?.toInt() ?? 0,
      auto: s('auto'),
      bps: s('bps'),
      shootingLimits: s('shootingLimits'),
      missPercent: s('missPercent'),
      intakeSpeed: s('intakeSpeed'),
      robotCap: s('RobotCap'),
      robotLimits: s('robotLimits'),
      driverSkills: s('driverSkills'),
      penalties: s('penalties'),
      bumpSpeed: s('bumpSpeed'),
      driverTechnique: s('DriverTechnique'),
      defenceStyle: s('defenceStyle'),
      durationSeconds: (m['durationSeconds'] as num?)?.toInt() ?? 60,
      createdAt:
          (m['createdAt'] ?? DateTime.now().toUtc().toIso8601String()).toString(),
      isSynced: overrideSynced ?? ((m['isSynced'] ?? 1) == 1),
    );
  }

  Map<String, String> detailRows() {
    String v(String x) => x.trim().isEmpty ? '-' : x;
    return {
      'Competition': competition,
      'Team': '$teamNum',
      'Scouter': scouterName,
      'Autonomous': v(auto),
      'Shooting rate (BPS)': v(bps),
      'Shooting mechanics': v(shootingLimits),
      'Missed shots': v(missPercent),
      'Intake': v(intakeSpeed),
      'Capacity': v(robotCap),
      'Limitations': v(robotLimits),
      'Driver skills': v(driverSkills),
      'Penalties': v(penalties),
      'Bump speed': v(bumpSpeed),
      'Driving technique': v(driverTechnique),
      'Defensive style': v(defenceStyle),
      'Form time': '${durationSeconds}s',
      'Synced': isSynced ? 'Yes' : 'Waiting for internet',
    };
  }
}
