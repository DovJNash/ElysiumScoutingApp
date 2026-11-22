import 'package:flutter/material.dart';
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

class LeaderHomeScreen extends StatefulWidget {
  const LeaderHomeScreen({super.key});

  @override
  State<LeaderHomeScreen> createState() => _LeaderHomeScreenState();
}

class _LeaderHomeScreenState extends State<LeaderHomeScreen> {
  List<CompetitionInfo> _competitions = [];
  CompetitionInfo? _comp;

  @override
  void initState() {
    super.initState();
    CompetitionRepository.loadCompetitions().then((c) {
      if (mounted) {
        setState(() {
          _competitions = c;
          _comp = c.isNotEmpty ? c.first : null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final leader = AuthService.instance.currentUser!;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: ElysiumAppBarTitle('Lead • ${leader.name}'),
          actions: [
            const SyncStatusBadge(),
            IconButton(
              tooltip: 'Log Out',
              onPressed: () => AuthService.instance.logout(),
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.leaderboard_rounded), text: 'Rankings'),
              Tab(icon: Icon(Icons.folder_open_rounded), text: 'Forms'),
              Tab(icon: Icon(Icons.bar_chart_rounded), text: 'Data'),
            ],
          ),
        ),
        body: _comp == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Elysium.surface,
                      border: Border(bottom: BorderSide(color: Elysium.border)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(children: [
                      const Icon(Icons.emoji_events_outlined, color: Elysium.primary),
                      const SizedBox(width: 10),
                      const Text('Event', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButton<CompetitionInfo>(
                          value: _comp,
                          isExpanded: true,
                          dropdownColor: Elysium.surface2,
                          underline: const SizedBox.shrink(),
                          items: _competitions
                              .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _comp = v);
                          },
                        ),
                      ),
                    ]),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _RankingsTab(competition: _comp!),
                        _FormsTab(competition: _comp!),
                        AnalyticsDashboard(fixedCompetition: _comp),
                      ],
                    ),
                  ),
                ],
              ),
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
              subtitle:
                  'Accuracy vs. other scouters (55%) • Sessions (25%) • Form speed (20%)',
            ),
            const SizedBox(height: 14),
            if (board.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text('No scouting sessions for this event yet.',
                      style: TextStyle(color: Elysium.muted)),
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
                color: top ? Elysium.primary.fade(0.08) : Elysium.surface,
                borderColor: top ? Elysium.primary : Elysium.border,
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  CircleAvatar(
                    backgroundColor: top ? Elysium.primary : Elysium.surface2,
                    child: Text('${i + 1}',
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: top ? Colors.white : Elysium.navy)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.scouterName,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(
                          'Sessions ${s.sessionCount} • Accuracy $acc • Avg ${s.avgDurationSeconds.toStringAsFixed(0)}s'
                          '${s.peerVerifiedMatches > 0 ? ' • ${s.peerVerifiedMatches} cross-checked' : ''}',
                          style: const TextStyle(fontSize: 12, color: Elysium.muted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Elysium.success.fade(0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(s.performanceScore.toStringAsFixed(1),
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, color: Elysium.success)),
                  ),
                ]),
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

  @override
  Widget build(BuildContext context) {
    final leader = AuthService.instance.currentUser!;
    return ListenableBuilder(
      listenable: DataRepository.instance,
      builder: (context, _) {
        final repo = DataRepository.instance;
        final rows = <_Row>[
          ...repo.scouting.where((e) => e.competition == competition.id).map(_Row.s),
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
                      child: Text('No forms for this event.',
                          style: TextStyle(color: Elysium.muted)))
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
                            ? 'Auto ${s.autoShoot}/${s.autoIntake} | Teleop ${s.teleopShoot}/${s.teleopIntake} | ${s.durationSeconds}s'
                            : 'BPS ${u!.bps.isEmpty ? '-' : u.bps} | Miss ${u.missPercent.isEmpty ? '-' : u.missPercent}';
                        final synced = s?.isSynced ?? u!.isSynced;

                        return ElysiumCard(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            onTap: () => showEntryDetails(
                              context,
                              title: s != null
                                  ? 'Match ${s.matchNum} • Team ${s.teamNum}'
                                  : 'Super Scouting • Team ${u!.teamNum}',
                              rows: s != null ? s.detailRows() : u!.detailRows(),
                            ),
                            title: Text(title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 14)),
                            subtitle: Row(children: [
                              Flexible(child: Text(sub, overflow: TextOverflow.ellipsis)),
                              if (!synced) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.cloud_off_rounded,
                                    size: 14, color: Elysium.warning),
                              ],
                            ]),
                            trailing: IconButton(
                              tooltip: 'Delete form',
                              icon: const Icon(Icons.delete_forever_rounded,
                                  color: Elysium.danger),
                              onPressed: () async {
                                final ok = await confirmDialog(
                                  context,
                                  title: 'Delete this form?',
                                  message: 'It will be removed for everyone.',
                                );
                                if (!ok) return;
                                if (s != null) {
                                  await SyncService.instance
                                      .deleteScoutingRecord(entry: s, requester: leader);
                                } else {
                                  await SyncService.instance
                                      .deleteSuperScoutingRecord(entry: u!, requester: leader);
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
