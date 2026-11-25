import 'package:flutter/material.dart' hide Text;
import '../services/locale_service.dart';

import '../models/team_model.dart';
import '../services/tba_service.dart';
import '../theme/elysium_theme.dart';
import 'localized_text.dart';

class MatchSchedulePage extends StatefulWidget {
  const MatchSchedulePage({super.key});

  @override
  State<MatchSchedulePage> createState() => _MatchSchedulePageState();
}

class _MatchSchedulePageState extends State<MatchSchedulePage> {
  final _eventKey = TextEditingController();
  final List<TbaMatch> _matches = [];
  final List<TbaTeam> _teams = [];
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    CompetitionRepository.loadCompetitions().then((competitions) {
      if (!mounted || competitions.isEmpty) return;
      final event = competitions.first.id;
      _eventKey.text = event;
      _load(event);
    });
  }

  @override
  void dispose() {
    _eventKey.dispose();
    super.dispose();
  }

  Future<void> _load(String eventKey) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var matches = await TbaService.instance.matchesAtEvent(eventKey);
      var teams = await TbaService.instance.teamsAtEvent(eventKey);
      matches = matches.isEmpty
          ? await TbaService.instance.cachedMatches(eventKey)
          : matches;
      teams =
          teams.isEmpty ? await TbaService.instance.cachedTeams(eventKey) : teams;
      if (mounted) {
        setState(() {
          _matches
            ..clear()
            ..addAll(matches);
          _teams
            ..clear()
            ..addAll(teams);
        });
      }
    } catch (error) {
      if (mounted) {
        final cachedMatches =
            await TbaService.instance.cachedMatches(eventKey);
        final cachedTeams =
            await TbaService.instance.cachedTeams(eventKey);
        if (mounted) {
          setState(() {
            _matches
              ..clear()
              ..addAll(cachedMatches);
            _teams
              ..clear()
              ..addAll(cachedTeams);
            _error = error;
          });
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _alliance(List<int> teams) =>
      teams.isEmpty ? '-' : teams.map((team) => team.toString()).join(', ');

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _eventKey,
                  decoration: InputDecoration(
                    labelText: LocaleService.instance.text('TBA event key'),
                    hintText: LocaleService.instance.text('e.g. 2025isde1'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading
                      ? null
                      : () => _load(_eventKey.text.trim()),
                  child: const Text('Load'),
                ),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Offline/cached data: $_error',
              style: const TextStyle(color: Elysium.warning),
            ),
          ),
        if (_loading)
          const LinearProgressIndicator()
        else
          Expanded(
            child: _matches.isEmpty
                ? Center(
                    child: Text(
                      _teams.isEmpty
                          ? 'No schedule loaded'
                          : '${_teams.length} teams loaded',
                      style: const TextStyle(color: Elysium.muted),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: _matches.length,
                    itemBuilder: (context, index) {
                      final match = _matches[index];
                      final title = match.matchLevel == 'qm'
                          ? 'Qualification ${match.matchNumber}'
                          : '${match.matchLevel.toUpperCase()} ${match.setNumber}-${match.matchNumber}';
                      return ElysiumCard(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(
                            'Red: ${_alliance(match.redTeams)}  •  '
                            'Blue: ${_alliance(match.blueTeams)}',
                          ),
                          trailing: match.redScore == null
                              ? const Icon(Icons.schedule_rounded)
                              : Text(
                                  '${match.redScore}-${match.blueScore}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900),
                                ),
                        ),
                      );
                    },
                  ),
          ),
      ],
    );
  }
}
