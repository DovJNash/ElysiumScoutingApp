import 'package:flutter/material.dart' hide Text;

import '../models/team_model.dart';
import '../services/auth_service.dart';
import '../services/match_assignment_service.dart';
import '../services/tba_service.dart';
import '../theme/elysium_theme.dart';
import 'localized_text.dart';

class LeaderOperationsPage extends StatefulWidget {
  const LeaderOperationsPage({super.key});

  @override
  State<LeaderOperationsPage> createState() => _LeaderOperationsPageState();
}

class _LeaderOperationsPageState extends State<LeaderOperationsPage> {
  final _password = TextEditingController();
  final _strategyCode = TextEditingController();
  final _leaderCode = TextEditingController();
  List<TeamMember> _members = [];
  TeamMember? _member;
  List<TbaEvent> _events = [];
  TbaEvent? _event;
  List<TbaMatch> _matches = [];
  Set<String> _assignedKeys = {};
  int _year = 2027;
  bool _savingCodes = false;
  bool _loadingMembers = true;
  bool _loadingEvents = false;
  bool _loadingMatches = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMembers();
    _loadEvents();
  }

  @override
  void dispose() {
    _password.dispose();
    _strategyCode.dispose();
    _leaderCode.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _loadingMembers = true;
      _error = null;
    });
    try {
      final members = await MatchAssignmentService.instance.loadTeamMembers();
      if (!mounted) return;
      setState(() {
        _members = members;
        _member = members.isEmpty ? null : members.first;
        _loadingMembers = false;
      });
      if (_member != null) await _loadAssignedMatches();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loadingMembers = false;
      });
    }
  }

  Future<void> _loadEvents() async {
    setState(() {
      _loadingEvents = true;
      _error = null;
    });
    List<TbaEvent> events = [];
    Object? error;
    try {
      events = await TbaService.instance.israeliEvents(year: _year);
    } catch (e) {
      error = e;
      events = await TbaService.instance.cachedIsraeliEvents(year: _year);
    }
    if (!mounted) return;
    setState(() {
      _events = events;
      _event = events.isEmpty ? null : events.first;
      _loadingEvents = false;
      _error = error?.toString();
    });
    if (_event != null) await _loadMatches();
  }

  Future<void> _loadMatches() async {
    final event = _event;
    if (event == null) return;
    setState(() {
      _loadingMatches = true;
      _matches = [];
    });
    Object? error;
    List<TbaMatch> matches = [];
    try {
      matches = await TbaService.instance.matchesAtEvent(event.key);
    } catch (e) {
      error = e;
      matches = await TbaService.instance.cachedMatches(event.key);
    }
    if (!mounted) return;
    setState(() {
      _matches = matches;
      _loadingMatches = false;
      if (error != null) _error = error.toString();
    });
    await _loadAssignedMatches();
  }

  Future<void> _loadAssignedMatches() async {
    final member = _member;
    final event = _event;
    if (member == null || event == null) return;
    try {
      final assignments = await MatchAssignmentService.instance.loadForMember(
        member,
      );
      if (!mounted) return;
      setState(() {
        _assignedKeys = assignments
            .where((assignment) => assignment.competitionId == event.key)
            .map(_assignmentKey)
            .toSet();
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  String _assignmentKey(MatchAssignment assignment) =>
      '${assignment.competitionId}_${assignment.matchLevel}_'
      '${assignment.setNumber}_${assignment.matchNumber}';

  MatchAssignment _asAssignment(TbaEvent event, TbaMatch match) =>
      MatchAssignment(
        competitionId: event.key,
        matchLevel: match.matchLevel,
        setNumber: match.setNumber,
        matchNumber: match.matchNumber,
      );

  Future<void> _setAssigned(TbaMatch match, bool assigned) async {
    final member = _member;
    final event = _event;
    if (member == null || event == null) return;
    final assignment = _asAssignment(event, match);
    final key = _assignmentKey(assignment);
    setState(() => _error = null);
    try {
      await MatchAssignmentService.instance.setAssignment(
        member: member,
        assignment: assignment,
        assigned: assigned,
      );
      if (mounted) {
        setState(() {
          if (assigned) {
            _assignedKeys.add(key);
          } else {
            _assignedKeys.remove(key);
          }
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  Future<void> _saveCodes() async {
    if (_savingCodes) return;
    setState(() {
      _savingCodes = true;
      _error = null;
    });
    try {
      await MatchAssignmentService.instance.updateTeamCodes(
        password: _password.text,
        strategyCode: _strategyCode.text,
        leaderCode: _leaderCode.text,
      );
      _password.clear();
      _strategyCode.clear();
      _leaderCode.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Team access codes updated')),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _savingCodes = false);
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Leader tools'),
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.key_rounded), text: 'Access codes'),
                Tab(
                    icon: Icon(Icons.assignment_ind_rounded),
                    text: 'Assignments'),
              ],
            ),
          ),
          body: TabBarView(children: [_accessCodes(), _assignments()]),
        ),
      );

  Widget _accessCodes() {
    final leader = AuthService.instance.currentUser!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ElysiumCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Update ${leader.teamName} (${leader.teamNumber}) role codes.',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _strategyCode,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Strategy code',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _leaderCode,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Leader code'),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: _savingCodes ? null : _saveCodes,
                child: Text(_savingCodes ? 'Saving...' : 'Update access codes'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Codes are saved only in the private Supabase table and are never bundled in the app.',
        ),
        if (_error != null) _errorMessage(),
      ],
    );
  }

  Widget _assignments() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_loadingMembers)
          const LinearProgressIndicator()
        else if (_members.isEmpty)
          const Text(
            'No Scouter or Strategy accounts are configured for your team.',
          )
        else
          DropdownButtonFormField<TeamMember>(
            initialValue: _member,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Team member'),
            items: _members
                .map(
                  (member) => DropdownMenuItem(
                    value: member,
                    child: Text('${member.name} • ${member.role}'),
                  ),
                )
                .toList(),
            onChanged: (member) async {
              setState(() => _member = member);
              await _loadAssignedMatches();
            },
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Text('Year'),
            const SizedBox(width: 12),
            DropdownButton<int>(
              value: _year,
              items: const [2026, 2027]
                  .map(
                    (year) =>
                        DropdownMenuItem(value: year, child: Text('$year')),
                  )
                  .toList(),
              onChanged: (year) {
                if (year == null) return;
                setState(() => _year = year);
                _loadEvents();
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<TbaEvent>(
                initialValue: _event,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Event'),
                items: _events
                    .map(
                      (event) => DropdownMenuItem(
                        value: event,
                        child: Text(
                          event.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _loadingEvents
                    ? null
                    : (event) {
                        setState(() => _event = event);
                        _loadMatches();
                      },
              ),
            ),
          ],
        ),
        if (_error != null) _errorMessage(),
        if (_loadingEvents || _loadingMatches)
          const LinearProgressIndicator()
        else if (_event == null)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No Israeli TBA events are available for this year.'),
          )
        else if (_matches.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No matches found for this event.'),
          )
        else ...[
          const SizedBox(height: 10),
          const Text(
            'Select the assigned matches. Unassigned matches remain hidden from that account.',
          ),
          const SizedBox(height: 8),
          for (final match in _matches)
            CheckboxListTile(
              value: _assignedKeys.contains(
                _assignmentKey(_asAssignment(_event!, match)),
              ),
              onChanged: (value) => _setAssigned(match, value == true),
              title: Text(
                match.matchLevel == 'qm'
                    ? 'Qualification ${match.matchNumber}'
                    : '${match.matchLevel.toUpperCase()} ${match.setNumber}-${match.matchNumber}',
              ),
              subtitle: Text(
                'Red: ${match.redTeams.join(', ')} • Blue: ${match.blueTeams.join(', ')}',
              ),
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
            ),
        ],
      ],
    );
  }

  Widget _errorMessage() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(_error!, style: const TextStyle(color: Elysium.danger)),
      );
}
