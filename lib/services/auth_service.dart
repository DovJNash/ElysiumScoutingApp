import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../config/supabase_config.dart';
import '../models/user_model.dart';

class AuthService extends ChangeNotifier {
  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  /// Per project: a login saved for another Supabase project is never reused.
  static String get _prefsKey =>
      'current_frc_user_v3_${SupabaseConfig.projectRef}';
  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  SupabaseClient get _supabase => Supabase.instance.client;

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        _currentUser =
            UserModel.fromMap(json.decode(raw) as Map<String, dynamic>);
        if (_currentUser!.id.isEmpty) _currentUser = null;
      } catch (_) {
        _currentUser = null;
      }
      notifyListeners();
    }
  }

  Future<void> _saveSession(UserModel user) async {
    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, json.encode(user.toMap()));
    notifyListeners();
  }

  static const _credentialsKey = 'elysium_offline_credentials';
  static const _profilesKey = 'elysium_offline_profiles';

  Map<String, dynamic> _readMap(SharedPreferences prefs, String key) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      return Map<String, dynamic>.from(json.decode(raw) as Map);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  /// Remembers the password AND the profile of every account that logged in
  /// on this device, so that account can log in again without internet.
  Future<void> _saveCredential({
    required String name,
    required String password,
    required UserModel user,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final id = name.trim().toLowerCase();
    final credentials = _readMap(prefs, _credentialsKey)..[id] = password;
    final profiles = _readMap(prefs, _profilesKey)..[id] = user.toMap();
    await prefs.setString(_credentialsKey, json.encode(credentials));
    await prefs.setString(_profilesKey, json.encode(profiles));
  }

  /// Offline login. It returns the profile of the account that was typed in
  /// (it used to return whichever account was saved as the current session -
  /// and nothing at all after a log out, so it never worked).
  Future<UserModel?> _offlineLogin({
    required String name,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final id = name.trim().toLowerCase();
    final expected = _readMap(prefs, _credentialsKey)[id];
    if (expected == null || expected != password) return null;

    final profile = _readMap(prefs, _profilesKey)[id];
    if (profile is Map) {
      final user = UserModel.fromMap(Map<String, dynamic>.from(profile));
      return user.id.isEmpty ? null : user;
    }
    // Accounts saved by an older version: use the saved session if it is the
    // same account.
    final sessionRaw = prefs.getString(_prefsKey);
    if (sessionRaw == null) return null;
    try {
      final user = UserModel.fromMap(
          Map<String, dynamic>.from(json.decode(sessionRaw) as Map));
      return user.id.isNotEmpty && user.name.trim().toLowerCase() == id
          ? user
          : null;
    } catch (_) {
      return null;
    }
  }

  /// True only for "no connection" problems. A wrong password or a missing
  /// account must NOT fall back to the offline login.
  bool _isNetworkError(Object e) {
    if (e is TimeoutException) return true;
    if (e is PostgrestException) return false;
    final text = e.toString();
    return text.contains('SocketException') ||
        text.contains('ClientException') ||
        text.contains('HandshakeException') ||
        text.contains('Failed host lookup') ||
        text.contains('XMLHttpRequest') ||
        text.contains('Connection') ||
        text.contains('Network is unreachable');
  }

  String _friendly(Object e) {
    if (e is PostgrestException) {
      final code = e.code ?? '';
      if (code == 'PGRST202' ||
          code == '42883' ||
          e.message.contains('schema cache')) {
        return 'The database is not set up yet (login function not found). '
            'Open Supabase -> SQL Editor, run supabase_setup.sql, wait about '
            '10 seconds and try again. Make sure the URL/key in '
            'supabase_config.dart belong to the same project.';
      }
      if (code == '42P01' || code == 'PGRST205') {
        return 'The login table is missing in this Supabase project. '
            'Run supabase_setup.sql in the SQL Editor.';
      }
      return e.message;
    }
    final text = e.toString();
    if (text.contains('SocketException') ||
        text.contains('ClientException') ||
        text.contains('Failed host lookup') ||
        text.contains('XMLHttpRequest') ||
        e is TimeoutException) {
      return 'No internet connection. Logging in / signing up needs internet.';
    }
    return text.replaceFirst('Exception: ', '');
  }

  Future<UserModel> login({
    required String name,
    required String password,
  }) async {
    if (name.trim().isEmpty || password.isEmpty) {
      throw Exception('Please enter both name and password.');
    }
    try {
      final res = await _supabase.rpc('app_login', params: {
        'p_name': name.trim(),
        'p_password': password,
      }).timeout(const Duration(seconds: 20));
      final rows = List<Map<String, dynamic>>.from(res as List);
      if (rows.isEmpty) throw Exception('Invalid name or password.');
      final user = UserModel.fromRpc(rows.first);
      await _saveCredential(name: name, password: password, user: user);
      await _saveSession(user);
      return user;
    } catch (e) {
      if (_isNetworkError(e)) {
        final offline = await _offlineLogin(name: name, password: password);
        if (offline != null) {
          await _saveSession(offline);
          return offline;
        }
      }
      throw Exception(_friendly(e));
    }
  }

  Future<UserModel> signUp({
    required String name,
    required String password,
    required String role,
    String roleAccessCode = '',
    int teamNumber = 0,
    String teamName = '',
  }) async {
    if (name.trim().isEmpty || password.isEmpty) {
      throw Exception('Name and password cannot be empty.');
    }
    try {
      final res = await _supabase.rpc('app_signup', params: {
        'p_id': const Uuid().v4(),
        'p_name': name.trim(),
        'p_password': password, // plain text, per your specification
        'p_role': UserRole.normalize(role),
        'p_code': roleAccessCode.trim(),
        'p_team_number': teamNumber,
        'p_team_name': teamName.trim(),
      }).timeout(const Duration(seconds: 20));
      final rows = List<Map<String, dynamic>>.from(res as List);
      if (rows.isEmpty) throw Exception('Sign up failed. Please try again.');
      final user = UserModel.fromRpc(rows.first);
      await _saveCredential(name: name, password: password, user: user);
      await _saveSession(user);
      return user;
    } catch (e) {
      throw Exception(_friendly(e));
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    notifyListeners();
  }
}
