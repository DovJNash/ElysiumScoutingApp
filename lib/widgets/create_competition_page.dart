import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as material show Text;
import '../models/team_model.dart';
import '../services/locale_service.dart';
import '../services/tba_service.dart';
import '../theme/elysium_theme.dart';
import 'localized_text.dart';
import 'team_picker.dart';

/// What the Leader entered when creating a competition.
class NewCompetition {
  final String id;
  final String name;
  final List<TeamInfo> teams;
  const NewCompetition({
    required this.id,
    required this.name,
    required this.teams,
  });
}

/// "Create competition": ID, name and a checklist of every Israeli district
/// team (ISR 2027) instead of typing team numbers.
/// Pops with a [NewCompetition], or null when cancelled.
class CreateCompetitionPage extends StatefulWidget {
  /// IDs that are already taken (compared ignoring upper/lower case).
  final Set<String> existingIds;
  const CreateCompetitionPage({super.key, this.existingIds = const {}});

  @override
  State<CreateCompetitionPage> createState() => _CreateCompetitionPageState();
}

class _CreateCompetitionPageState extends State<CreateCompetitionPage> {
  final _id = TextEditingController();
  final _name = TextEditingController();
  final _search = TextEditingController();
  final _manual = TextEditingController();

  List<TeamInfo> _teams = [];
  bool _loading = true;
  final Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  @override
  void dispose() {
    _id.dispose();
    _name.dispose();
    _search.dispose();
    _manual.dispose();
    super.dispose();
  }

  Future<void> _loadTeams() async {
    List<TbaTeam> teams = [];
    try {
      teams = await TbaService.instance.israeliTeams();
    } catch (_) {
      teams = await TbaService.instance.cachedIsraeliTeams();
    }
    if (!mounted) return;
    setState(() {
      _teams = teams
          .map((team) => TeamInfo.fromTba(
                number: team.number,
                name: team.name,
                logoUrl: team.logoUrl,
              ))
          .toList();
      _loading = false;
    });
  }

  List<TeamInfo> get _shown {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return _teams;
    return _teams
        .where((team) =>
            '${team.number}'.contains(query) ||
            team.name.toLowerCase().contains(query))
        .toList();
  }

  /// Teams ticked in the list plus (only when the list could not be loaded)
  /// the typed numbers.
  Set<int> get _chosenNumbers {
    final numbers = {..._selected};
    for (final part in _manual.text.split(RegExp(r'[,\s]+'))) {
      final number = int.tryParse(part);
      if (number != null && number > 0) numbers.add(number);
    }
    return numbers;
  }

  void _warn(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _create() {
    final id = _id.text.trim();
    final name = _name.text.trim();
    if (id.isEmpty || name.isEmpty) {
      _warn('Enter a competition ID and name.');
      return;
    }
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id)) {
      _warn('The ID can only contain letters, numbers, - and _ (no spaces).');
      return;
    }
    if (widget.existingIds.any((e) => e.toLowerCase() == id.toLowerCase())) {
      _warn('A competition with this ID already exists.');
      return;
    }
    final numbers = _chosenNumbers.toList()..sort();
    if (numbers.isEmpty) {
      _warn('Choose at least one team.');
      return;
    }
    final byNumber = {for (final team in _teams) team.number: team};
    Navigator.of(context).pop(NewCompetition(
      id: id,
      name: name,
      teams: [
        for (final number in numbers)
          byNumber[number] ?? TeamInfo.unlisted(number),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    final count = _chosenNumbers.length;
    return Scaffold(
      appBar: AppBar(title: const ElysiumAppBarTitle('Create competition')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _id,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: LocaleService.instance.text('Competition ID'),
                    hintText: 'e.g. 2027isr_practice',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText:
                        LocaleService.instance.text('Competition name'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _teamSection(shown)),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _create,
                  icon: const Icon(Icons.add_business_rounded),
                  label: Text('Create competition ($count '
                      '${count == 1 ? 'team' : 'teams'})'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _teamSection(List<TeamInfo> shown) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_teams.isEmpty) {
      // The team list could not be loaded (offline and nothing cached).
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Could not load the Israeli teams. Type the team numbers instead.',
            style: TextStyle(color: Elysium.warning),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _manual,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: LocaleService.instance.text('Existing team numbers'),
              hintText: '1937,1690,1574',
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              setState(() => _loading = true);
              _loadTeams();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
          ),
        ],
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText:
                  LocaleService.instance.text('Search team number or name'),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_selected.length} of ${_teams.length} teams selected',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: Elysium.muted),
                ),
              ),
              TextButton(
                onPressed: shown.isEmpty
                    ? null
                    : () => setState(
                        () => _selected.addAll(shown.map((t) => t.number))),
                child: const Text('Select all'),
              ),
              TextButton(
                onPressed: _selected.isEmpty
                    ? null
                    : () => setState(_selected.clear),
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? const Center(
                  child: Text('No team found.',
                      style: TextStyle(color: Elysium.muted)),
                )
              : ListView.builder(
                  itemCount: shown.length,
                  itemBuilder: (context, index) {
                    final team = shown[index];
                    return CheckboxListTile(
                      value: _selected.contains(team.number),
                      onChanged: (checked) => setState(() {
                        if (checked == true) {
                          _selected.add(team.number);
                        } else {
                          _selected.remove(team.number);
                        }
                      }),
                      controlAffinity: ListTileControlAffinity.trailing,
                      secondary: TeamLogo(team: team, size: 40),
                      title: material.Text(
                        '${team.number}  ${team.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
