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

  const UserModel({required this.id, required this.name, required this.role});

  /// Row returned by the app_login / app_signup RPCs.
  factory UserModel.fromRpc(Map<String, dynamic> m) => UserModel(
        id: m['user_id'].toString(),
        name: m['user_name'].toString(),
        role: UserRole.normalize(m['user_role'].toString()),
      );

  factory UserModel.fromMap(Map<String, dynamic> m) => UserModel(
        id: m['id']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
        role: UserRole.normalize(m['role']?.toString() ?? UserRole.scouter),
      );

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'role': role};
}
