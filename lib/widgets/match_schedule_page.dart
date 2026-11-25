import 'package:flutter/material.dart' hide Text;

import '../models/team_model.dart';
import '../services/locale_service.dart';
import '../services/tba_service.dart';
import '../theme/elysium_theme.dart';
import 'localized_text.dart';

class MatchSchedulePage extends StatefulWidget {
  const MatchSchedulePage({super.key});

  @override
  State<MatchSchedulePage> createState() => _MatchSchedulePageState();
}

class _MatchSchedulePageState extends State<MatchSchedulePage> {
  List<TbaEvent> _events = [];
  TbaEvent? _selectedEvent;
  final List<TbaMatch> _matches = [];
  final List<TbaTeam> _teams = [];
  bool _loadingEvents = true;
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _loadingEvents = true;
      _error = null;
    });

    List<TbaEvent> events = [];
    Object? loadError;
    try {
      events =
          await TbaService.instance.israeliDistrictEvents(year: 2027);
    } catch (error) {
      loadError = error;
      events =
          await TbaService.instance.cachedIsraeliDistrictEvents(year: 2027);
    }
    if (events.isEmpty) {
      final competitions = await CompetitionRepository.loadCompetitions();
      events = competitions
          .map((competition) => TbaEvent(
                key: competition.id,
                name: competition.name,
              ))
          .where((event) => event.key.startsWith('2027'))
          .toList();
    }

    if (!mounted) return;
    setState(() {
      _events = events;
      _selectedEvent = events.isEmpty ? null : events.first;
      _error = loadError;
      _loadingEvents = false;
    });
    if (_selectedEvent != null) {
      await _load(_selectedEvent!);
    }
  }

  Future<void> _load(TbaEvent event) async {
    setState(() {
      _selectedEvent = event;
      _loading = true;
      _error = null;
      _matches.clear();
      _teams.clear();
    });
    try {
      final results = await Future.wait<Object>([
        TbaService.instance.matchesAtEvent(event.key),
        TbaService.instance.teamsAtEvent(event.key),
      ]);
      final matches = results[0] as List<TbaMatch>;
      final teams = results[1] as List<TbaTeam>;
      if (mounted) {
        setState(() {
          _matches.addAll(matches);
          _teams.addAll(teams);
        });
      }
    } catch (error) {
      final cachedMatches =
          await TbaService.instance.cachedMatches(event.key);
      final cachedTeams = await TbaService.instance.cachedTeams(event.key);
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
                child: DropdownButtonFormField<TbaEvent>(
                  value: _selectedEvent,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: LocaleService.instance.text('Competition'),
                  ),
                  hint: const Text('Choose a 2027 Israel competition'),
                  items: _events
                      .map((event) => DropdownMenuItem(
                            value: event,
                            child: Text(event.label),
                          ))
                      .toList(),
                  onChanged: _loadingEvents || _loading
                      ? null
                      : (event) {
                          if (event != null) _load(event);
                        },
                ),
              ),
              IconButton(
                tooltip: 'Refresh competitions',
                onPressed: _loadingEvents || _loading ? null : _loadEvents,
                icon: const Icon(Icons.refresh_rounded),
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
        if (_loadingEvents || _loading)
          const LinearProgressIndicator()
        else
          Expanded(
            child: _matches.isEmpty
                ? Center(
                    child: Text(
                      _events.isEmpty
                          ? 'No 2027 Israel competitions found.'
                          : _teams.isEmpty
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
