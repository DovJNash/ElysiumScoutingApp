class UserRole {
  static const String scouter = 'Scouter';
  static const String strategy = 'Strategy';
  static const String leader = 'Leader';

  static String normalize(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower == 'strategy') return strategy;
    if (lower == 'leader' || lower == 'lead') return leader;
    return scouter;
  }
}

class UserModel {
  final String id;
  final String name;
  final String role;
  final int teamNumber;
  final String teamName;

  const UserModel({
    required this.id,
    required this.name,
    required this.role,
    this.teamNumber = 0,
    this.teamName = '',
  });

  /// Row returned by the app_login / app_signup RPCs.
  factory UserModel.fromRpc(Map<String, dynamic> m) => UserModel(
        id: m['user_id'].toString(),
        name: m['user_name'].toString(),
        role: UserRole.normalize(m['user_role'].toString()),
        teamNumber: (m['team_number'] as num?)?.toInt() ?? 0,
        teamName: m['team_name']?.toString() ?? '',
      );

  factory UserModel.fromMap(Map<String, dynamic> m) => UserModel(
        id: m['id']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
        role: UserRole.normalize(m['role']?.toString() ?? UserRole.scouter),
        teamNumber: (m['teamNumber'] as num?)?.toInt() ?? 0,
        teamName: m['teamName']?.toString() ?? '',
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'role': role,
        'teamNumber': teamNumber,
        'teamName': teamName,
      };
}
