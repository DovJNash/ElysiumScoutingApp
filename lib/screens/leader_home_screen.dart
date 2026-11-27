import 'package:flutter/material.dart' hide Text;

import 'dart:async';
import 'dart:math';

import '../models/scouting_entry.dart';
import '../models/super_scouting_entry.dart';
import '../models/team_model.dart';
import '../services/analytics_service.dart';
import '../services/auth_service.dart';
import '../services/data_repository.dart';
import '../services/sync_service.dart';
import '../theme/elysium_theme.dart';
import '../widgets/analytics_dashboard.dart';
import '../widgets/entry_detail_dialog.dart';
import '../widgets/sync_status_badge.dart';
import '../services/locale_service.dart';
import '../widgets/match_schedule_page.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pit_scouting_entry.dart';
import '../services/pit_scouting_service.dart';
import '../widgets/team_picker.dart';
import '../widgets/create_competition_page.dart';
import '../widgets/super_scouting_page.dart';

import 'package:uuid/uuid.dart';

import '../widgets/localized_text.dart';
import '../widgets/profile_page.dart';
import '../widgets/leader_operations_page.dart';

class LeaderHomeScreen extends StatefulWidget {
  const LeaderHomeScreen({super.key});

  @override
  State<LeaderHomeScreen> createState() => _LeaderHomeScreenState();
}

class _LeaderHomeScreenState extends State<LeaderHomeScreen> {
  List<CompetitionInfo> _competitions = [];
  CompetitionInfo? _comp;
  int _year = 2027;
  bool _loadingCompetitions = true;

  @override
  void initState() {
    super.initState();
    _loadCompetitions();
  }

  Future<void> _loadCompetitions() async {
    setState(() => _loadingCompetitions = true);
    final competitions = await CompetitionRepository.loadCompetitions(
      year: _year,
    );
    if (!mounted) return;
    setState(() {
      _competitions = competitions;
      _comp = competitions.isNotEmpty ? competitions.first : null;
      _loadingCompetitions = false;
    });
  }

  bool _isOfflineError(Object error) {
    if (error is TimeoutException) return true;
    final message = error.toString();
    return message.contains('SocketException') ||
        message.contains('ClientException') ||
        message.contains('HandshakeException') ||
        message.contains('Failed host lookup') ||
        message.contains('XMLHttpRequest') ||
        message.contains('Network is unreachable');
  }

  Future<void> _createCompetition(BuildContext context) async {
    final result = await Navigator.of(context).push<NewCompetition>(
      MaterialPageRoute(
        builder: (_) => CreateCompetitionPage(
          existingIds: _competitions.map((c) => c.id).toSet(),
        ),
      ),
    );
    if (result == null || !mounted || !context.mounted) return;
    final competition = CompetitionInfo(
      id: result.id,
      name: result.name,
      teams: result.teams,
    );

    String? notice;
    try {
      final password = await AuthService.instance.currentPassword();
      if (password == null) {
        throw StateError('The current Leader credentials are unavailable.');
      }
      await CompetitionRepository.createCompetition(
        requesterId: AuthService.instance.currentUser!.id,
        requesterPassword: password,
        competition: competition,
      );
    } on StateError catch (error) {
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
      return;
    } on PostgrestException catch (error) {
      // The database refused it (e.g. the ID is taken): do not create it.
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not create the competition: ${error.message}'),
        ),
      );
      return;
    } catch (error) {
      if (!_isOfflineError(error)) {
        if (!mounted || !context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not create the competition: '
              '${error.toString().replaceFirst('Exception: ', '')}',
            ),
          ),
        );
        return;
      }
      CompetitionRepository.addCompetition(competition);
      notice = 'No connection: the competition exists only on this device '
          'until it is created again while online.';
    }
    if (!mounted || !context.mounted) return;
    setState(() {
      _competitions = [..._competitions, competition];
      _comp = competition;
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(notice ?? 'Competition created')));
  }

  @override
  Widget build(BuildContext context) {
    final leader = AuthService.instance.currentUser!;
    return DefaultTabController(
      length: 7,
      child: Builder(
        builder: (context) {
          final tabs = DefaultTabController.of(context);
          return AnimatedBuilder(
            animation: tabs,
            builder: (context, _) => PopScope(
              canPop: tabs.index == 0,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop) tabs.animateTo(0);
              },
              child: Scaffold(
                appBar: AppBar(
                  title: ElysiumAppBarTitle('Lead • ${leader.name}'),
                  actions: [
                    const SyncStatusBadge(),
                    IconButton(
                      tooltip: 'Leader tools',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LeaderOperationsPage(),
                        ),
                      ),
                      icon: const Icon(Icons.admin_panel_settings_rounded),
                    ),
                    IconButton(
                      tooltip: LocaleService.instance.text(
                        'Create competition',
                      ),
                      onPressed: () => _createCompetition(context),
                      icon: const Icon(Icons.add_business_rounded),
                    ),
                    IconButton(
                      tooltip: 'Account',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ProfilePage()),
                      ),
                      icon: const Icon(Icons.account_circle_rounded),
                    ),
                    IconButton(
                      tooltip: 'Match schedule',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            appBar: AppBar(
                              title: const Text('Match Schedule'),
                            ),
                            body: const MatchSchedulePage(),
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.calendar_month_rounded),
                    ),
                  ],
                  bottom: const TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    tabs: [
                      Tab(
                        icon: Icon(Icons.leaderboard_rounded),
                        child: Text('Rankings'),
                      ),
                      Tab(
                        icon: Icon(Icons.folder_open_rounded),
                        child: Text('Forms'),
                      ),
                      Tab(
                        icon: Icon(Icons.bar_chart_rounded),
                        child: Text('Data'),
                      ),
                      Tab(
                        icon: Icon(Icons.emoji_events_rounded),
                        child: Text('Overall'),
                      ),
                      Tab(
                        icon: Icon(Icons.calendar_month_rounded),
                        child: Text('Schedule'),
                      ),
                      Tab(
                        icon: Icon(Icons.assignment_ind_rounded),
                        child: Text('Super Scouting'),
                      ),
                      Tab(
                        icon: Icon(Icons.handyman_rounded),
                        child: Text('Pit'),
                      ),
                    ],
                  ),
                ),
                body: _comp == null
                    ? _loadingCompetitions
                        ? const Center(child: CircularProgressIndicator())
                        : const Center(
                            child: Text('No competitions available.'),
                          )
                    : Column(
                        children: [
                          Container(
                            decoration: const BoxDecoration(
                              color: Elysium.surface,
                              border: Border(
                                bottom: BorderSide(color: Elysium.border),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                DropdownButton<int>(
                                  value: _year,
                                  items: const [2026, 2027]
                                      .map(
                                        (year) => DropdownMenuItem(
                                          value: year,
                                          child: Text('$year'),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (year) {
                                    if (year == null) return;
                                    setState(() => _year = year);
                                    _loadCompetitions();
                                  },
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.emoji_events_outlined,
                                  color: Elysium.primary,
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Event',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButton<CompetitionInfo>(
                                    value: _comp,
                                    isExpanded: true,
                                    dropdownColor: Elysium.surface2,
                                    underline: const SizedBox.shrink(),
                                    items: _competitions
                                        .map(
                                          (c) => DropdownMenuItem(
                                            value: c,
                                            child: Text(c.name),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) {
                                      if (v != null) setState(() => _comp = v);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _RankingsTab(competition: _comp!),
                                _FormsTab(competition: _comp!),
                                AnalyticsDashboard(fixedCompetition: _comp),
                                const _OverallRankingsTab(),
                                const MatchSchedulePage(),
                                SuperScoutingPage(competition: _comp!),
                                _LeaderPitTab(competition: _comp!),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------- Rankings
class _RankingsTab extends StatelessWidget {
  final CompetitionInfo competition;
  const _RankingsTab({required this.competition});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DataRepository.instance,
      builder: (context, _) {
        final repo = DataRepository.instance;
        final dark = Theme.of(context).brightness == Brightness.dark;
        final board = AnalyticsService.computeScoutLeaderboard(
          competitionId: competition.id,
          scoutingEntries: repo.scouting,
          superEntries: repo.superScouting,
        );

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionTitle(
              'Scout Performance Rankings',
              subtitle: 'Score = Accuracy 55% + Volume 25% + Speed 20%. '
                  'Accuracy compares each form to the median of other scouters for the same match/team '
                  '(or team fallback). Volume is 12.5 points per session, capped at 100. '
                  'Speed is 100 minus 0.25 points per second away from a 120-second target, clamped to 40–100.',
            ),
            const SizedBox(height: 14),
            if (board.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No scouting sessions for this event yet.',
                    style: TextStyle(color: Elysium.muted),
                  ),
                ),
              ),
            ...List.generate(board.length, (i) {
              final s = board[i];
              final top = i == 0;
              final acc = s.accuracyPercent == null
                  ? 'not verifiable yet'
                  : '${s.accuracyPercent!.toStringAsFixed(1)}%';
              return ElysiumCard(
                margin: const EdgeInsets.only(bottom: 10),
                color: top
                    ? Elysium.primary.fade(0.08)
                    : dark
                        ? const Color(0xFF14243B)
                        : Elysium.surface,
                borderColor: top
                    ? Elysium.primary
                    : dark
                        ? const Color(0xFF354B68)
                        : Elysium.border,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: top
                          ? Elysium.primary
                          : dark
                              ? const Color(0xFF243A56)
                              : Elysium.surface2,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: top
                              ? Colors.white
                              : dark
                                  ? const Color(0xFFE7EFFB)
                                  : Elysium.navy,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.scouterName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sessions ${s.sessionCount} • Accuracy $acc • Avg ${s.avgDurationSeconds.toStringAsFixed(0)}s'
                            '${s.peerVerifiedMatches > 0 ? ' • ${s.peerVerifiedMatches} cross-checked' : ''}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Elysium.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Elysium.success.fade(0.16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        s.performanceScore.toStringAsFixed(1),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Elysium.success,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _LeaderPitTab extends StatefulWidget {
  final CompetitionInfo competition;
  const _LeaderPitTab({required this.competition});

  @override
  State<_LeaderPitTab> createState() => _LeaderPitTabState();
}

class _LeaderPitTabState extends State<_LeaderPitTab> {
  TeamInfo? _team;
  final _controllers = <String, TextEditingController>{
    'autonomous': TextEditingController(),
    'strengths': TextEditingController(),
    'difficulties': TextEditingController(),
    'defense': TextEditingController(),
    'notes': TextEditingController(),
  };
  bool _submitting = false;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || _team == null) return;
    setState(() => _submitting = true);
    final user = AuthService.instance.currentUser!;
    final entry = PitScoutingEntry(
      id: const Uuid().v4(),
      uniqueKey: PitScoutingEntry.buildUniqueKey(
        competition: widget.competition.id,
        teamNum: _team!.number,
        scouterId: user.id,
      ),
      competition: widget.competition.id,
      scouterId: user.id,
      scouterName: user.name,
      teamNum: _team!.number,
      autonomousTypes: _controllers['autonomous']!.text.trim(),
      strengths: _controllers['strengths']!.text.trim(),
      difficulties: _controllers['difficulties']!.text.trim(),
      defense: _controllers['defense']!.text.trim(),
      otherNotes: _controllers['notes']!.text.trim(),
      durationSeconds: 90,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      isSynced: false,
    );
    await PitScoutingService.instance.submit(entry);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _team = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_team == null) {
      return TeamPicker(
        competition: widget.competition,
        accent: Elysium.primary,
        onBack: () {},
        onSelected: (team) => setState(() => _team = team),
      );
    }
    final fields = [
      ('autonomous', 'Autonomous types'),
      ('strengths', 'What the team does well'),
      ('difficulties', 'What is difficult for the team'),
      ('defense', 'How the team plays defense'),
      ('notes', 'How is the team different'),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            TextButton.icon(
              onPressed: () => setState(() => _team = null),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Choose another team'),
            ),
            Expanded(
              child: Text(
                'Pit Scouting • Team ${_team!.number}',
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        ...fields.map(
          (field) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: TextField(
              controller: _controllers[field.$1],
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: LocaleService.instance.text(field.$2),
                alignLabelWithHint: true,
              ),
            ),
          ),
        ),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: Text(_submitting ? 'Submitting...' : 'Submit Pit Scouting'),
          ),
        ),
      ],
    );
  }
}

class _OverallRankingsTab extends StatefulWidget {
  const _OverallRankingsTab();

  @override
  State<_OverallRankingsTab> createState() => _OverallRankingsTabState();
}

class _OverallRankingsTabState extends State<_OverallRankingsTab> {
  List<CompetitionInfo> _competitions = [];

  @override
  void initState() {
    super.initState();
    CompetitionRepository.loadCompetitions().then((competitions) {
      if (mounted) setState(() => _competitions = competitions);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DataRepository.instance,
      builder: (context, _) {
        final repo = DataRepository.instance;
        final dark = Theme.of(context).brightness == Brightness.dark;
        final totals = <int, List<TeamStandingSummary>>{};
        for (final competition in _competitions) {
          final standings = AnalyticsService.computeTeamStandings(
            competition: competition,
            scoutingEntries: repo.scouting,
            superEntries: repo.superScouting,
          );
          for (final standing in standings.where(
            (item) => item.matchesScouted > 0,
          )) {
            totals.putIfAbsent(standing.teamNum, () => []).add(standing);
          }
        }
        final overall = totals.entries.map((entry) {
          final rows = entry.value;
          final rating =
              rows.map((row) => row.compositeRating).reduce((a, b) => a + b) /
                  rows.length;
          final matches = rows
              .map((row) => row.matchesScouted)
              .fold<int>(0, (a, b) => a + b);
          final name = rows.last.teamName;
          final logo = rows.last.logoUrl;
          return (entry.key, name, logo, rating, matches);
        }).toList()
          ..sort((a, b) => b.$4.compareTo(a.$4));

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionTitle(
              'Overall Team Rankings',
              subtitle:
                  'Average composite rating across every competition with this team scouted.',
            ),
            const SizedBox(height: 14),
            if (overall.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No cross-competition team data yet.',
                    style: TextStyle(color: Elysium.muted),
                  ),
                ),
              ),
            ...List.generate(overall.length, (index) {
              final row = overall[index];
              return ElysiumCard(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: index == 0
                        ? Elysium.primary
                        : dark
                            ? const Color(0xFF243A56)
                            : Elysium.surface2,
                    foregroundColor: index == 0
                        ? Colors.white
                        : dark
                            ? const Color(0xFFE7EFFB)
                            : Elysium.navy,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  title: Text(
                    '${row.$1} • ${row.$2}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text('${row.$5} matches across competitions'),
                  trailing: Text(
                    row.$4.toStringAsFixed(1),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Elysium.primary,
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

// ------------------------------------------------------------------- Forms
class _Row {
  final DateTime time;
  final ScoutingEntry? scouting;
  final SuperScoutingEntry? superEntry;
  _Row.s(ScoutingEntry e)
      : time = e.createdAtTime,
        scouting = e,
        superEntry = null;
  _Row.sup(SuperScoutingEntry e)
      : time = e.createdAtTime,
        scouting = null,
        superEntry = e;
}

class _FormsTab extends StatelessWidget {
  final CompetitionInfo competition;
  const _FormsTab({required this.competition});

  ({Color color, String label}) _accuracyFor(
    ScoutingEntry entry,
    List<ScoutingEntry> competitionEntries,
  ) {
    final peers = competitionEntries
        .where(
          (item) =>
              item.matchNum == entry.matchNum &&
              item.teamNum == entry.teamNum &&
              item.scouterId != entry.scouterId,
        )
        .toList();
    if (peers.length < 2) {
      return (color: Elysium.muted, label: 'Not enough peer forms');
    }

    double median(List<int> values) {
      final sorted = [...values]..sort();
      final middle = sorted.length ~/ 2;
      return sorted.length.isOdd
          ? sorted[middle].toDouble()
          : (sorted[middle - 1] + sorted[middle]) / 2;
    }

    double normalizedError(int value, double reference, int floor) =>
        ((value - reference).abs() / max(reference.abs(), floor.toDouble()))
            .clamp(0.0, 1.0);

    final error = [
          normalizedError(
            entry.autoShoot,
            median(peers.map((item) => item.autoShoot).toList()),
            10,
          ),
          normalizedError(
            entry.autoIntake,
            median(peers.map((item) => item.autoIntake).toList()),
            10,
          ),
          normalizedError(
            entry.teleopShoot,
            median(peers.map((item) => item.teleopShoot).toList()),
            20,
          ),
          normalizedError(
            entry.teleopIntake,
            median(peers.map((item) => item.teleopIntake).toList()),
            20,
          ),
          normalizedError(
            entry.driverSkill,
            median(peers.map((item) => item.driverSkill).toList()),
            10,
          ),
        ].reduce((a, b) => a + b) /
        5;

    if (error <= 0.35) {
      return (color: Elysium.success, label: 'High form accuracy');
    }
    if (error >= 0.65) {
      return (color: Elysium.danger, label: 'Low form accuracy');
    }
    return (color: Elysium.warning, label: 'Moderate form accuracy');
  }

  @override
  Widget build(BuildContext context) {
    final leader = AuthService.instance.currentUser!;
    return ListenableBuilder(
      listenable: DataRepository.instance,
      builder: (context, _) {
        final repo = DataRepository.instance;
        final rows = <_Row>[
          ...repo.scouting
              .where((e) => e.competition == competition.id)
              .map(_Row.s),
          ...repo.superScouting
              .where((e) => e.competition == competition.id)
              .map(_Row.sup),
        ]..sort((a, b) => b.time.compareTo(a.time));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: SectionTitle(
                'All Submitted Forms (${rows.length})',
                subtitle: 'Tap to inspect. Lead privilege: delete any form.',
              ),
            ),
            Expanded(
              child: rows.isEmpty
                  ? const Center(
                      child: Text(
                        'No forms for this event.',
                        style: TextStyle(color: Elysium.muted),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: rows.length,
                      itemBuilder: (context, i) {
                        final r = rows[i];
                        final s = r.scouting;
                        final u = r.superEntry;
                        final title = s != null
                            ? '[Match ${s.matchNum}] Team ${s.teamNum} — ${s.scouterName}'
                            : '[Super] Team ${u!.teamNum} — ${u.scouterName}';
                        final sub = s != null
                            ? 'Auto scored ${s.autoShoot}; alliance fuels ${s.autoIntake} | Teleop scored ${s.teleopShoot}; alliance fuels ${s.teleopIntake} | ${s.durationSeconds}s'
                            : 'BPS ${u!.bps.isEmpty ? '-' : u.bps} | Miss ${u.missPercent.isEmpty ? '-' : u.missPercent}';
                        final synced = s?.isSynced ?? u!.isSynced;

                        return ElysiumCard(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: s == null
                                ? null
                                : Builder(
                                    builder: (context) {
                                      final status = _accuracyFor(
                                        s,
                                        repo.scouting
                                            .where(
                                              (item) =>
                                                  item.competition ==
                                                  competition.id,
                                            )
                                            .toList(),
                                      );
                                      return Tooltip(
                                        message: status.label,
                                        child: Icon(
                                          status.color == Elysium.success
                                              ? Icons.verified_rounded
                                              : status.color == Elysium.danger
                                                  ? Icons.report_rounded
                                                  : Icons
                                                      .remove_circle_outline_rounded,
                                          color: status.color,
                                        ),
                                      );
                                    },
                                  ),
                            onTap: () => showEntryDetails(
                              context,
                              title: s != null
                                  ? 'Match ${s.matchNum} • Team ${s.teamNum}'
                                  : 'Super Scouting • Team ${u!.teamNum}',
                              rows:
                                  s != null ? s.detailRows() : u!.detailRows(),
                            ),
                            title: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    sub,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (!synced) ...[
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.cloud_off_rounded,
                                    size: 14,
                                    color: Elysium.warning,
                                  ),
                                ],
                              ],
                            ),
                            trailing: IconButton(
                              tooltip: 'Delete form',
                              icon: const Icon(
                                Icons.delete_forever_rounded,
                                color: Elysium.danger,
                              ),
                              onPressed: () async {
                                final ok = await confirmDialog(
                                  context,
                                  title: 'Delete this form?',
                                  message: 'It will be removed for everyone.',
                                );
                                if (!ok) return;
                                if (s != null) {
                                  await SyncService.instance
                                      .deleteScoutingRecord(
                                    entry: s,
                                    requester: leader,
                                  );
                                } else {
                                  await SyncService.instance
                                      .deleteSuperScoutingRecord(
                                    entry: u!,
                                    requester: leader,
                                  );
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
