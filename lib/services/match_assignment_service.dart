import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';
import 'auth_service.dart';

class MatchAssignment {
  final String competitionId;
  final String matchLevel;
  final int setNumber;
  final int matchNumber;

  const MatchAssignment({
    required this.competitionId,
    required this.matchLevel,
    required this.setNumber,
    required this.matchNumber,
  });

  factory MatchAssignment.fromMap(Map<String, dynamic> row) => MatchAssignment(
        competitionId: row['competition_id'].toString(),
        matchLevel: row['match_level'].toString(),
        setNumber: (row['set_number'] as num).toInt(),
        matchNumber: (row['match_number'] as num).toInt(),
      );

  Map<String, dynamic> toMap() => {
        'competition_id': competitionId,
        'match_level': matchLevel,
        'set_number': setNumber,
        'match_number': matchNumber,
      };

  bool matches({
    required String competitionId,
    required String matchLevel,
    required int setNumber,
    required int matchNumber,
  }) =>
      this.competitionId == competitionId &&
      this.matchLevel == matchLevel &&
      this.setNumber == setNumber &&
      this.matchNumber == matchNumber;
}

class TeamMember {
  final String id;
  final String name;
  final String role;

  const TeamMember({required this.id, required this.name, required this.role});

  factory TeamMember.fromMap(Map<String, dynamic> row) => TeamMember(
        id: row['user_id'].toString(),
        name: row['user_name'].toString(),
        role: row['user_role'].toString(),
      );
}

class MatchAssignmentService {
  MatchAssignmentService._();
  static final instance = MatchAssignmentService._();

  SupabaseClient get _client => Supabase.instance.client;

  String _cacheKey(String userId) => 'elysium_match_assignments_$userId';

  Future<List<MatchAssignment>> loadMine({bool refresh = false}) async {
    final user = AuthService.instance.currentUser;
    if (user == null) return [];
    if (refresh) {
      try {
        final password = await AuthService.instance.currentPassword();
        if (password == null) throw StateError('Account password unavailable.');
        final result = await _client.rpc(
          'my_match_assignments',
          params: {'p_user_id': user.id, 'p_password': password},
        ).timeout(const Duration(seconds: 20));
        final assignments = List<Map<String, dynamic>>.from(result as List)
            .map(MatchAssignment.fromMap)
            .toList();
        await _save(user.id, assignments);
        return assignments;
      } on PostgrestException {
        rethrow;
      } catch (_) {
        // Read the last server-confirmed list below when the connection is down.
      }
    }
    final cached = await _read(user.id);
    if (!refresh && cached.isNotEmpty) return cached;
    if (refresh) return cached;
    return loadMine(refresh: true);
  }

  Future<List<TeamMember>> loadTeamMembers() async {
    final user = AuthService.instance.currentUser;
    final password = await AuthService.instance.currentPassword();
    if (user == null || user.role != UserRole.leader || password == null) {
      throw StateError('A verified Leader account is required.');
    }
    final result = await _client.rpc(
      'leader_team_members',
      params: {'p_requester_id': user.id, 'p_password': password},
    ).timeout(const Duration(seconds: 20));
    return List<Map<String, dynamic>>.from(result as List)
        .map(TeamMember.fromMap)
        .where((member) => member.role != UserRole.leader)
        .toList();
  }

  Future<List<MatchAssignment>> loadForMember(TeamMember member) async {
    final user = AuthService.instance.currentUser;
    final password = await AuthService.instance.currentPassword();
    if (user == null || user.role != UserRole.leader || password == null) {
      throw StateError('A verified Leader account is required.');
    }
    final result = await _client.rpc(
      'leader_member_match_assignments',
      params: {
        'p_requester_id': user.id,
        'p_password': password,
        'p_assigned_to': member.id,
      },
    ).timeout(const Duration(seconds: 20));
    return List<Map<String, dynamic>>.from(result as List)
        .map(MatchAssignment.fromMap)
        .toList();
  }

  Future<void> updateTeamCodes({
    required String password,
    required String strategyCode,
    required String leaderCode,
  }) async {
    final user = AuthService.instance.currentUser;
    if (user == null || user.role != UserRole.leader) {
      throw StateError('Only a Leader can change team access codes.');
    }
    await _client.rpc(
      'leader_update_team_role_codes',
      params: {
        'p_requester_id': user.id,
        'p_password': password,
        'p_strategy_code': strategyCode,
        'p_leader_code': leaderCode,
      },
    ).timeout(const Duration(seconds: 20));
  }

  Future<void> setAssignment({
    required TeamMember member,
    required MatchAssignment assignment,
    required bool assigned,
  }) async {
    final user = AuthService.instance.currentUser;
    final password = await AuthService.instance.currentPassword();
    if (user == null || user.role != UserRole.leader || password == null) {
      throw StateError('A verified Leader account is required.');
    }
    await _client.rpc(
      'leader_set_match_assignment',
      params: {
        'p_requester_id': user.id,
        'p_password': password,
        'p_assigned_to': member.id,
        'p_competition_id': assignment.competitionId,
        'p_match_level': assignment.matchLevel,
        'p_set_number': assignment.setNumber,
        'p_match_number': assignment.matchNumber,
        'p_assigned': assigned,
      },
    ).timeout(const Duration(seconds: 20));
    if (member.id == user.id) {
      final mine = await _read(user.id);
      mine.removeWhere(
        (item) => item.matches(
          competitionId: assignment.competitionId,
          matchLevel: assignment.matchLevel,
          setNumber: assignment.setNumber,
          matchNumber: assignment.matchNumber,
        ),
      );
      if (assigned) mine.add(assignment);
      await _save(user.id, mine);
    }
  }

  Future<List<MatchAssignment>> _read(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey(userId));
    if (raw == null || raw.isEmpty) return [];
    try {
      return (json.decode(raw) as List)
          .map(
            (row) =>
                MatchAssignment.fromMap(Map<String, dynamic>.from(row as Map)),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(String userId, List<MatchAssignment> assignments) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey(userId),
      json.encode(assignments.map((entry) => entry.toMap()).toList()),
    );
  }
}
