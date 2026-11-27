import 'package:flutter/material.dart' hide Text;

import '../models/team_model.dart';
import '../services/locale_service.dart';
import '../services/tba_service.dart';
import '../services/match_assignment_service.dart';
import '../theme/elysium_theme.dart';
import 'localized_text.dart';

class MatchSchedulePage extends StatefulWidget {
  final bool filterToMyAssignments;

  const MatchSchedulePage({super.key, this.filterToMyAssignments = false});

  @override
  State<MatchSchedulePage> createState() => _MatchSchedulePageState();
}

class _MatchSchedulePageState extends State<MatchSchedulePage> {
  List<TbaEvent> _events = [];
  TbaEvent? _selectedEvent;
  final List<TbaMatch> _matches = [];
  final List<TbaTeam> _teams = [];
  List<MatchAssignment> _assignments = [];
  int _year = 2027;
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
      if (widget.filterToMyAssignments) {
        _assignments = await MatchAssignmentService.instance.loadMine(
          refresh: true,
        );
      }
      events = await TbaService.instance.israeliEvents(year: _year);
    } catch (error) {
      loadError = error;
      events = await TbaService.instance.cachedIsraeliEvents(year: _year);
    }
    if (widget.filterToMyAssignments) {
      final assignedIds =
          _assignments.map((assignment) => assignment.competitionId).toSet();
      events =
          events.where((event) => assignedIds.contains(event.key)).toList();
    }
    if (events.isEmpty) {
      final competitions = await CompetitionRepository.loadCompetitions(
        year: _year,
      );
      events = competitions
          .map(
            (competition) =>
                TbaEvent(key: competition.id, name: competition.name),
          )
          .where((event) => event.key.startsWith('$_year'))
          .where(
            (event) =>
                !widget.filterToMyAssignments ||
                _assignments.any(
                  (assignment) => assignment.competitionId == event.key,
                ),
          )
          .toList();
    }

    if (!mounted) return;
    setState(() {
      _events = events;
      _selectedEvent = events.isEmpty ? null : events.first;
      _error = loadError != null && events.isNotEmpty
          ? 'TBA is unavailable; showing cached events.'
          : loadError;
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
      var matches = results[0] as List<TbaMatch>;
      final teams = results[1] as List<TbaTeam>;
      if (widget.filterToMyAssignments) {
        matches = matches
            .where(
              (match) => _assignments.any(
                (assignment) => assignment.matches(
                  competitionId: event.key,
                  matchLevel: match.matchLevel,
                  setNumber: match.setNumber,
                  matchNumber: match.matchNumber,
                ),
              ),
            )
            .toList();
      }
      if (mounted) {
        setState(() {
          _matches.addAll(matches);
          _teams.addAll(teams);
        });
      }
    } catch (error) {
      var cachedMatches = await TbaService.instance.cachedMatches(event.key);
      if (widget.filterToMyAssignments) {
        cachedMatches = cachedMatches
            .where(
              (match) => _assignments.any(
                (a) => a.matches(
                  competitionId: event.key,
                  matchLevel: match.matchLevel,
                  setNumber: match.setNumber,
                  matchNumber: match.matchNumber,
                ),
              ),
            )
            .toList();
      }
      final cachedTeams = await TbaService.instance.cachedTeams(event.key);
      if (mounted) {
        setState(() {
          _matches
            ..clear()
            ..addAll(cachedMatches);
          _teams
            ..clear()
            ..addAll(cachedTeams);
          _error = cachedMatches.isNotEmpty || cachedTeams.isNotEmpty
              ? 'TBA is unavailable; showing any locally cached schedule data.'
              : error;
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
              DropdownButton<int>(
                value: _year,
                items: const [2026, 2027]
                    .map(
                      (year) =>
                          DropdownMenuItem(value: year, child: Text('$year')),
                    )
                    .toList(),
                onChanged: _loadingEvents || _loading
                    ? null
                    : (year) {
                        if (year == null) return;
                        setState(() => _year = year);
                        _loadEvents();
                      },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<TbaEvent>(
                  value: _selectedEvent,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: LocaleService.instance.text('Competition'),
                  ),
                  hint: const Text('Choose an Israel event'),
                  items: _events
                      .map(
                        (event) => DropdownMenuItem(
                          value: event,
                          child: Text(event.label),
                        ),
                      )
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
                          ? widget.filterToMyAssignments
                              ? 'No assigned events for this year.'
                              : 'No Israel events found for this year.'
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
                          title: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            'Red: ${_alliance(match.redTeams)}  •  '
                            'Blue: ${_alliance(match.blueTeams)}',
                          ),
                          trailing: match.redScore == null
                              ? const Icon(Icons.schedule_rounded)
                              : Text(
                                  '${match.redScore}-${match.blueScore}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
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
