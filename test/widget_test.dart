import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frc_scouting_app/models/pit_scouting_entry.dart';
import 'package:frc_scouting_app/models/user_model.dart';
import 'package:frc_scouting_app/screens/auth_screen.dart';
import 'package:frc_scouting_app/services/locale_service.dart';
import 'package:frc_scouting_app/services/tba_service.dart';

void main() {
  test('user model preserves team identity', () {
    const user = UserModel(
      id: 'user-1',
      name: 'Scout',
      role: 'Scouter',
      teamNumber: 1937,
      teamName: 'Elysium',
    );

    expect(UserModel.fromMap(user.toMap()).teamNumber, 1937);
    expect(UserModel.fromMap(user.toMap()).teamName, 'Elysium');
  });

  test('pit scouting unique key scopes team, competition and scouter', () {
    final key = PitScoutingEntry.buildUniqueKey(
      competition: 'DCMP',
      teamNum: 1690,
      scouterId: 'scouter-1',
    );

    expect(key, 'PIT_DCMP_1690_scouter-1');
  });

  test('TBA match parses qualification alliances and live scores', () {
    final match = TbaMatch.fromJson({
      'key': '2025isde1_qm14',
      'event_key': '2025isde1',
      'comp_level': 'qm',
      'match_number': 14,
      'set_number': 1,
      'alliances': {
        'red': {
          'team_keys': ['frc1937', 'frc1690'],
          'score': 120,
        },
        'blue': {
          'team_keys': ['frc1574', 'frc5987'],
          'score': 105,
        },
      },
    });

    expect(match.matchNumber, 14);
    expect(match.redTeams, [1937, 1690]);
    expect(match.blueTeams, [1574, 5987]);
    expect(match.redScore, 120);
    expect(match.blueScore, 105);
  });

  test('TBA team keeps country and season avatar data for registration', () {
    final team = TbaTeam.fromJson({
      'key': 'frc1937',
      'nickname': 'Elysium',
      'country': 'Israel',
    });

    expect(team.number, 1937);
    expect(team.country, 'Israel');
    expect(team.logoUrl, contains('/avatar/2027/frc1937.png'));
    expect(
      TbaTeam.fromJson(team.toJson()).logoUrl,
      team.logoUrl,
    );
    expect(
      TbaTeam.fromJson({
        'key': 'frc1690',
        'name': 'Orbit Robotics',
      }).name,
      'Orbit Robotics',
    );
  });

  test('TBA Israel district event exposes a selectable event key and label',
      () {
    final event = TbaEvent.fromJson({
      'key': '2027isde1',
      'name': 'ISR District Event #1',
      'city': 'Tel Aviv-Yafo',
    });

    expect(event.key, '2027isde1');
    expect(event.label, 'ISR District Event #1 — Tel Aviv-Yafo');
  });

  test('Hebrew is the default and locale switching translates UI text', () async {
    SharedPreferences.setMockInitialValues({});
    await LocaleService.instance.initialize();

    expect(LocaleService.instance.isHebrew, isTrue);
    expect(LocaleService.instance.text('SIGN UP'), 'הרשמה');

    var changedImmediately = false;
    void listener() => changedImmediately = true;
    LocaleService.instance.addListener(listener);
    final switching = LocaleService.instance.setLocale(const Locale('en'));
    expect(changedImmediately, isTrue);
    await switching;
    LocaleService.instance.removeListener(listener);
    expect(LocaleService.instance.text('SIGN UP'), 'SIGN UP');

    await LocaleService.instance.setLocale(const Locale('he'));
    expect(LocaleService.instance.text('SIGN UP'), 'הרשמה');
  });

  testWidgets('registration can select a team manually when TBA is unavailable',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await LocaleService.instance.setLocale(const Locale('en'));
    await tester.binding.setSurfaceSize(const Size(900, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
    await tester.tap(find.byIcon(Icons.language_rounded));
    await tester.pump();
    expect(find.text('הרשמה'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.language_rounded));
    await tester.pump();
    expect(find.text('SIGN UP'), findsOneWidget);

    await tester.tap(find.text('SIGN UP'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('Can’t load or find your team? Enter it manually'),
      findsOneWidget,
    );
    await tester.tap(
      find.text('Can’t load or find your team? Enter it manually'),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '1690');
    await tester.enterText(find.byType(TextField).at(2), 'Orbit');
    await tester.tap(find.text('Continue with this team'));
    await tester.pumpAndSettle();

    expect(find.text('What is your role?'), findsOneWidget);
    expect(find.text('1690 - Orbit'), findsOneWidget);
  });
}
