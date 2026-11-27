import 'package:flutter/material.dart' hide Text;
import 'package:uuid/uuid.dart';

import '../models/scouting_form_config.dart';
import '../models/super_scouting_entry.dart';
import '../models/team_model.dart';
import '../services/auth_service.dart';
import '../services/data_repository.dart';
import '../services/locale_service.dart';
import '../services/sync_service.dart';
import '../theme/elysium_theme.dart';
import 'entry_detail_dialog.dart';
import 'field_diagram_picker.dart';
import 'localized_text.dart';
import 'responsive_counter_pad.dart';
import 'team_picker.dart';

/// Super Scouting form (team picker -> text form -> submit) for one fixed
/// competition. Used as a tab by the Leader, the same form the Strategy role
/// fills in on its own "Super Scouting" tab.
class SuperScoutingPage extends StatefulWidget {
  final CompetitionInfo competition;
  const SuperScoutingPage({super.key, required this.competition});

  @override
  State<SuperScoutingPage> createState() => _SuperScoutingPageState();
}

class _SuperScoutingPageState extends State<SuperScoutingPage>
    with AutomaticKeepAliveClientMixin {
  TeamInfo? _team;
  DateTime? _startedAt;
  bool _submitting = false;
  int _autoShotBand = 0;
  int _autoDeliveredBand = 0;
  int _intakeSpeed = 5;
  bool _canShootWhileMoving = false;
  bool _canClimb = false;
  String _autoExitPath = 'None';
  String _climbLevel = 'L1';
  int _climbTimeSeconds = 0;

  final Map<String, TextEditingController> _c = {
    for (final f in SuperScoutingFormConfig.fields)
      f.key: TextEditingController(),
  };

  // Keeps what has been typed when the user switches to another tab.
  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(covariant SuperScoutingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.competition.id != widget.competition.id) {
      // Another event was chosen: never carry the old team / text over.
      _clearForm();
      _team = null;
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _clearForm() {
    for (final c in _c.values) {
      c.clear();
    }
    _autoShotBand = 0;
    _autoDeliveredBand = 0;
    _intakeSpeed = 5;
    _canShootWhileMoving = false;
    _canClimb = false;
    _autoExitPath = 'None';
    _climbLevel = 'L1';
    _climbTimeSeconds = 0;
  }

  Future<void> _submit() async {
    if (_submitting || _team == null) return;
    final user = AuthService.instance.currentUser!;
    final comp = widget.competition;
    final team = _team!;

    final uniqueKey = SuperScoutingEntry.buildUniqueKey(
      competition: comp.id,
      teamNum: team.number,
      scouterId: user.id,
    );
    final exists = DataRepository.instance.superScouting.any(
      (e) => e.uniqueKey == uniqueKey,
    );
    if (exists) {
      final overwrite = await confirmDialog(
        context,
        title: 'Report already exists',
        message:
            'You already wrote a Super Scouting report for Team ${team.number} at this event. Replace it?',
        confirmLabel: 'Replace',
      );
      if (!overwrite) return;
    }
    setState(() => _submitting = true);

    final duration = _startedAt == null
        ? 90
        : DateTime.now().difference(_startedAt!).inSeconds.clamp(5, 3600);
    String t(String k) => _c[k]!.text.trim();
    final autoNotes = [
      t('auto'),
      'Fuel shot range: ${ScoutingFormConfig.fuelDescription(_autoShotBand)}',
      'Fuel delivered range: ${ScoutingFormConfig.fuelDescription(_autoDeliveredBand)}',
    ].where((note) => note.isNotEmpty).join('\n');
    final movingNotes = t('shootingWhileMoving');
    final climbNotes = t('climbCapability');

    final entry = SuperScoutingEntry(
      id: const Uuid().v4(),
      uniqueKey: uniqueKey,
      competition: comp.id,
      scouterId: user.id,
      scouterName: user.name,
      teamNum: team.number,
      auto: autoNotes,
      autoExitPath: _autoExitPath,
      bps: t('bps'),
      shootingLimits: t('shootingLimits'),
      missPercent: t('missPercent'),
      intakeSpeed:
          '${_intakeSpeed}/10: ${ScoutingFormConfig.speedDescriptions[_intakeSpeed - 1]}'
          '${t('intakeSpeed').isEmpty ? '' : '\n${t('intakeSpeed')}'}',
      robotCap: t('RobotCap'),
      robotLimits: t('robotLimits'),
      driverSkills: t('driverSkills'),
      penalties: t('penalties'),
      bumpSpeed: t('bumpSpeed'),
      driverTechnique: t('DriverTechnique'),
      defenceStyle: t('defenceStyle'),
      shootingWhileMoving:
          'Can shoot while moving: ${_canShootWhileMoving ? 'Yes' : 'No'}'
          '${movingNotes.isEmpty ? '' : '\n$movingNotes'}',
      climbCapability: _canClimb
          ? 'Yes, $_climbLevel; climb time: ${_climbTimeSeconds}s'
              '${climbNotes.isEmpty ? '' : '\n$climbNotes'}'
          : 'No${climbNotes.isEmpty ? '' : '\n$climbNotes'}',
      durationSeconds: duration,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      isSynced: false,
    );

    bool synced = false;
    try {
      synced = await SyncService.instance.submitSuperScouting(entry);
    } catch (_) {}

    _clearForm();
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _team = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          synced
              ? 'Super Scouting for Team ${team.number} saved & synced!'
              : 'Saved on this device. It will upload when internet returns.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    final theme = Theme.of(context);
    if (_team == null) {
      return TeamPicker(
        competition: widget.competition,
        accent: Elysium.primary,
        onBack: () {},
        onSelected: (t) => setState(() {
          _clearForm(); // never carry the previous team's text over
          _team = t;
          _startedAt = DateTime.now();
        }),
      );
    }

    final team = _team!;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _team = null),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Back'),
              ),
              TeamLogo(team: team, size: 32),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${team.number} (${team.name})',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ...SuperScoutingFormConfig.fields.map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _field(f),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: const Icon(Icons.cloud_upload_rounded),
                  label: Text(
                    _submitting ? 'Submitting...' : 'Submit Super Scouting',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _field(SuperScoutingFieldSchema field) {
    switch (field.key) {
      case 'auto':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _notesField(field),
            const SizedBox(height: 12),
            _fuelSlider(
              'Autonomous fuels shot (range)',
              _autoShotBand,
              (value) => setState(() => _autoShotBand = value),
            ),
            const SizedBox(height: 12),
            _fuelSlider(
              'Autonomous fuels delivered (range)',
              _autoDeliveredBand,
              (value) => setState(() => _autoDeliveredBand = value),
            ),
          ],
        );
      case 'autoExitPath':
        return FieldDiagramPicker(
          title: field.label,
          value: _autoExitPath,
          options: ScoutingFormConfig.exitPaths,
          pathMode: true,
          onChanged: (value) => setState(() => _autoExitPath = value),
        );
      case 'intakeSpeed':
        return _ratingSlider(
          'How fast was the intake?',
          _intakeSpeed,
          ScoutingFormConfig.speedDescriptions,
          (value) => setState(() => _intakeSpeed = value),
          min: 1,
          controllerField: field,
        );
      case 'shootingWhileMoving':
        return Column(
          children: [
            _yesNo(
              'Can the robot shoot while moving?',
              _canShootWhileMoving,
              (value) => setState(() => _canShootWhileMoving = value),
            ),
            const SizedBox(height: 8),
            _notesField(field),
          ],
        );
      case 'climbCapability':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _yesNo(
              'Did the robot climb?',
              _canClimb,
              (value) => setState(() => _canClimb = value),
            ),
            if (_canClimb) ...[
              const SizedBox(height: 8),
              const Text('Climb level',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              _chipGroup(
                const ['L1', 'L2', 'L3'],
                _climbLevel,
                (value) => setState(() => _climbLevel = value),
              ),
              const SizedBox(height: 8),
              ResponsiveCounterPad(
                label: 'Climb time (seconds)',
                value: _climbTimeSeconds,
                accentColor: Elysium.accent,
                extraDeltas: const [-5, 5],
                onChanged: (value) => setState(() => _climbTimeSeconds = value),
              ),
            ],
            const SizedBox(height: 8),
            _notesField(field),
          ],
        );
      default:
        return _notesField(field);
    }
  }

  Widget _notesField(SuperScoutingFieldSchema field) => TextField(
        controller: _c[field.key],
        maxLines: field.maxLines,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: LocaleService.instance.text(field.label),
          hintText: LocaleService.instance.text(field.hint),
          alignLabelWithHint: true,
        ),
      );

  Widget _fuelSlider(
    String label,
    int value,
    ValueChanged<int> onChanged,
  ) {
    final description = ScoutingFormConfig.fuelDescription(value);
    return ElysiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '$value / 10',
                style: const TextStyle(
                  color: Elysium.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Slider(
            value: value.toDouble(),
            min: 0,
            max: 10,
            divisions: 10,
            label: '$value',
            onChanged: (next) => onChanged(next.round()),
          ),
          Text(
            LocaleService.instance.text(description),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
        ],
      ),
    );
  }

  Widget _ratingSlider(
    String label,
    int value,
    List<String> descriptions,
    ValueChanged<int> onChanged, {
    int min = 0,
    required SuperScoutingFieldSchema controllerField,
  }) {
    final description = descriptions[value - min];
    return Column(
      children: [
        ElysiumCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
              Slider(
                value: value.toDouble(),
                min: min.toDouble(),
                max: (min + descriptions.length - 1).toDouble(),
                divisions: descriptions.length - 1,
                label: '$value',
                onChanged: (next) => onChanged(next.round()),
              ),
              Text(LocaleService.instance.text(description)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _notesField(controllerField),
      ],
    );
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
          const SizedBox(height: 8),
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
                    labelStyle: TextStyle(
                      color: value == option
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                if (option) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _chipGroup(
    List<String> options,
    String selected,
    ValueChanged<String> onPick,
  ) =>
      Wrap(
        spacing: 8,
        children: options
            .map(
              (option) => ChoiceChip(
                label: Text(option),
                selected: selected == option,
                onSelected: (_) => onPick(option),
                showCheckmark: false,
                selectedColor: Theme.of(context).colorScheme.primary,
                labelStyle: TextStyle(
                  color: selected == option
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            )
            .toList(),
      );
}
