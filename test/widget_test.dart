import 'package:flutter_test/flutter_test.dart';

import 'package:frc_scouting_app/models/pit_scouting_entry.dart';
import 'package:frc_scouting_app/models/user_model.dart';
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
}
