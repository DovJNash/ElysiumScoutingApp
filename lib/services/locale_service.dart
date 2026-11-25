import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleService extends ChangeNotifier {
  LocaleService._();
  static final instance = LocaleService._();

  static const String _prefsKey = 'elysium_locale';
  Locale _locale = const Locale('en');

  Locale get locale => _locale;
  bool get isHebrew => _locale.languageCode == 'he';

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    if (code == 'he') _locale = const Locale('he');
  }

  class LocaleSwitchButton extends StatelessWidget {
    const LocaleSwitchButton({super.key});

    @override
    Widget build(BuildContext context) {
      final service = LocaleService.instance;
      return IconButton(
        tooltip: service.text('language'),
        onPressed: () => service.setLocale(
          service.isHebrew ? const Locale('en') : const Locale('he'),
        ),
        icon: const Icon(Icons.language_rounded),
      );
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (locale.languageCode != 'en' && locale.languageCode != 'he') return;
    _locale = Locale(locale.languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, locale.languageCode);
    notifyListeners();
  }

  String text(String key) {
    final value = _isHebrew ? _he[key] : _en[key];
    return value ?? _en[key] ?? key;
  }

  bool get _isHebrew => _locale.languageCode == 'he';

  static const Map<String, String> _en = {
    'app_name': 'Elysium 1937 Scouting App',
    'login': 'Log In',
    'signup': 'Sign Up',
    'name': 'Name',
    'password': 'Password',
    'role': 'Role',
    'team_number': 'Team number',
    'team_access_code': 'Team access code',
    'language': 'Language',
  };

  static const Map<String, String> _he = {
    'app_name': 'אפליקציית הסקאוטינג של אליסיום 1937',
    'login': 'כניסה',
    'signup': 'הרשמה',
    'name': 'שם',
    'password': 'סיסמה',
    'role': 'תפקיד',
    'team_number': 'מספר קבוצה',
    'team_access_code': 'קוד גישה לקבוצה',
    'language': 'שפה',
  };
}
