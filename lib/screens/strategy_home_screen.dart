import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/scouting_form_config.dart';
import '../models/super_scouting_entry.dart';
import '../models/team_model.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../theme/elysium_theme.dart';
import '../services/data_repository.dart';
import '../widgets/analytics_dashboard.dart';
import '../widgets/entry_detail_dialog.dart';
import '../widgets/my_submissions_sheet.dart';
import '../widgets/sync_status_badge.dart';
import '../widgets/team_picker.dart';

class StrategyHomeScreen extends StatefulWidget {
  const StrategyHomeScreen({super.key});

  @override
  State<StrategyHomeScreen> createState() => _StrategyHomeScreenState();
}

class _StrategyHomeScreenState extends State<StrategyHomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<CompetitionInfo> _competitions = [];

  CompetitionInfo? _comp;
  TeamInfo? _team;
  DateTime? _startedAt;
  bool _submitting = false;

  final Map<String, TextEditingController> _c = {
    for (final f in SuperScoutingFormConfig.fields) f.key: TextEditingController()
  };

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (!_tabs.indexIsChanging) setState(() {});
      });
    CompetitionRepository.loadCompetitions().then((c) {
      if (mounted) setState(() => _competitions = c);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _canPopApp => !(_tabs.index == 0 && _comp != null);

  void _goBack() {
    setState(() {
      if (_team != null) {
        _team = null;
      } else if (_comp != null) {
        _comp = null;
      }
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final user = AuthService.instance.currentUser!;
    final comp = _comp!;
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

    for (final c in _c.values) {
      c.clear();
    }
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
    final user = AuthService.instance.currentUser!;
    return PopScope(
      canPop: _canPopApp,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: ElysiumAppBarTitle('Strategy • ${user.name}'),
          actions: [
            const SyncStatusBadge(),
            IconButton(
              tooltip: 'My Reports',
              onPressed: () => showMySubmissionsSheet(context, superMode: true),
              icon: const Icon(Icons.history_rounded),
            ),
            IconButton(
              tooltip: 'Log Out',
              onPressed: () => AuthService.instance.logout(),
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
          bottom: TabBar(
            controller: _tabs,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(icon: Icon(Icons.assignment_ind_rounded), text: 'Super Scouting'),
              Tab(icon: Icon(Icons.bar_chart_rounded), text: 'Data'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabs,
          children: [_superTab(), const AnalyticsDashboard()],
        ),
      ),
    );
  }

  Widget _superTab() {
    if (_competitions.isEmpty) return const Center(child: CircularProgressIndicator());

    if (_comp == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionTitle('Select Competition for Super Scouting'),
          const SizedBox(height: 14),
          ..._competitions.map((comp) => ElysiumCard(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(comp.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${comp.teams.length} teams'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => setState(() => _comp = comp),
                ),
              )),
        ],
      );
    }

    if (_team == null) {
      return TeamPicker(
        competition: _comp!,
        accent: Elysium.primary,
        onBack: () => setState(() => _comp = null),
        onSelected: (t) => setState(() {
          for (final c in _c.values) {
            c.clear(); // never carry the previous team's text over
          }
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
              onPressed: _goBack,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back'),
            ),
            TeamLogo(team: team, size: 32),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${team.number} (${team.name})',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
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
                        labelText: f.label,
                        hintText: f.hint,
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
                  label: Text(_submitting ? 'Submitting...' : 'Submit Super Scouting',
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
