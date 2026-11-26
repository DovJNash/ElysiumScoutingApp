import 'package:flutter/material.dart' hide Text;
import '../config/supabase_config.dart';
import '../models/team_model.dart';
import '../services/locale_service.dart';
import '../theme/elysium_theme.dart';
import 'localized_text.dart';

class TeamLogo extends StatelessWidget {
  final TeamInfo team;
  final double size;

  const TeamLogo({super.key, required this.team, this.size = 44});

  /// Own logo for team 1937, otherwise The Blue Alliance avatar of this season
  /// and (if that does not exist) of the previous season.
  List<String> get _urls {
    if (team.logoUrl.isEmpty) return const [];
    final list = <String>[team.logoUrl];
    final marker = '/avatar/${SupabaseConfig.season}/';
    if (team.logoUrl.contains(marker)) {
      list.add(team.logoUrl
          .replaceFirst(marker, '/avatar/${SupabaseConfig.season - 1}/'));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text('${team.number}',
          style: TextStyle(
              fontSize: size * 0.28,
              fontWeight: FontWeight.w900,
              color: Elysium.primary)),
    );

    Widget content;
    if (team.number == 1937) {
      content = Padding(
        padding: EdgeInsets.all(size * 0.1),
        child: Image.asset(Elysium.iconAsset,
            fit: BoxFit.contain, filterQuality: FilterQuality.high),
      );
    } else if (_urls.isEmpty) {
      content = fallback;
    } else {
      content = _NetworkAvatar(urls: _urls, fallback: fallback);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Elysium.surface2,
          border: Border.all(color: Elysium.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: content,
      ),
    );
  }
}

class _NetworkAvatar extends StatefulWidget {
  final List<String> urls;
  final Widget fallback;
  const _NetworkAvatar({required this.urls, required this.fallback});

  @override
  State<_NetworkAvatar> createState() => _NetworkAvatarState();
}

class _NetworkAvatarState extends State<_NetworkAvatar> {
  int _i = 0;

  @override
  void didUpdateWidget(covariant _NetworkAvatar old) {
    super.didUpdateWidget(old);
    if (old.urls.first != widget.urls.first) _i = 0;
  }

  @override
  Widget build(BuildContext context) {
    if (_i >= widget.urls.length) return widget.fallback;
    return Image.network(
      widget.urls[_i],
      key: ValueKey(widget.urls[_i]),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _i++);
        });
        return widget.fallback;
      },
      loadingBuilder: (c, child, p) => p == null ? child : widget.fallback,
    );
  }
}

/// Searchable team list. Typing a number that is not in competitions.json
/// offers "scout it anyway", so a missing team never blocks a scouter.
class TeamPicker extends StatefulWidget {
  final CompetitionInfo competition;
  final ValueChanged<TeamInfo> onSelected;
  final VoidCallback onBack;
  final Color accent;

  const TeamPicker({
    super.key,
    required this.competition,
    required this.onSelected,
    required this.onBack,
    this.accent = Elysium.primary,
  });

  @override
  State<TeamPicker> createState() => _TeamPickerState();
}

class _TeamPickerState extends State<TeamPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final teams = widget.competition.teams.where((t) {
      if (q.isEmpty) return true;
      return '${t.number}'.contains(q) || t.name.toLowerCase().contains(q);
    }).toList();

    final typed = int.tryParse(q);
    final showUnlisted = typed != null &&
        typed > 0 &&
        !widget.competition.teams.any((t) => t.number == typed);

    return Column(
      children: [
        Container(
          decoration: const BoxDecoration(
            color: Elysium.surface,
            border: Border(bottom: BorderSide(color: Elysium.border)),
          ),
          padding: const EdgeInsets.fromLTRB(8, 6, 16, 10),
          child: Column(
            children: [
              Row(
                children: [
                  TextButton.icon(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Competitions'),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(widget.competition.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: LocaleService.instance
                        .text('Search team number or name'),
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (showUnlisted)
                ElysiumCard(
                  margin: const EdgeInsets.only(bottom: 10),
                  borderColor: widget.accent,
                  child: ListTile(
                    leading: const Icon(Icons.add_circle_outline_rounded),
                    title: Text('Team $typed (not in list)',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: const Text('Scout it anyway'),
                    trailing: ElevatedButton(
                      onPressed: () => widget.onSelected(TeamInfo.unlisted(typed)),
                      child: const Text('Next'),
                    ),
                  ),
                ),
              ...teams.map(
                (team) => ElysiumCard(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    leading: TeamLogo(team: team),
                    title: Text('${team.number} — ${team.name}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                    trailing: ElevatedButton(
                      onPressed: () => widget.onSelected(team),
                      child: const Text('Next'),
                    ),
                    onTap: () => widget.onSelected(team),
                  ),
                ),
              ),
              if (teams.isEmpty && !showUnlisted)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('No team found. Type the team number to add it.',
                        style: TextStyle(color: Elysium.muted)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
