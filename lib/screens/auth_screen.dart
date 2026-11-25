import 'package:flutter/material.dart' hide Text;
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/locale_service.dart';
import '../services/tba_service.dart';
import '../theme/elysium_theme.dart';
import '../models/team_model.dart';
import '../widgets/team_picker.dart';
import '../widgets/localized_text.dart';

enum _AuthView { splitChoice, loginForm, teamSelect, roleSelect, signUpForm }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  _AuthView _view = _AuthView.splitChoice;
  String _role = UserRole.scouter;
  List<TbaTeam> _israeliTeams = [];
  TbaTeam? _selectedTeam;
  bool _loadingTeams = false;
  String _teamQuery = '';

  final _name = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_view == _AuthView.loginForm) {
        await AuthService.instance.login(name: _name.text, password: _password.text);
      } else {
        await AuthService.instance.signUp(
          name: _name.text,
          password: _password.text,
          role: _role,
          roleAccessCode: _code.text,
          teamNumber: _selectedTeam!.number,
          teamName: _selectedTeam!.name,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _go(_AuthView v) => setState(() {
        _error = null;
        _view = v;
      });

  Future<void> _openRegistration() async {
    setState(() {
      _loadingTeams = true;
      _error = null;
      _selectedTeam = null;
      _teamQuery = '';
      _view = _AuthView.teamSelect;
    });
    try {
      final teams = await TbaService.instance.israeliTeams(year: 2027);
      if (mounted) setState(() => _israeliTeams = teams);
    } catch (e) {
      final cached = await TbaService.instance.cachedIsraeliTeams(year: 2027);
      if (mounted) {
        setState(() {
          _israeliTeams = cached;
          _error = cached.isEmpty
              ? 'Could not load the 2027 Israeli team list. Check the TBA API key and internet connection.'
              : null;
        });
      }
    } finally {
      if (mounted) setState(() => _loadingTeams = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final atRoot = _view == _AuthView.splitChoice;
    return PopScope(
      canPop: atRoot,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_view == _AuthView.signUpForm) {
          _go(_AuthView.roleSelect);
        } else if (_view == _AuthView.roleSelect &&
            _selectedTeam != null) {
          _go(_AuthView.teamSelect);
        } else {
          _go(_AuthView.splitChoice);
        }
      },
      child: Scaffold(
        body: Column(
          children: [
            _header(),
            Expanded(
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    child: _current(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Blue brand band with the Elysium logo (compact on small / landscape
  /// screens so the two big panels keep their room).
  Widget _header() {
    final tall = MediaQuery.sizeOf(context).height >= 720;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Elysium.primary, Elysium.primaryDark],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Padding(
              padding:
                  EdgeInsets.fromLTRB(16, tall ? 14 : 8, 16, tall ? 18 : 10),
              child: tall
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElysiumFullLogo(height: 118, onDark: true),
                        SizedBox(height: 6),
                        Text('SCOUTING SYSTEM',
                            style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 3,
                                fontSize: 12)),
                      ],
                    )
                  : const Center(
                      child: ElysiumLogo(size: 42, onDark: true)),
            ),
            const Positioned(
              right: 8,
              top: 4,
              child: LocaleSwitchButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _current() {
    switch (_view) {
      case _AuthView.splitChoice:
        return _split();
      case _AuthView.roleSelect:
        return _roleSelect();
      case _AuthView.teamSelect:
        return _teamSelect();
      case _AuthView.loginForm:
        return _credentials(false);
      case _AuthView.signUpForm:
        return _credentials(true);
    }
  }

  Widget _split() {
    return Row(
      key: const ValueKey('split'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _Panel(
            title: 'LOG IN',
            subtitle: 'Access your scouting, strategy or lead console',
            icon: Icons.login_rounded,
            color: Elysium.primary,
            onTap: () => _go(_AuthView.loginForm),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _Panel(
            title: 'SIGN UP',
            subtitle: 'Create an account and choose your team role',
            icon: Icons.person_add_alt_1_rounded,
            color: Elysium.navy,
            onTap: _openRegistration,
          ),
        ),
      ],
    );
  }

  Widget _teamSelect() {
    final query = _teamQuery.trim().toLowerCase();
    final filtered = _israeliTeams
        .where((team) =>
            query.isEmpty ||
            team.number.toString().contains(query) ||
            team.name.toLowerCase().contains(query))
        .toList();

    return Column(
      key: const ValueKey('teams'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => _go(_AuthView.splitChoice),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const Expanded(
              child: Text(
                'Choose your team',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
        const Text(
          'Israeli FRC teams — 2027 season',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (value) => setState(() => _teamQuery = value),
          decoration: InputDecoration(
            hintText: LocaleService.instance.text('Search team number or name'),
            prefixIcon: const Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 8),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Elysium.danger),
            ),
          ),
        if (_loadingTeams) const LinearProgressIndicator(),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(_loadingTeams
                      ? 'Loading teams...'
                      : 'No teams found. Try again later.'),
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final team = filtered[index];
                    final teamInfo = TeamInfo.fromTba(
                      number: team.number,
                      name: team.name,
                      logoUrl: team.logoUrl,
                    );
                    return Card(
                      child: ListTile(
                        leading: TeamLogo(team: teamInfo, size: 44),
                        title: Text('${team.number} — ${team.name}'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          setState(() {
                            _selectedTeam = team;
                            _error = null;
                            _view = _AuthView.roleSelect;
                          });
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _roleSelect() {
    void pick(String role) => setState(() {
          _role = role;
          _code.clear();
          _error = null;
          _view = _AuthView.signUpForm;
        });

    return Column(
      key: const ValueKey('roles'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => _go(
                _selectedTeam == null
                    ? _AuthView.splitChoice
                    : _AuthView.teamSelect,
              ),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const Expanded(
              child: Text('What is your role?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 48),
          ],
        ),
        if (_selectedTeam != null) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TeamLogo(
                team: TeamInfo.fromTba(
                  number: _selectedTeam!.number,
                  name: _selectedTeam!.name,
                  logoUrl: _selectedTeam!.logoUrl,
                ),
                size: 32,
              ),
              const SizedBox(width: 8),
              Text(
                '${_selectedTeam!.number} — ${_selectedTeam!.name}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final compact = c.maxWidth < 600;
            final panels = [
              _Panel(
                title: UserRole.scouter,
                subtitle: 'Live match data collection',
                icon: Icons.analytics_outlined,
                color: Elysium.roleColor(UserRole.scouter),
                compact: compact,
                onTap: () => pick(UserRole.scouter),
              ),
              _Panel(
                title: UserRole.strategy,
                subtitle: 'Super scouting & analytics (access code)',
                icon: Icons.insights_rounded,
                color: Elysium.roleColor(UserRole.strategy),
                compact: compact,
                onTap: () => pick(UserRole.strategy),
              ),
              _Panel(
                title: UserRole.leader,
                subtitle: 'Scout rankings & moderation (access code)',
                icon: Icons.shield_outlined,
                color: Elysium.roleColor(UserRole.leader),
                compact: compact,
                onTap: () => pick(UserRole.leader),
              ),
            ];
            final spaced = <Widget>[];
            for (var i = 0; i < panels.length; i++) {
              if (i > 0) spaced.add(const SizedBox(width: 10, height: 10));
              spaced.add(Expanded(child: panels[i]));
            }

            return compact
                ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: spaced)
                : Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: spaced);
          }),
        ),
      ],
    );
  }

  Widget _credentials(bool isSignUp) {
    final needsCode = isSignUp && _role != UserRole.scouter;
    return Center(
      key: ValueKey(isSignUp ? 'signup' : 'login'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: ElysiumCard(
            padding: const EdgeInsets.all(22),
            borderColor: isSignUp ? Elysium.roleColor(_role).fade(0.6) : Elysium.border,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _go(isSignUp ? _AuthView.roleSelect : _AuthView.splitChoice),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Back'),
                  ),
                ),
                const SizedBox(height: 6),
                Text(isSignUp ? 'Create $_role Account' : 'Welcome Back',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Elysium.navy)),
                const SizedBox(height: 4),
                Text(
                  isSignUp
                      ? 'Role: $_role'
                      : 'Enter your name and password to continue',
                  style: const TextStyle(color: Elysium.muted),
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: LocaleService.instance.text('Name'),
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: LocaleService.instance.text('Password'),
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                  onSubmitted: (_) => _loading ? null : _submit(),
                ),
                if (isSignUp && _selectedTeam != null) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      TeamLogo(
                        team: TeamInfo.fromTba(
                          number: _selectedTeam!.number,
                          name: _selectedTeam!.name,
                          logoUrl: _selectedTeam!.logoUrl,
                        ),
                        size: 40,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${_selectedTeam!.number} — ${_selectedTeam!.name}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      TextButton(
                        onPressed: _openRegistration,
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                ],
                if (needsCode) ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: _code,
                    decoration: InputDecoration(
                      labelText:
                          LocaleService.instance.text('$_role access code'),
                      helperText: LocaleService.instance.text(
                          'Ask your team lead for the code for this team'),
                      prefixIcon: const Icon(Icons.vpn_key_outlined),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Elysium.danger.fade(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Elysium.danger.fade(0.4)),
                    ),
                    child: Text(_error!, style: const TextStyle(color: Elysium.danger, fontWeight: FontWeight.w600)),
                  ),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : Text(isSignUp ? 'Complete Sign Up' : 'Log In',
                            style: const TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool compact;

  const _Panel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconBubble = Container(
      padding: EdgeInsets.all(compact ? 12 : 18),
      decoration: BoxDecoration(color: color.fade(0.16), shape: BoxShape.circle),
      child: Icon(icon, size: compact ? 28 : 42, color: color),
    );
    final titleText = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(title,
          style: TextStyle(
              fontSize: compact ? 22 : 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: Elysium.navy)),
    );
    final sub = Text(subtitle,
        textAlign: compact ? TextAlign.start : TextAlign.center,
        style: const TextStyle(fontSize: 13, color: Elysium.muted));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.fade(0.16), Elysium.surface],
            ),
            border: Border.all(color: color.fade(0.55), width: 1.6),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: compact
                ? Row(children: [
                    iconBubble,
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Align(alignment: Alignment.centerLeft, child: titleText),
                          const SizedBox(height: 4),
                          sub,
                        ],
                      ),
                    ),
                  ])
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      iconBubble,
                      const SizedBox(height: 20),
                      titleText,
                      const SizedBox(height: 10),
                      sub,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
