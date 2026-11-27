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
import 'localized_text.dart';
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

  final Map<String, TextEditingController> _c = {
    for (final f in SuperScoutingFormConfig.fields)
      f.key: TextEditingController()
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
  }

  Future<void> _submit() async {
    if (_submitting || _team == null) return;
    final user = AuthService.instance.currentUser!;
    final comp = widget.competition;
    final team = _team!;

    final uniqueKey = SuperScoutingEntry.buildUniqueKey(
        competition: comp.id, teamNum: team.number, scouterId: user.id);
    final exists = DataRepository.instance.superScouting
        .any((e) => e.uniqueKey == uniqueKey);
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

    final entry = SuperScoutingEntry(
      id: const Uuid().v4(),
      uniqueKey: uniqueKey,
      competition: comp.id,
      scouterId: user.id,
      scouterName: user.name,
      teamNum: team.number,
      auto: t('auto'),
      bps: t('bps'),
      shootingLimits: t('shootingLimits'),
      missPercent: t('missPercent'),
      intakeSpeed: t('intakeSpeed'),
      robotCap: t('RobotCap'),
      robotLimits: t('robotLimits'),
      driverSkills: t('driverSkills'),
      penalties: t('penalties'),
      bumpSpeed: t('bumpSpeed'),
      driverTechnique: t('DriverTechnique'),
      defenceStyle: t('defenceStyle'),
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(synced
          ? 'Super Scouting for Team ${team.number} saved & synced!'
          : 'Saved on this device. It will upload when internet returns.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
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
          decoration: const BoxDecoration(
            color: Elysium.surface,
            border: Border(bottom: BorderSide(color: Elysium.border)),
          ),
          child: Row(children: [
            TextButton.icon(
              onPressed: () => setState(() => _team = null),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back'),
            ),
            TeamLogo(team: team, size: 32),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${team.number} (${team.name})',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ]),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ...SuperScoutingFormConfig.fields.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: TextField(
                      controller: _c[f.key],
                      maxLines: f.maxLines,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: LocaleService.instance.text(f.label),
                        hintText: LocaleService.instance.text(f.hint),
                        alignLabelWithHint: true,
                      ),
                    ),
                  )),
              const SizedBox(height: 4),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: const Icon(Icons.cloud_upload_rounded),
                  label: Text(
                      _submitting ? 'Submitting...' : 'Submit Super Scouting',
                      style: const TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}
