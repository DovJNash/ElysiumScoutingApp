import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as material show Text;
import '../models/pit_scouting_entry.dart';
import '../models/team_model.dart';
import '../services/locale_service.dart';
import '../services/pit_scouting_service.dart';
import '../theme/elysium_theme.dart';
import 'localized_text.dart';
import 'team_picker.dart';

/// Every team of a competition with all of its pit scouting forms: the team's
/// logo, number and name, how many forms were submitted for it, and (when the
/// team is opened) the data of every form. Shown in the Data tab of the
/// Strategy and Leader roles.
class PitDataView extends StatefulWidget {
  final CompetitionInfo competition;
  const PitDataView({super.key, required this.competition});

  @override
  State<PitDataView> createState() => _PitDataViewState();
}

class _PitDataViewState extends State<PitDataView> {
  final TextEditingController _search = TextEditingController();
  bool _onlyWithForms = false;
  bool _refreshing = false;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final error = await PitScoutingService.instance.pull();
    if (!mounted) return;
    setState(() {
      _refreshing = false;
      _offline = error != null;
    });
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  static String _when(String iso) {
    final time = DateTime.tryParse(iso)?.toLocal();
    if (time == null) return '';
    return '${time.year}-${_pad(time.month)}-${_pad(time.day)} '
        '${_pad(time.hour)}:${_pad(time.minute)}';
  }

  static String _formsLabel(int n) => n == 1 ? '1 pit form' : '$n pit forms';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PitScoutingService.instance,
      builder: (context, _) {
        final comp = widget.competition;

        final byTeam = <int, List<PitScoutingEntry>>{};
        for (final entry in PitScoutingService.instance.entries) {
          if (entry.competition != comp.id) continue;
          byTeam.putIfAbsent(entry.teamNum, () => []).add(entry);
        }
        for (final list in byTeam.values) {
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        }

        // Every team of the competition, plus teams that have a form but are
        // not in the competition's list.
        final teams = <int, TeamInfo>{
          for (final team in comp.teams) team.number: team,
        };
        for (final number in byTeam.keys) {
          teams.putIfAbsent(number, () => TeamInfo.unlisted(number));
        }
        final all = teams.values.toList()
          ..sort((a, b) => a.number.compareTo(b.number));

        final scouted = all.where((t) => byTeam.containsKey(t.number)).length;
        final totalForms = byTeam.values.fold<int>(0, (sum, l) => sum + l.length);

        final query = _search.text.trim().toLowerCase();
        final shown = all.where((team) {
          if (_onlyWithForms && !byTeam.containsKey(team.number)) return false;
          if (query.isEmpty) return true;
          return '${team.number}'.contains(query) ||
              team.name.toLowerCase().contains(query);
        }).toList();

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  const Expanded(child: SectionTitle('Pit scouting data')),
                  if (_refreshing)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    IconButton(
                      tooltip: LocaleService.instance.text('Refresh'),
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 2),
                child: Text(
                  '$scouted of ${all.length} teams scouted • '
                  '${totalForms == 1 ? '1 form' : '$totalForms forms'}',
                  style:
                      const TextStyle(fontSize: 12, color: Elysium.muted),
                ),
              ),
              if (_offline)
                const Padding(
                  padding: EdgeInsets.only(left: 12, top: 4),
                  child: Text(
                    'Showing saved pit data (no connection)',
                    style: TextStyle(fontSize: 12, color: Elysium.warning),
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: LocaleService.instance
                      .text('Search team number or name'),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilterChip(
                  label: const Text('Only teams with forms'),
                  selected: _onlyWithForms,
                  onSelected: (value) =>
                      setState(() => _onlyWithForms = value),
                ),
              ),
              const SizedBox(height: 8),
              if (shown.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('No team found.',
                        style: TextStyle(color: Elysium.muted)),
                  ),
                ),
              ...shown.map((team) => _teamCard(
                    comp,
                    team,
                    byTeam[team.number] ?? const <PitScoutingEntry>[],
                  )),
            ],
          ),
        );
      },
    );
  }

  Widget _teamCard(
    CompetitionInfo comp,
    TeamInfo team,
    List<PitScoutingEntry> forms,
  ) {
    final hasForms = forms.isNotEmpty;
    final title = Row(
      children: [
        Text('${team.number}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(width: 10),
        Expanded(
          child: material.Text(
            team.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
    final subtitle = Padding(
      padding: const EdgeInsets.only(top: 4),
      child: hasForms
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Elysium.success.fade(0.16),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _formsLabel(forms.length),
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Elysium.success),
              ),
            )
          : const Text('No pit forms yet',
              style: TextStyle(fontSize: 12, color: Elysium.muted)),
    );
    return ElysiumCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: !hasForms
          ? ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              leading: TeamLogo(team: team, size: 48),
              title: title,
              subtitle: subtitle,
            )
          : Theme(
              // no divider lines inside the card
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: PageStorageKey('pit_${comp.id}_${team.number}'),
                tilePadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                leading: TeamLogo(team: team, size: 48),
                title: title,
                subtitle: subtitle,
                children: forms.map(_formCard).toList(),
              ),
            ),
    );
  }

  Widget _formCard(PitScoutingEntry entry) {
    final fields = <(String, String)>[
      ('Autonomous types', entry.autonomousTypes),
      ('What the team does well', entry.strengths),
      ('What is difficult for the team', entry.difficulties),
      ('How the team plays defense', entry.defense),
      ('How is the team different', entry.otherNotes),
    ];
    final when = _when(entry.createdAt);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Elysium.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Elysium.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline_rounded,
                  size: 16, color: Elysium.muted),
              const SizedBox(width: 6),
              Expanded(
                child: material.Text(
                  when.isEmpty
                      ? entry.scouterName
                      : '${entry.scouterName} • $when',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Elysium.muted),
                ),
              ),
              if (!entry.isSynced)
                const Text('Waiting for internet',
                    style: TextStyle(fontSize: 11, color: Elysium.warning)),
            ],
          ),
          const SizedBox(height: 10),
          for (final field in fields) ...[
            Text(field.$1,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Elysium.primary)),
            const SizedBox(height: 2),
            // The text a scouter typed is shown exactly as written.
            material.Text(field.$2.isEmpty ? '—' : field.$2),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
