import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../models/scouting_entry.dart';
import '../models/scouting_form_config.dart';
import '../models/team_model.dart';
import '../services/auth_service.dart';
import '../services/data_repository.dart';
import '../services/sync_service.dart';
import '../theme/elysium_theme.dart';
import '../widgets/entry_detail_dialog.dart';
import '../widgets/my_submissions_sheet.dart';
import '../widgets/responsive_counter_pad.dart';
import '../widgets/sync_status_badge.dart';
import '../widgets/team_picker.dart';
import '../services/locale_service.dart';
import '../widgets/match_schedule_page.dart';
import '../widgets/localized_text.dart';
import '../widgets/field_diagram_picker.dart';
import '../widgets/profile_page.dart';
import '../services/match_assignment_service.dart';

class ScouterHomeScreen extends StatefulWidget {
  const ScouterHomeScreen({super.key});

  @override
  State<ScouterHomeScreen> createState() => _ScouterHomeScreenState();
}

class _ScouterHomeScreenState extends State<ScouterHomeScreen> {
  List<CompetitionInfo> _competitions = [];
  CompetitionInfo? _competition;
  TeamInfo? _team;
  final List<MatchAssignment> _myAssignments = [];
  MatchAssignment? _selectedAssignment;
  int _year = 2027;
  bool _loadingCompetitions = true;
  String? _assignmentError;

  int _step = 0;
  DateTime? _startedAt;

  final _matchController = TextEditingController();
  final _notesController = TextEditingController();

  String _startPos = ScoutingFormConfig.startPositions.first;
  String _exitPos = ScoutingFormConfig.exitPaths.first;

  int _autoShoot = 0;
  int _autoCycles = 0;
  int _autoFuelsDelivered = 0;
  int _autoIntakeSpeed = 5;
  int _autoPerformance = 3;
  int _teleopShoot = 0;
  int _teleopCycles = 0;
  int _teleopFuelsDelivered = 0;
  int _teleopIntakeSpeed = 5;
  int _teleopAccuracy = 3;
  int _teleopPerformance = 5;
  int _defenseRating = 3;
  int _defenseResilience = 3;
  int _driverSkill = 5;
  int _climbTimeSeconds = 0;
  bool _robotShowed = true;
  bool _teleopCanShootMoving = false;
  bool _playedDefense = false;
  bool _dealtWithDefense = false;
  bool _climbed = false;
  String _climbLevel = 'L1';

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadCompetitions();
  }

  bool get _limitedToAssignments =>
      AuthService.instance.currentUser?.role != 'Leader';

  Future<void> _loadCompetitions() async {
    setState(() => _loadingCompetitions = true);
    List<MatchAssignment> assignments = [];
    String? assignmentError;
    if (_limitedToAssignments) {
      try {
        assignments = await MatchAssignmentService.instance.loadMine(
          refresh: true,
        );
      } catch (error) {
        assignmentError = error.toString().replaceFirst('Exception: ', '');
      }
    }
    List<CompetitionInfo> competitions;
    try {
      competitions = await CompetitionRepository.loadCompetitions(year: _year);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _assignmentError =
            assignmentError ?? error.toString().replaceFirst('Exception: ', '');
        _loadingCompetitions = false;
      });
      return;
    }
    if (_limitedToAssignments) {
      final assignedIds =
          assignments.map((assignment) => assignment.competitionId).toSet();
      competitions =
          competitions.where((item) => assignedIds.contains(item.id)).toList();
    }
    if (!mounted) return;
    setState(() {
      _myAssignments
        ..clear()
        ..addAll(assignments);
      _competitions = competitions;
      _assignmentError = assignmentError;
      _loadingCompetitions = false;
      if (_competition != null &&
          !_competitions.any((item) => item.id == _competition!.id)) {
        _competition = null;
        _selectedAssignment = null;
      }
    });
  }

  @override
  void dispose() {
    _matchController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _step = 0;
    _startedAt = DateTime.now();
    _matchController.clear();
    _notesController.clear();
    _startPos = ScoutingFormConfig.startPositions.first;
    _exitPos = ScoutingFormConfig.exitPaths.first;
    _autoShoot = 0;
    _autoCycles = 0;
    _autoFuelsDelivered = 0;
    _autoIntakeSpeed = 5;
    _autoPerformance = 3;
    _teleopShoot = 0;
    _teleopCycles = 0;
    _teleopFuelsDelivered = 0;
    _teleopIntakeSpeed = 5;
    _teleopAccuracy = 3;
    _teleopPerformance = 5;
    _defenseRating = 3;
    _defenseResilience = 3;
    _driverSkill = 5;
    _climbTimeSeconds = 0;
    _robotShowed = true;
    _teleopCanShootMoving = false;
    _playedDefense = false;
    _dealtWithDefense = false;
    _climbed = false;
    _climbLevel = 'L1';
  }

  /// Android back button / swipe: go up one level instead of closing the app.
  void _goBack() {
    setState(() {
      if (_team != null) {
        if (_step > 0) {
          _step--;
        } else {
          _team = null;
        }
      } else if (_competition != null) {
        _competition = null;
      }
    });
  }

  int? get _matchNum => _limitedToAssignments
      ? _selectedAssignment?.matchNumber
      : int.tryParse(_matchController.text.trim());
  String get _matchLevel =>
      _limitedToAssignments ? _selectedAssignment?.matchLevel ?? 'qm' : 'qm';
  int get _matchSet =>
      _limitedToAssignments ? _selectedAssignment?.setNumber ?? 1 : 1;

  MatchAssignment? _firstAssignedMatch(String competitionId) {
    for (final assignment in _myAssignments) {
      if (assignment.competitionId == competitionId) return assignment;
    }
    return null;
  }

  void _next() {
    if (_step == 0 && (_matchNum == null || _matchNum! <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid match number first.')),
      );
      return;
    }
    if (_step == 0 &&
        _limitedToAssignments &&
        (_selectedAssignment == null ||
            _selectedAssignment!.competitionId != _competition?.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a match assigned to you.')),
      );
      return;
    }
    if (_step == 1 && !_robotShowed) {
      _submit();
      return;
    }
    if (_step < ScoutingFormConfig.stepTitles.length - 1) {
      setState(() => _step++);
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final matchNum = _matchNum;
    if (matchNum == null || matchNum <= 0) {
      setState(() => _step = 0);
      return;
    }
    final user = AuthService.instance.currentUser!;
    final comp = _competition!;
    final team = _team!;

    final uniqueKey = ScoutingEntry.buildUniqueKey(
      competition: comp.id,
      teamNum: team.number,
      matchNum: matchNum,
      matchLevel: _matchLevel,
      matchSet: _matchSet,
      scouterId: user.id,
    );

    final exists = DataRepository.instance.scouting.any(
      (e) => e.uniqueKey == uniqueKey,
    );
    if (exists) {
      final overwrite = await confirmDialog(
        context,
        title: 'Already submitted',
        message:
            'You already scouted Team ${team.number} in match $matchNum. Replace your earlier form?',
        confirmLabel: 'Replace',
      );
      if (!overwrite) return;
    }

    setState(() => _submitting = true);

    final duration = _startedAt == null
        ? 60
        : DateTime.now().difference(_startedAt!).inSeconds.clamp(5, 3600);

    final entry = ScoutingEntry(
      id: const Uuid().v4(),
      uniqueKey: uniqueKey,
      competition: comp.id,
      scouterId: user.id,
      scouterName: user.name,
      teamNum: team.number,
      matchNum: matchNum,
      matchLevel: _matchLevel,
      matchSet: _matchSet,
      startPos: _robotShowed ? _startPos : '',
      exitPos: _robotShowed ? _exitPos : '',
      autoShoot: _robotShowed ? _autoShoot : 0,
      autoIntake: _robotShowed ? _autoFuelsDelivered : 0,
      allianceCount: 0,
      neutralCount: 0,
      opponentCount: 0,
      teleopShoot: _robotShowed ? _teleopShoot : 0,
      teleopIntake: _robotShowed ? _teleopFuelsDelivered : 0,
      robotShowed: _robotShowed,
      fuelCountsAreRanges: _robotShowed,
      autoCycles: _robotShowed ? _autoCycles : 0,
      autoFuelsDelivered: _robotShowed ? _autoFuelsDelivered : 0,
      autoIntakeSpeed: _robotShowed ? _autoIntakeSpeed : 0,
      autoPerformance: _robotShowed ? _autoPerformance : 0,
      teleopCanShootMoving: _robotShowed && _teleopCanShootMoving,
      teleopCycles: _robotShowed ? _teleopCycles : 0,
      teleopFuelsDelivered: _robotShowed ? _teleopFuelsDelivered : 0,
      teleopIntakeSpeed: _robotShowed ? _teleopIntakeSpeed : 0,
      teleopAccuracy: _robotShowed ? _teleopAccuracy : 0,
      teleopPerformance: _robotShowed ? _teleopPerformance : 0,
      playedDefense: _robotShowed && _playedDefense,
      defenseRating: _robotShowed && _playedDefense ? _defenseRating : 0,
      dealtWithDefense: _robotShowed && _dealtWithDefense,
      defenseResilience:
          _robotShowed && _dealtWithDefense ? _defenseResilience : 0,
      climbed: _robotShowed && _climbed,
      climbLevel: _robotShowed && _climbed ? _climbLevel : '',
      climbTimeSeconds: _robotShowed && _climbed ? _climbTimeSeconds : 0,
      doingDefence: _robotShowed && _playedDefense ? _defenseRating : 0,
      standDefence: _robotShowed && _dealtWithDefense ? _defenseResilience : 0,
      driverSkill: _robotShowed ? _driverSkill : 0,
      notes: _robotShowed
          ? _notesController.text.trim()
          : 'Robot did not show up.',
      durationSeconds: duration,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      isSynced: false,
    );

    bool synced = false;
    try {
      synced = await SyncService.instance.submitScouting(entry);
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save scouting form: $error')),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _team = null;
      _robotShowed = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          synced
              ? 'Match $matchNum • Team ${team.number} submitted & synced!'
              : 'Saved on this device. It will upload automatically when internet returns.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser!;
    final atRoot = _competition == null;

    return PopScope(
      canPop: atRoot,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: ElysiumAppBarTitle('Scouter • ${user.name}'),
          actions: [
            const SyncStatusBadge(),
            IconButton(
              tooltip: 'Submitted forms',
              onPressed: () =>
                  showMySubmissionsSheet(context, superMode: false),
              icon: const Icon(Icons.history_rounded),
            ),
            IconButton(
              tooltip: 'Account',
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const ProfilePage())),
              icon: const Icon(Icons.account_circle_rounded),
            ),
            IconButton(
              tooltip: 'Match Schedule',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Match Schedule')),
                    body: const MatchSchedulePage(filterToMyAssignments: true),
                  ),
                ),
              ),
              icon: const Icon(Icons.calendar_month_rounded),
            ),
          ],
        ),
        body: _competition == null
            ? _competitionMenu()
            : _team == null
                ? TeamPicker(
                    competition: _competition!,
                    accent: Elysium.primary,
                    onBack: () => setState(() => _competition = null),
                    onSelected: (t) => setState(() {
                      _team = t;
                      _resetForm();
                    }),
                  )
                : _wizard(),
      ),
    );
  }

  Widget _competitionMenu() {
    if (_loadingCompetitions) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(child: SectionTitle('Select Competition')),
            DropdownButton<int>(
              value: _year,
              items: const [2026, 2027]
                  .map(
                    (year) =>
                        DropdownMenuItem(value: year, child: Text('$year')),
                  )
                  .toList(),
              onChanged: (year) {
                if (year == null) return;
                setState(() {
                  _year = year;
                  _competition = null;
                });
                _loadCompetitions();
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_assignmentError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _assignmentError!,
              style: const TextStyle(color: Elysium.warning),
            ),
          ),
        if (_competitions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              _limitedToAssignments
                  ? 'No matches have been assigned to you.'
                  : 'No competitions found.',
              textAlign: TextAlign.center,
            ),
          ),
        ..._competitions.map(
          (comp) => ElysiumCard(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 8,
              ),
              leading: CircleAvatar(
                backgroundColor: Elysium.primary.fade(0.2),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: Elysium.primary,
                ),
              ),
              title: Text(
                comp.name,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text('${comp.teams.length} registered teams'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => setState(() {
                _competition = comp;
                _selectedAssignment =
                    _limitedToAssignments ? _firstAssignedMatch(comp.id) : null;
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _wizard() {
    final team = _team!;
    final last = _step == ScoutingFormConfig.stepTitles.length - 1;
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  TeamLogo(team: team, size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Team ${team.number} (${team.name})',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    ScoutingFormConfig.stepTitles[_step],
                    style: const TextStyle(
                      color: Elysium.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: (_step + 1) / ScoutingFormConfig.stepTitles.length,
                borderRadius: BorderRadius.circular(8),
                minHeight: 6,
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _stepBody(),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(top: BorderSide(color: theme.dividerColor)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _goBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: Text(_step > 0 ? 'Back' : 'Change Team'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : _next,
                      icon: Icon(
                        last
                            ? Icons.cloud_upload_rounded
                            : Icons.arrow_forward_rounded,
                      ),
                      label: Text(
                        last
                            ? (_submitting ? 'Submitting...' : 'Submit')
                            : 'Next',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _chipGroup(
    List<String> options,
    String selected,
    ValueChanged<String> onPick,
  ) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options
          .map(
            (o) => ChoiceChip(
              label: Text(o),
              selected: selected == o,
              selectedColor: theme.colorScheme.primary,
              backgroundColor: dark
                  ? const Color(0xFF243A56)
                  : Elysium.surface2,
              showCheckmark: false,
              side: BorderSide(
                color: selected == o
                    ? theme.colorScheme.primary
                    : dark
                        ? const Color(0xFF526783)
                        : Elysium.border,
              ),
              labelStyle: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected == o
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
              ),
              onSelected: (_) => onPick(o),
            ),
          )
          .toList(),
    );
  }

  String _matchLabel(MatchAssignment assignment) =>
      assignment.matchLevel == 'qm'
          ? 'Qualification ${assignment.matchNumber}'
          : '${assignment.matchLevel.toUpperCase()} '
              '${assignment.setNumber}-${assignment.matchNumber}';

  Widget _stepBody() {
    switch (_step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_limitedToAssignments)
              DropdownButtonFormField<MatchAssignment>(
                initialValue: _myAssignments
                        .where(
                          (assignment) =>
                              assignment.competitionId == _competition!.id,
                        )
                        .contains(_selectedAssignment)
                    ? _selectedAssignment
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Assigned match'),
                items: _myAssignments
                    .where(
                      (assignment) =>
                          assignment.competitionId == _competition!.id,
                    )
                    .map(
                      (assignment) => DropdownMenuItem(
                        value: assignment,
                        child: Text(_matchLabel(assignment)),
                      ),
                    )
                    .toList(),
                onChanged: (assignment) =>
                    setState(() => _selectedAssignment = assignment),
              )
            else
              TextField(
                controller: _matchController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: LocaleService.instance.text('Match Number'),
                  hintText: LocaleService.instance.text('e.g., 14'),
                  prefixIcon: const Icon(Icons.tag_rounded),
                ),
              ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionTitle('Did the robot show up to the match?'),
            const SizedBox(height: 14),
            _yesNo(
              'Did the robot show up to the match?',
              _robotShowed,
              (value) => setState(() => _robotShowed = value),
            ),
            if (!_robotShowed) ...[
              const SizedBox(height: 12),
              const ElysiumCard(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Selecting No will submit this match with empty gameplay values and a note that the robot did not show up.',
                ),
              ),
            ],
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FieldDiagramPicker(
              title: 'Starting Position',
              value: _startPos,
              options: ScoutingFormConfig.startPositions,
              onChanged: (v) => setState(() => _startPos = v),
            ),
            const SizedBox(height: 14),
            _scaleSlider(
              'How many fuels did the robot shoot? (range)',
              _autoShoot,
              10,
              ScoutingFormConfig.fuelRangeDescriptions,
              (v) => setState(() => _autoShoot = v),
              min: 0,
            ),
            const SizedBox(height: 14),
            ResponsiveCounterPad(
              label: 'How many cycles did the robot do?',
              value: _autoCycles,
              accentColor: Elysium.accent,
              onChanged: (v) => setState(() => _autoCycles = v),
            ),
            const SizedBox(height: 14),
            _scaleSlider(
              'How many fuels did the robot deliver? (range)',
              _autoFuelsDelivered,
              10,
              ScoutingFormConfig.fuelRangeDescriptions,
              (v) => setState(() => _autoFuelsDelivered = v),
              min: 0,
            ),
            const SizedBox(height: 14),
            _scaleSlider(
              'How fast was the robot intake?',
              _autoIntakeSpeed,
              10,
              ScoutingFormConfig.speedDescriptions,
              (v) => setState(() => _autoIntakeSpeed = v),
            ),
            const SizedBox(height: 14),
            _scaleSlider(
              'Overall autonomous performance',
              _autoPerformance,
              5,
              ScoutingFormConfig.fivePointDescriptions,
              (v) => setState(() => _autoPerformance = v),
            ),
            const SizedBox(height: 14),
            FieldDiagramPicker(
              title: 'Robot exit path',
              value: _exitPos,
              options: ScoutingFormConfig.exitPaths,
              pathMode: true,
              onChanged: (v) => setState(() => _exitPos = v),
            ),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _yesNo(
              'Can the robot shoot while moving?',
              _teleopCanShootMoving,
              (value) => setState(() => _teleopCanShootMoving = value),
            ),
            const SizedBox(height: 14),
            _scaleSlider(
              'How many fuels did the robot shoot? (range)',
              _teleopShoot,
              10,
              ScoutingFormConfig.fuelRangeDescriptions,
              (v) => setState(() => _teleopShoot = v),
              min: 0,
            ),
            const SizedBox(height: 14),
            ResponsiveCounterPad(
              label: 'How many cycles did the robot do?',
              value: _teleopCycles,
              accentColor: Elysium.accent,
              onChanged: (v) => setState(() => _teleopCycles = v),
            ),
            const SizedBox(height: 14),
            _scaleSlider(
              'How many fuels did the robot deliver? (range)',
              _teleopFuelsDelivered,
              10,
              ScoutingFormConfig.fuelRangeDescriptions,
              (v) => setState(() => _teleopFuelsDelivered = v),
              min: 0,
            ),
            const SizedBox(height: 14),
            _scaleSlider(
              'How fast was the robot intake?',
              _teleopIntakeSpeed,
              10,
              ScoutingFormConfig.speedDescriptions,
              (v) => setState(() => _teleopIntakeSpeed = v),
            ),
            const SizedBox(height: 14),
            _scaleSlider(
              'How accurate is the robot shooting?',
              _teleopAccuracy,
              5,
              ScoutingFormConfig.accuracyDescriptions,
              (v) => setState(() => _teleopAccuracy = v),
            ),
            const SizedBox(height: 14),
            _scaleSlider(
              'Overall teleop performance',
              _teleopPerformance,
              10,
              ScoutingFormConfig.performanceDescriptions,
              (v) => setState(() => _teleopPerformance = v),
            ),
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _yesNo(
              'Did the robot play defense?',
              _playedDefense,
              (value) => setState(() => _playedDefense = value),
            ),
            if (_playedDefense) ...[
              const SizedBox(height: 8),
              _scaleSlider(
                'How good was the robot in defense?',
                _defenseRating,
                5,
                ScoutingFormConfig.defenseDescriptions,
                (v) => setState(() => _defenseRating = v),
              ),
            ],
            const SizedBox(height: 14),
            _yesNo(
              'Did the robot deal with defense?',
              _dealtWithDefense,
              (value) => setState(() => _dealtWithDefense = value),
            ),
            if (_dealtWithDefense) ...[
              const SizedBox(height: 8),
              _scaleSlider(
                'How good was the robot at dealing with defense?',
                _defenseResilience,
                5,
                ScoutingFormConfig.defenseResilienceDescriptions,
                (v) => setState(() => _defenseResilience = v),
              ),
            ],
            const SizedBox(height: 14),
            _scaleSlider(
              'How good was the driver?',
              _driverSkill,
              10,
              ScoutingFormConfig.performanceDescriptions,
              (v) => setState(() => _driverSkill = v),
            ),
            const SizedBox(height: 14),
            _yesNo(
              'Did the robot climb?',
              _climbed,
              (value) => setState(() => _climbed = value),
            ),
            if (_climbed) ...[
              const SizedBox(height: 8),
              const Text(
                'Climb level',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              _chipGroup(
                const ['L1', 'L2', 'L3'],
                _climbLevel,
                (value) => setState(() => _climbLevel = value),
              ),
              const SizedBox(height: 12),
              ResponsiveCounterPad(
                label: 'How many seconds did the robot take to climb?',
                value: _climbTimeSeconds,
                accentColor: Elysium.accent,
                extraDeltas: const [-5, 5],
                onChanged: (v) => setState(() => _climbTimeSeconds = v),
              ),
            ],
            const SizedBox(height: 18),
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: LocaleService.instance.text('Notes about the match'),
                hintText: LocaleService.instance.text(
                  'Add notes about the robot or match...',
                ),
                alignLabelWithHint: true,
              ),
            ),
          ],
        );
    }
  }

  Widget _yesNo(String title, bool value, ValueChanged<bool> onChanged) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return ElysiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final option in [true, false]) ...[
                Expanded(
                  child: ChoiceChip(
                    label: Center(child: Text(option ? 'Yes' : 'No')),
                    selected: value == option,
                    onSelected: (_) => onChanged(option),
                    showCheckmark: false,
                    selectedColor: theme.colorScheme.primary,
                    backgroundColor: dark
                        ? const Color(0xFF243A56)
                        : Elysium.surface2,
                    side: BorderSide(
                      color: value == option
                          ? theme.colorScheme.primary
                          : dark
                              ? const Color(0xFF526783)
                              : Elysium.border,
                    ),
                    labelStyle: TextStyle(
                      color: value == option
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (option) const SizedBox(width: 10),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _scaleSlider(
    String title,
    int value,
    int max,
    List<String> descriptions,
    ValueChanged<int> onChanged,
    {int min = 1},
  ) {
    assert(descriptions.length == max - min + 1);
    final index = (value.clamp(min, max) - min).toInt();
    final description = descriptions[index];
    return ElysiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Elysium.primary.fade(0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$value / $max',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Elysium.primary,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: value.toDouble().clamp(min, max).toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            label: descriptions[index],
            onChanged: (v) => onChanged(v.round()),
          ),
          Text(
            LocaleService.instance.text(description),
            style: const TextStyle(
              color: Elysium.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
