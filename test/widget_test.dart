import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frc_scouting_app/models/pit_scouting_entry.dart';
import 'package:frc_scouting_app/models/scouting_entry.dart';
import 'package:frc_scouting_app/models/team_model.dart';
import 'package:frc_scouting_app/models/user_model.dart';
import 'package:frc_scouting_app/screens/auth_screen.dart';
import 'package:frc_scouting_app/services/locale_service.dart';
import 'package:frc_scouting_app/services/pit_scouting_service.dart';
import 'package:frc_scouting_app/services/tba_service.dart';
import 'package:frc_scouting_app/services/match_assignment_service.dart';
import 'package:frc_scouting_app/theme/elysium_theme.dart';
import 'package:frc_scouting_app/widgets/pit_data_view.dart';

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

  test('scouting entry round-trips the V3 match fields and no-show state', () {
    final entry = ScoutingEntry(
      id: 'entry-1',
      uniqueKey: '2026isde1_1690_qf_1_2_scouter-1',
      competition: '2026isde1',
      scouterId: 'scouter-1',
      scouterName: 'Scout',
      teamNum: 1690,
      matchNum: 2,
      matchLevel: 'qf',
      matchSet: 1,
      startPos: '',
      exitPos: '',
      autoShoot: 0,
      autoIntake: 0,
      allianceCount: 0,
      neutralCount: 0,
      opponentCount: 0,
      teleopShoot: 0,
      teleopIntake: 0,
      robotShowed: false,
      autoCycles: 0,
      autoFuelsDelivered: 0,
      autoIntakeSpeed: 0,
      autoPerformance: 0,
      teleopCanShootMoving: false,
      teleopCycles: 0,
      teleopFuelsDelivered: 0,
      teleopIntakeSpeed: 0,
      teleopAccuracy: 0,
      teleopPerformance: 0,
      playedDefense: false,
      defenseRating: 0,
      dealtWithDefense: false,
      defenseResilience: 0,
      climbed: false,
      climbLevel: '',
      climbTimeSeconds: 0,
      doingDefence: 0,
      standDefence: 0,
      driverSkill: 0,
      notes: 'Robot did not show up.',
      durationSeconds: 60,
      createdAt: '2026-03-01T10:00:00.000Z',
      isSynced: false,
    );

    final restored = ScoutingEntry.fromMap(entry.toSqliteMap());
    expect(restored.robotShowed, isFalse);
    expect(restored.matchLevel, 'qf');
    expect(restored.matchSet, 1);
    expect(restored.notes, 'Robot did not show up.');
    expect(restored.autoPerformance, 0);
    expect(restored.toSupabaseMap()['robotShowed'], isFalse);
  });

  test('match assignment matches event, level, set, and number', () {
    const assignment = MatchAssignment(
      competitionId: '2026isde1',
      matchLevel: 'qf',
      setNumber: 2,
      matchNumber: 1,
    );

    expect(
      assignment.matches(
        competitionId: '2026isde1',
        matchLevel: 'qf',
        setNumber: 2,
        matchNumber: 1,
      ),
      isTrue,
    );
    expect(
      assignment.matches(
        competitionId: '2026isde1',
        matchLevel: 'qm',
        setNumber: 2,
        matchNumber: 1,
      ),
      isFalse,
    );
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

  test('TBA unplayed match (score -1) has no score', () {
    final match = TbaMatch.fromJson({
      'key': '2027isde1_qm1',
      'event_key': '2027isde1',
      'comp_level': 'qm',
      'match_number': 1,
      'set_number': 1,
      'alliances': {
        'red': {
          'team_keys': ['frc1937'],
          'score': -1,
        },
        'blue': {
          'team_keys': ['frc1690'],
          'score': -1,
        },
      },
    });

    expect(match.redScore, isNull);
    expect(match.blueScore, isNull);
  });

  test('TBA schedule lists qualifications before playoffs', () {
    TbaMatch match(String level, int set, int number) => TbaMatch.fromJson({
          'key': '2027x_$level${set}m$number',
          'event_key': '2027x',
          'comp_level': level,
          'match_number': number,
          'set_number': set,
          'alliances': {
            'red': {'team_keys': <String>[], 'score': -1},
            'blue': {'team_keys': <String>[], 'score': -1},
          },
        });

    final list = [
      match('f', 1, 1),
      match('sf', 2, 1),
      match('qm', 1, 2),
      match('sf', 1, 1),
      match('qm', 1, 1),
    ]..sort(TbaMatch.compareSchedule);

    expect(list.map((e) => e.key).toList(), [
      '2027x_qm1m1',
      '2027x_qm1m2',
      '2027x_sf1m1',
      '2027x_sf2m1',
      '2027x_f1m1',
    ]);
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
    expect(TbaTeam.fromJson(team.toJson()).logoUrl, team.logoUrl);
    expect(
      TbaTeam.fromJson({'key': 'frc1690', 'name': 'Orbit Robotics'}).name,
      'Orbit Robotics',
    );
  });

  test(
    'TBA Israel district event exposes a selectable event key and label',
    () {
      final event = TbaEvent.fromJson({
        'key': '2027isde1',
        'name': 'ISR District Event #1',
        'city': 'Tel Aviv-Yafo',
      });

      expect(event.key, '2027isde1');
      expect(event.label, 'ISR District Event #1 — Tel Aviv-Yafo');
    },
  );

  test('TBA Israeli offseason event keeps country when cached', () {
    final event = TbaEvent.fromJson({
      'key': '2026isr',
      'name': 'ISR 2026 IOS',
      'city': 'Haifa',
      'country': 'Israel',
    });

    expect(TbaEvent.fromJson(event.toJson()).country, 'Israel');
    expect(event.label, 'ISR 2026 IOS — Haifa');
  });

  test(
    'Hebrew is the default and locale switching translates UI text',
    () async {
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
    },
  );

  testWidgets(
    'registration can select a team manually when TBA is unavailable',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await LocaleService.instance.setLocale(const Locale('en'));
      await tester.binding.setSurfaceSize(const Size(900, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
      final logoCenter = tester.getCenter(find.byType(ElysiumFullLogo));
      await tester.tap(find.byIcon(Icons.language_rounded));
      await tester.pump();
      expect(find.text('הרשמה'), findsOneWidget);
      expect(tester.getCenter(find.byType(ElysiumFullLogo)), logoCenter);
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
    },
  );

  testWidgets('pit data lists every team with its number of forms', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await LocaleService.instance.setLocale(const Locale('en'));
    await tester.binding.setSurfaceSize(const Size(900, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    PitScoutingEntry form(String id, String scouter, String auto) =>
        PitScoutingEntry(
          id: id,
          uniqueKey: 'PIT_2027isde1_1690_$scouter',
          competition: '2027isde1',
          scouterId: scouter,
          scouterName: scouter,
          teamNum: 1690,
          autonomousTypes: auto,
          strengths: 'Fast cycles',
          difficulties: '',
          defense: 'Plays no defense',
          otherNotes: '',
          durationSeconds: 60,
          createdAt: '2027-03-01T10:00:00.000Z',
        );

    PitScoutingService.instance.entries
      ..clear()
      ..addAll([
        form('a', 'dana', 'Two-piece auto'),
        form('b', 'omer', 'Leave only'),
      ]);
    addTearDown(PitScoutingService.instance.entries.clear);

    const competition = CompetitionInfo(
      id: '2027isde1',
      name: 'District 1',
      teams: [
        TeamInfo(number: 1690, name: 'Orbit', logoUrl: ''),
        TeamInfo(number: 1574, name: 'MisCar', logoUrl: ''),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PitDataView(competition: competition)),
      ),
    );
    await tester.pumpAndSettle();

    // Every team of the competition is listed, with its form count.
    // (the number is shown in the title and inside the logo placeholder)
    expect(find.text('1690'), findsWidgets);
    expect(find.text('1574'), findsWidgets);
    expect(find.text('2 pit forms'), findsOneWidget);
    expect(find.text('No pit forms yet'), findsOneWidget);
    expect(find.text('1 of 2 teams scouted • 2 forms'), findsOneWidget);

    // Opening a team shows the data of all its forms.
    await tester.tap(find.text('1690').first);
    await tester.pumpAndSettle();
    expect(find.text('Two-piece auto'), findsOneWidget);
    expect(find.text('Leave only'), findsOneWidget);
  });
}
