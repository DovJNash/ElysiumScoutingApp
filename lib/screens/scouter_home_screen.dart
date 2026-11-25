import 'dart:async';
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

class ScouterHomeScreen extends StatefulWidget {
  const ScouterHomeScreen({super.key});

  @override
  State<ScouterHomeScreen> createState() => _ScouterHomeScreenState();
}

class _ScouterHomeScreenState extends State<ScouterHomeScreen> {
  List<CompetitionInfo> _competitions = [];
  CompetitionInfo? _competition;
  TeamInfo? _team;

  int _step = 0;
  DateTime? _startedAt;

  final _matchController = TextEditingController();
  final _notesController = TextEditingController();

  String _startPos = ScoutingFormConfig.startPositions.first;
  String _exitPos = ScoutingFormConfig.exitPaths.first;

  int _autoShoot = 0;
  int _autoIntake = 0;
  int _teleopShoot = 0;
  int _teleopIntake = 0;

  int _allianceCount = 0;
  int _neutralCount = 0;
  int _opponentCount = 0;
  String? _activeZone; // 'alliance' | 'neutral' | 'opponent'
  DateTime? _zoneSince; // when the running zone timer was started
  Timer? _ticker;

  int _doingDefence = 5;
  int _standDefence = 5;
  int _driverSkill = 5;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    CompetitionRepository.loadCompetitions().then((c) {
      if (mounted) setState(() => _competitions = c);
    });
    // Only repaints the running timer. The seconds themselves are measured
    // with timestamps, so they stay correct even if the app is throttled.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _activeZone == null) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
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
    _autoIntake = 0;
    _teleopShoot = 0;
    _teleopIntake = 0;
    _allianceCount = 0;
    _neutralCount = 0;
    _opponentCount = 0;
    _activeZone = null;
    _zoneSince = null;
    _doingDefence = 5;
    _standDefence = 5;
    _driverSkill = 5;
  }

  // ---- zone timers --------------------------------------------------------
  int _zoneBase(String key) => key == 'alliance'
      ? _allianceCount
      : key == 'neutral'
          ? _neutralCount
          : _opponentCount;

  void _setZone(String key, int v) {
    final value = v.clamp(0, 999);
    if (key == 'alliance') _allianceCount = value;
    if (key == 'neutral') _neutralCount = value;
    if (key == 'opponent') _opponentCount = value;
  }

  int _elapsedZoneSeconds() => _zoneSince == null
      ? 0
      : (DateTime.now().difference(_zoneSince!).inMilliseconds / 1000).round();

  /// Seconds to display (saved seconds + the running timer).
  int _liveZone(String key) =>
      _zoneBase(key) + (_activeZone == key ? _elapsedZoneSeconds() : 0);

  /// Stops the running timer and adds its seconds to the zone.
  void _commitZone() {
    final z = _activeZone;
    if (z == null) return;
    _setZone(z, _zoneBase(z) + _elapsedZoneSeconds());
    _activeZone = null;
    _zoneSince = null;
  }

  void _toggleZone(String key) {
    setState(() {
      final wasRunning = _activeZone == key;
      _commitZone();
      if (!wasRunning) {
        _activeZone = key;
        _zoneSince = DateTime.now();
      }
    });
  }

  void _adjustZone(String key, int delta) {
    setState(() {
      final wasRunning = _activeZone == key;
      if (wasRunning) _commitZone();
      _setZone(key, _zoneBase(key) + delta);
      if (wasRunning) {
        _activeZone = key;
        _zoneSince = DateTime.now();
      }
    });
  }

  /// Android back button / swipe: go up one level instead of closing the app.
  void _goBack() {
    setState(() {
      _commitZone();
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

  int? get _matchNum => int.tryParse(_matchController.text.trim());

  void _next() {
    if (_step == 0 && (_matchNum == null || _matchNum! <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid match number first.')),
      );
      return;
    }
    if (_step < ScoutingFormConfig.stepTitles.length - 1) {
      setState(() {
        _commitZone(); // a running zone timer never leaks into the next step
        _step++;
      });
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
    _commitZone();

    final uniqueKey = ScoutingEntry.buildUniqueKey(
      competition: comp.id,
      teamNum: team.number,
      matchNum: matchNum,
      scouterId: user.id,
    );

    final exists =
        DataRepository.instance.scouting.any((e) => e.uniqueKey == uniqueKey);
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
      startPos: _startPos,
      exitPos: _exitPos,
      autoShoot: _autoShoot,
      autoIntake: _autoIntake,
      allianceCount: _allianceCount,
      neutralCount: _neutralCount,
      opponentCount: _opponentCount,
      teleopShoot: _teleopShoot,
      teleopIntake: _teleopIntake,
      doingDefence: _doingDefence,
      standDefence: _standDefence,
      driverSkill: _driverSkill,
      notes: _notesController.text.trim(),
      durationSeconds: duration,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      isSynced: false,
    );

    bool synced = false;
    try {
      synced = await SyncService.instance.submitScouting(entry);
    } catch (_) {
      synced = false;
    }

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _team = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(synced
          ? 'Match $matchNum • Team ${team.number} submitted & synced!'
          : 'Saved on this device. It will upload automatically when internet returns.'),
    ));
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
            const LocaleSwitchButton(),
            IconButton(
              tooltip: 'Match Schedule',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Match Schedule')),
                    body: const MatchSchedulePage(),
                  ),
                ),
              ),
              icon: const Icon(Icons.calendar_month_rounded),
            ),
            const SyncStatusBadge(),
            IconButton(
              tooltip: 'My Submissions',
              onPressed: () => showMySubmissionsSheet(context, superMode: false),
              icon: const Icon(Icons.history_rounded),
            ),
            IconButton(
              tooltip: 'Log Out',
              onPressed: () => AuthService.instance.logout(),
              icon: const Icon(Icons.logout_rounded),
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
    if (_competitions.isEmpty) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionTitle('Select Competition'),
        const SizedBox(height: 14),
        ..._competitions.map(
          (comp) => ElysiumCard(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: Elysium.primary.fade(0.2),
                child: const Icon(Icons.emoji_events_rounded, color: Elysium.primary),
              ),
              title: Text(comp.name,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              subtitle: Text('${comp.teams.length} registered teams'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => setState(() => _competition = comp),
            ),
          ),
        ),
      ],
    );
  }

  Widget _wizard() {
    final team = _team!;
    final last = _step == ScoutingFormConfig.stepTitles.length - 1;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Elysium.surface,
            border: Border(bottom: BorderSide(color: Elysium.border)),
          ),
          child: Column(
            children: [
              Row(children: [
                TeamLogo(team: team, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Team ${team.number} (${team.name})',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                Text(ScoutingFormConfig.stepTitles[_step],
                    style: const TextStyle(
                        color: Elysium.primary, fontWeight: FontWeight.w800)),
              ]),
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
          decoration: const BoxDecoration(
            color: Elysium.surface,
            border: Border(top: BorderSide(color: Elysium.border)),
          ),
          child: SafeArea(
            top: false,
            child: Row(children: [
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
                    icon: Icon(last ? Icons.cloud_upload_rounded : Icons.arrow_forward_rounded),
                    label: Text(last ? (_submitting ? 'Submitting...' : 'Submit') : 'Next',
                        style: const TextStyle(fontSize: 16)),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _chipGroup(List<String> options, String selected, ValueChanged<String> onPick) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options
          .map((o) => ChoiceChip(
                label: Text(o),
                selected: selected == o,
                selectedColor: Elysium.primary,
                backgroundColor: Elysium.surface,
                showCheckmark: false,
                side: BorderSide(color: selected == o ? Elysium.primary : Elysium.border),
                labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected == o ? Colors.white : Elysium.navy),
                onSelected: (_) => onPick(o),
              ))
          .toList(),
    );
  }

  Widget _stepBody() {
    switch (_step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _matchController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: LocaleService.instance.text('Match Number'),
                hintText: LocaleService.instance.text('e.g., 14'),
                prefixIcon: Icon(Icons.tag_rounded),
              ),
            ),
            const SizedBox(height: 22),
            const Text('Starting Position',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            _chipGroup(ScoutingFormConfig.startPositions, _startPos,
                (v) => setState(() => _startPos = v)),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Elysium.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('AUTONOMOUS PERIOD',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: Colors.white)),
            ),
            const SizedBox(height: 16),
            ResponsiveCounterPad(
              label: 'Auto Game Pieces Scored',
              value: _autoShoot,
              accentColor: Elysium.primary,
              onChanged: (v) => setState(() => _autoShoot = v),
            ),
            const SizedBox(height: 14),
            ResponsiveCounterPad(
              label: 'How Many Fuels Passed to Alliance Zone',
              value: _autoIntake,
              accentColor: Elysium.accent,
              onChanged: (v) => setState(() => _autoIntake = v),
            ),
            const SizedBox(height: 22),
            const Text('Exit Path',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            _chipGroup(ScoutingFormConfig.exitPaths, _exitPos,
                (v) => setState(() => _exitPos = v)),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ResponsiveCounterPad(
              label: 'Teleop Game Pieces Scored',
              value: _teleopShoot,
              accentColor: Elysium.primary,
              onChanged: (v) => setState(() => _teleopShoot = v),
            ),
            const SizedBox(height: 14),
            ResponsiveCounterPad(
              label: 'How Many Fuels Passed to Alliance Zone',
              value: _teleopIntake,
              accentColor: Elysium.accent,
              onChanged: (v) => setState(() => _teleopIntake = v),
            ),
            const SizedBox(height: 22),
            const SectionTitle('Zone Time (seconds)',
                subtitle: 'Tap Track to run a timer for the zone the robot is in, or adjust by 5 s.'),
            const SizedBox(height: 10),
            _zoneRow('Alliance Zone', 'alliance', Elysium.primary),
            const SizedBox(height: 10),
            _zoneRow('Neutral Zone', 'neutral', Elysium.accent),
            const SizedBox(height: 10),
            _zoneRow('Opponent Zone', 'opponent', Elysium.danger),
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _slider('Defense Played By This Robot (1–10)', _doingDefence,
                (v) => setState(() => _doingDefence = v)),
            const SizedBox(height: 14),
            _slider('Resilience Against Defense (1–10)', _standDefence,
                (v) => setState(() => _standDefence = v)),
            const SizedBox(height: 14),
            _slider('Driver Skill (1–10)', _driverSkill,
                (v) => setState(() => _driverSkill = v)),
            const SizedBox(height: 18),
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: LocaleService.instance.text('General Notes'),
                hintText: LocaleService.instance
                    .text('Mechanical issues, penalties, endgame, cycle notes...'),
                alignLabelWithHint: true,
              ),
            ),
          ],
        );
    }
  }

  Widget _zoneRow(String label, String key, Color color) {
    final running = _activeZone == key;
    final seconds = _liveZone(key);
    return ElysiumCard(
      borderColor: running ? color : Elysium.border,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            Text('${seconds}s',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            IconButton(
              tooltip: '-5 s',
              onPressed: () => _adjustZone(key, -5),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            IconButton(
              tooltip: '+5 s',
              onPressed: () => _adjustZone(key, 5),
              icon: const Icon(Icons.add_circle_outline),
            ),
            const Spacer(),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: running ? color : Elysium.surface2,
                foregroundColor: running ? Elysium.onColor(color) : Elysium.navy,
              ),
              onPressed: () => _toggleZone(key),
              icon: Icon(running ? Icons.pause_rounded : Icons.play_arrow_rounded),
              label: Text(running ? 'Running' : 'Track'),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _slider(String title, int value, ValueChanged<int> onChanged) {
    return ElysiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Elysium.primary.fade(0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$value / 10',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, color: Elysium.primary)),
            ),
          ]),
          Slider(
            value: value.toDouble(),
            min: ScoutingFormConfig.minRating.toDouble(),
            max: ScoutingFormConfig.maxRating.toDouble(),
            divisions: 9,
            label: '$value',
            onChanged: (v) => onChanged(v.round()),
          ),
        ],
      ),
    );
  }
}
