import 'package:flutter/material.dart' hide Text;

import '../services/app_settings_service.dart';
import '../services/auth_service.dart';
import '../services/data_repository.dart';
import '../services/locale_service.dart';
import '../services/pit_scouting_service.dart';
import '../theme/elysium_theme.dart';
import 'entry_detail_dialog.dart';
import 'localized_text.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _name = TextEditingController();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name.text = AuthService.instance.currentUser?.name ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await AuthService.instance.updateProfile(
        currentPassword: _currentPassword.text,
        name: _name.text,
        newPassword: _newPassword.text,
      );
      _currentPassword.clear();
      _newPassword.clear();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Profile updated')));
      }
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteAccount() async {
    if (_saving) return;
    final confirmed = await confirmDialog(
      context,
      title: 'Delete account',
      message:
          'This permanently deletes your account and all scouting forms you submitted. This cannot be undone.',
      confirmLabel: 'Delete account',
    );
    if (!confirmed || !mounted) return;
    final password = _currentPassword.text;
    if (password.isEmpty) {
      _showError(StateError('Enter your current password before deleting.'));
      return;
    }
    setState(() => _saving = true);
    try {
      await AuthService.instance.deleteAccount(password: password);
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          DataRepository.instance,
          PitScoutingService.instance,
          AuthService.instance,
        ]),
        builder: (context, _) {
          final current = AuthService.instance.currentUser;
          if (current == null) return const SizedBox.shrink();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ElysiumCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Elysium.primary,
                      child: Text(
                        current.name.isEmpty
                            ? '?'
                            : current.name.characters.first.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      current.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${current.role} • ${current.teamNumber} — ${current.teamName}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const SectionTitle('Account details'),
              const SizedBox(height: 8),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _currentPassword,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _newPassword,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New password (leave blank to keep current)',
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _saveProfile,
                  child: Text(_saving ? 'Saving...' : 'Save changes'),
                ),
              ),
              const SizedBox(height: 18),
              const SectionTitle('App preferences'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Dark mode'),
                value: AppSettingsService.instance.isDarkMode,
                onChanged: AppSettingsService.instance.setDarkMode,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('App language'),
                trailing: const LocaleSwitchButton(),
                subtitle: Text(
                  LocaleService.instance.isHebrew ? 'עברית' : 'English',
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await AuthService.instance.logout();
                  if (context.mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Log out'),
              ),
              const SizedBox(height: 22),
              const SectionTitle('Your submitted forms'),
              const SizedBox(height: 8),
              ..._scoutingForms(current.id),
              ..._superForms(current.id),
              ..._pitForms(current.id),
              if (_submittedCount(current.id) == 0)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text('No forms submitted yet.'),
                ),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: _saving ? null : _deleteAccount,
                icon: const Icon(Icons.delete_forever, color: Elysium.danger),
                label: const Text(
                  'Delete account',
                  style: TextStyle(color: Elysium.danger),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  int _submittedCount(String userId) =>
      DataRepository.instance.scouting
          .where((entry) => entry.scouterId == userId)
          .length +
      DataRepository.instance.superScouting
          .where((entry) => entry.scouterId == userId)
          .length +
      PitScoutingService.instance.entries
          .where((entry) => entry.scouterId == userId)
          .length;

  List<Widget> _scoutingForms(String userId) => DataRepository.instance.scouting
      .where((entry) => entry.scouterId == userId)
      .map(
        (entry) => _formTile(
          'Match • ${entry.competition} • ${entry.teamNum} • ${entry.matchNum}',
          entry.createdAt,
          () => showEntryDetails(
            context,
            title: 'Match scouting • Team ${entry.teamNum}',
            rows: entry.detailRows(),
          ),
        ),
      )
      .toList();

  List<Widget> _superForms(String userId) =>
      DataRepository.instance.superScouting
          .where((entry) => entry.scouterId == userId)
          .map(
            (entry) => _formTile(
              'Super scouting • ${entry.competition} • ${entry.teamNum}',
              entry.createdAt,
              () => showEntryDetails(
                context,
                title: 'Super scouting • Team ${entry.teamNum}',
                rows: entry.detailRows(),
              ),
            ),
          )
          .toList();

  List<Widget> _pitForms(String userId) => PitScoutingService.instance.entries
      .where((entry) => entry.scouterId == userId)
      .map(
        (entry) => _formTile(
          'Pit scouting • ${entry.competition} • ${entry.teamNum}',
          entry.createdAt,
          () => showEntryDetails(
            context,
            title: 'Pit scouting • Team ${entry.teamNum}',
            rows: entry.detailRows(),
          ),
        ),
      )
      .toList();

  Widget _formTile(String title, String createdAt, VoidCallback onTap) {
    final date = DateTime.tryParse(createdAt);
    return ElysiumCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title),
        subtitle: Text(date == null ? createdAt : date.toLocal().toString()),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
