class PitScoutingEntry {
  final String id;
  final String uniqueKey;
  final String competition;
  final String scouterId;
  final String scouterName;
  final int teamNum;
  final String autonomousTypes;
  final String strengths;
  final String difficulties;
  final String defense;
  final String otherNotes;
  final int durationSeconds;
  final String createdAt;
  final bool isSynced;

  const PitScoutingEntry({
    required this.id,
    required this.uniqueKey,
    required this.competition,
    required this.scouterId,
    required this.scouterName,
    required this.teamNum,
    required this.autonomousTypes,
    required this.strengths,
    required this.difficulties,
    required this.defense,
    required this.otherNotes,
    required this.durationSeconds,
    required this.createdAt,
    this.isSynced = true,
  });

  static String buildUniqueKey({
    required String competition,
    required int teamNum,
    required String scouterId,
  }) =>
      'PIT_${competition.trim()}_${teamNum}_${scouterId.trim()}';

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'uniqueKey': uniqueKey,
        'competition': competition,
        'scouterId': scouterId,
        'scouterName': scouterName,
        'teamNum': teamNum,
        'autonomous_types': autonomousTypes,
        'strengths': strengths,
        'difficulties': difficulties,
        'defense': defense,
        'other_notes': otherNotes,
        'durationSeconds': durationSeconds,
        'createdAt': createdAt,
        'isSynced': isSynced,
      };

  factory PitScoutingEntry.fromMap(Map<String, dynamic> m,
      {bool? overrideSynced}) {
    String s(String k) => (m[k] ?? '').toString();
    return PitScoutingEntry(
      id: s('id'),
      uniqueKey: s('uniqueKey'),
      competition: s('competition'),
      scouterId: s('scouterId'),
      scouterName: s('scouterName'),
      teamNum: (m['teamNum'] as num?)?.toInt() ?? 0,
      autonomousTypes: s('autonomous_types'),
      strengths: s('strengths'),
      difficulties: s('difficulties'),
      defense: s('defense'),
      otherNotes: s('other_notes'),
      durationSeconds: (m['durationSeconds'] as num?)?.toInt() ?? 60,
      createdAt: s('createdAt'),
      isSynced: overrideSynced ??
          (m['isSynced'] is bool ? m['isSynced'] as bool : true),
    );
  }

  Map<String, String> detailRows() => {
        'Competition': competition,
        'Team': '$teamNum',
        'Scouter': scouterName,
        'Autonomous types': autonomousTypes,
        'What they do well': strengths,
        'Difficulties': difficulties,
        'Defensive style': defense,
        'Other notes': otherNotes,
        'Form time': '${durationSeconds}s',
        'Synced': isSynced ? 'Yes' : 'Waiting for internet',
      };
}
