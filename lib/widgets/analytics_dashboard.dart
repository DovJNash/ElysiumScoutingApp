import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/team_model.dart';
import '../services/analytics_service.dart';
import '../services/data_repository.dart';
import '../theme/elysium_theme.dart';
import 'entry_detail_dialog.dart';
import 'team_picker.dart';

/// Live analytics used by Strategy (Data tab) and Leader (Data tab).
/// If [fixedCompetition] is given, the dashboard follows it and hides its own
/// competition selector.
class AnalyticsDashboard extends StatefulWidget {
  final CompetitionInfo? fixedCompetition;
  const AnalyticsDashboard({super.key, this.fixedCompetition});

  @override
  State<AnalyticsDashboard> createState() => _AnalyticsDashboardState();
}

class _AnalyticsDashboardState extends State<AnalyticsDashboard> {
  List<CompetitionInfo> _competitions = [];
  CompetitionInfo? _selected;

  @override
  void initState() {
    super.initState();
    CompetitionRepository.loadCompetitions().then((c) {
      if (mounted) {
        setState(() {
          _competitions = c;
          _selected = c.isNotEmpty ? c.first : null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final comp = widget.fixedCompetition ?? _selected;
    if (comp == null) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        if (widget.fixedCompetition == null)
          Container(
            decoration: const BoxDecoration(
              color: Elysium.surface,
              border: Border(bottom: BorderSide(color: Elysium.border)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.filter_list_rounded, color: Elysium.primary),
                const SizedBox(width: 10),
                const Text('Competition', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<CompetitionInfo>(
                    value: _selected,
                    isExpanded: true,
                    dropdownColor: Elysium.surface2,
                    underline: const SizedBox.shrink(),
                    items: _competitions
                        .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selected = v);
                    },
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListenableBuilder(
            listenable: DataRepository.instance,
            builder: (context, _) {
              final repo = DataRepository.instance;
              final standings = AnalyticsService.computeTeamStandings(
                competition: comp,
                scoutingEntries: repo.scouting,
                superEntries: repo.superScouting,
              );
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _chart(standings),
                  const SizedBox(height: 16),
                  _ratingChart(standings),
                  const SizedBox(height: 16),
                  _ranking(standings),
                  const SizedBox(height: 16),
                  _telemetryTable(standings),
                  const SizedBox(height: 16),
                  _zoneTable(standings),
                  const SizedBox(height: 16),
                  _superTable(context, standings),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Text _axisText(String v) => Text(v,
      style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700, color: Elysium.muted));

  FlTitlesData _titles(List<TeamStandingSummary> top) => FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 38,
            getTitlesWidget: (value, meta) => _axisText(meta.formattedValue),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final i = value.toInt();
              if (i < 0 || i >= top.length || value != i.toDouble()) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('${top[i].teamNum}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Elysium.navy)),
              );
            },
          ),
        ),
      );

  FlGridData get _grid => FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (v) =>
            FlLine(color: Elysium.border, strokeWidth: 1),
      );

  Widget _emptyChart() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(
          child: Text('No scouted matches for this competition yet.',
              style: TextStyle(color: Elysium.muted)),
        ),
      );

  Widget _chart(List<TeamStandingSummary> standings) {
    final top = standings.where((t) => t.matchesScouted > 0).take(6).toList();
    final peak = top.fold<double>(
        0, (m, t) => max(m, max(t.avgAutoShoot, t.avgTeleopShoot)));
    return ElysiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Auto vs Teleop Scoring (top teams)'),
          const SizedBox(height: 8),
          Row(children: [
            _legend(Elysium.primary, 'Avg auto scored'),
            const SizedBox(width: 16),
            _legend(Elysium.accent, 'Avg teleop scored'),
          ]),
          const SizedBox(height: 16),
          if (top.isEmpty)
            _emptyChart()
          else
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: peak <= 0 ? 1 : peak * 1.2,
                  gridData: _grid,
                  borderData: FlBorderData(show: false),
                  titlesData: _titles(top),
                  barGroups: List.generate(top.length, (i) {
                    final t = top[i];
                    return BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                          toY: t.avgAutoShoot,
                          color: Elysium.primary,
                          width: 12,
                          borderRadius: BorderRadius.circular(4)),
                      BarChartRodData(
                          toY: t.avgTeleopShoot,
                          color: Elysium.accent,
                          width: 12,
                          borderRadius: BorderRadius.circular(4)),
                    ]);
                  }),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _ratingChart(List<TeamStandingSummary> standings) {
    final top = standings.where((t) => t.matchesScouted > 0).take(10).toList();
    final peak = top.fold<double>(0, (m, t) => max(m, t.compositeRating));
    return ElysiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Overall Rating (top 10)',
              subtitle: 'Scouting + super scouting combined'),
          const SizedBox(height: 16),
          if (top.isEmpty)
            _emptyChart()
          else
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: peak <= 0 ? 1 : peak * 1.15,
                  gridData: _grid,
                  borderData: FlBorderData(show: false),
                  titlesData: _titles(top),
                  barGroups: List.generate(top.length, (i) {
                    return BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                          toY: top[i].compositeRating,
                          color: i == 0 ? Elysium.navy : Elysium.primary,
                          width: 18,
                          borderRadius: BorderRadius.circular(4)),
                    ]);
                  }),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _legend(Color c, String text) => Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 12, color: Elysium.muted)),
      ]);

  Widget _ranking(List<TeamStandingSummary> standings) {
    return ElysiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Overall Team Standing',
              subtitle: 'Weighted index of auto, teleop, driver, defense and super-scouting data'),
          const SizedBox(height: 12),
          ...List.generate(standings.length, (i) {
            final t = standings[i];
            final first = i == 0 && t.compositeRating > 0;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: first ? Elysium.primary : Elysium.surface2,
                child: Text('${i + 1}',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: first ? Colors.white : Elysium.navy)),
              ),
              title: Row(children: [
                TeamLogo(
                    team: TeamInfo(number: t.teamNum, name: t.teamName, logoUrl: t.logoUrl),
                    size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${t.teamNum} — ${t.teamName}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ]),
              subtitle: Text(
                  'Matches ${t.matchesScouted} • Super ${t.superReportsCount} • Driver ${t.avgDriverSkill.toStringAsFixed(1)}/10'),
              trailing: Text('${t.compositeRating.toStringAsFixed(1)} pts',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, color: Elysium.primary)),
            );
          }),
        ],
      ),
    );
  }

  Widget _tableCard(String title, Widget table) => ElysiumCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(title),
            const SizedBox(height: 10),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: table),
          ],
        ),
      );

  Text _b(String s) => Text(s, style: const TextStyle(fontWeight: FontWeight.w900));

  Widget _telemetryTable(List<TeamStandingSummary> s) => _tableCard(
        'Scoring & Intake Telemetry (averages)',
        DataTable(
          headingRowColor: const WidgetStatePropertyAll(Elysium.surface2),
          columnSpacing: 18,
          columns: const [
            DataColumn(label: Text('Team')),
            DataColumn(label: Text('Matches')),
            DataColumn(label: Text('Auto Shot')),
            DataColumn(label: Text('Auto Int.')),
            DataColumn(label: Text('Tele Shot')),
            DataColumn(label: Text('Tele Int.')),
            DataColumn(label: Text('Est BPS')),
            DataColumn(label: Text('Miss %')),
          ],
          rows: s
              .map((t) => DataRow(cells: [
                    DataCell(_b('${t.teamNum}')),
                    DataCell(Text('${t.matchesScouted}')),
                    DataCell(Text(t.avgAutoShoot.toStringAsFixed(1))),
                    DataCell(Text(t.avgAutoIntake.toStringAsFixed(1))),
                    DataCell(Text(t.avgTeleopShoot.toStringAsFixed(1))),
                    DataCell(Text(t.avgTeleopIntake.toStringAsFixed(1))),
                    DataCell(Text(t.estimatedBps.toStringAsFixed(1))),
                    DataCell(Text('${t.estimatedMissPercent.toStringAsFixed(0)}%')),
                  ]))
              .toList(),
        ),
      );

  Widget _zoneTable(List<TeamStandingSummary> s) => _tableCard(
        'Zone Control (seconds) & Defense / Driver Ratings',
        DataTable(
          headingRowColor: const WidgetStatePropertyAll(Elysium.surface2),
          columnSpacing: 18,
          columns: const [
            DataColumn(label: Text('Team')),
            DataColumn(label: Text('Alliance')),
            DataColumn(label: Text('Neutral')),
            DataColumn(label: Text('Opponent')),
            DataColumn(label: Text('Doing Def')),
            DataColumn(label: Text('Stand Def')),
            DataColumn(label: Text('Driver')),
          ],
          rows: s
              .map((t) => DataRow(cells: [
                    DataCell(_b('${t.teamNum}')),
                    DataCell(Text('${t.avgAllianceTime.toStringAsFixed(0)}s')),
                    DataCell(Text('${t.avgNeutralTime.toStringAsFixed(0)}s')),
                    DataCell(Text('${t.avgOpponentTime.toStringAsFixed(0)}s')),
                    DataCell(Text('${t.avgDoingDefence.toStringAsFixed(1)}/10')),
                    DataCell(Text('${t.avgStandDefence.toStringAsFixed(1)}/10')),
                    DataCell(Text('${t.avgDriverSkill.toStringAsFixed(1)}/10')),
                  ]))
              .toList(),
        ),
      );

  Widget _superTable(BuildContext context, List<TeamStandingSummary> standings) {
    final withSuper = standings.where((t) => t.superEntries.isNotEmpty).toList();
    Widget clip(String v) => ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 170),
          child: Text(v.trim().isEmpty ? '-' : v,
              maxLines: 2, overflow: TextOverflow.ellipsis),
        );

    return _tableCard(
      'Super Scouting Intelligence (tap a team for the full report)',
      withSuper.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: Text('No Super Scouting reports for this competition yet.',
                  style: TextStyle(color: Elysium.muted)),
            )
          : DataTable(
              headingRowColor: const WidgetStatePropertyAll(Elysium.surface2),
              columnSpacing: 18,
              dataRowMinHeight: 48,
              dataRowMaxHeight: 64,
              columns: const [
                DataColumn(label: Text('Team')),
                DataColumn(label: Text('Capacity')),
                DataColumn(label: Text('Bump')),
                DataColumn(label: Text('Defense')),
                DataColumn(label: Text('Limitations')),
                DataColumn(label: Text('Penalties')),
              ],
              rows: withSuper.map((t) {
                final latest = t.superEntries.first;
                return DataRow(cells: [
                  DataCell(
                    _b('${t.teamNum}'),
                    onTap: () => showEntryDetails(context,
                        title: 'Team ${t.teamNum} • latest report',
                        rows: latest.detailRows()),
                  ),
                  DataCell(clip(latest.robotCap)),
                  DataCell(clip(latest.bumpSpeed)),
                  DataCell(clip(latest.defenceStyle)),
                  DataCell(clip(latest.robotLimits)),
                  DataCell(clip(latest.penalties)),
                ]);
              }).toList(),
            ),
    );
  }
}
