import 'package:flutter/material.dart';
import '../models/scouting_entry.dart';
import '../models/super_scouting_entry.dart';
import '../services/auth_service.dart';
import '../services/data_repository.dart';
import '../services/sync_service.dart';
import '../theme/elysium_theme.dart';
import 'entry_detail_dialog.dart';

/// Bottom sheet listing ONLY the current user's own forms, with delete.
/// superMode = false -> Scouting forms (Scouter), true -> Super Scouting (Strategy).
void showMySubmissionsSheet(BuildContext context, {required bool superMode}) {
  final user = AuthService.instance.currentUser!;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Elysium.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (_, controller) => ListenableBuilder(
        listenable: DataRepository.instance,
        builder: (context, _) {
          final repo = DataRepository.instance;
          final scouting = superMode
              ? <ScoutingEntry>[]
              : repo.scouting.where((e) => e.scouterId == user.id).toList();
          final supers = superMode
              ? repo.superScouting.where((e) => e.scouterId == user.id).toList()
              : <SuperScoutingEntry>[];
          final count = scouting.length + supers.length;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Elysium.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SectionTitle(
                  superMode ? 'My Super Scouting Reports' : 'My Submitted Forms',
                  subtitle: 'You can only delete forms submitted by your own account.',
                ),
                const Divider(height: 24),
                Expanded(
                  child: count == 0
                      ? const Center(
                          child: Text('Nothing submitted yet.',
                              style: TextStyle(color: Elysium.muted)))
                      : ListView(
                          controller: controller,
                          children: [
                            ...scouting.map((e) => _tile(
                                  context,
                                  title:
                                      '${e.competition} • Match ${e.matchNum} • Team ${e.teamNum}',
                                  subtitle:
                                      'Auto ${e.autoShoot} | Teleop ${e.teleopShoot} | Driver ${e.driverSkill}/10',
                                  synced: e.isSynced,
                                  onOpen: () => showEntryDetails(context,
                                      title: 'Match ${e.matchNum} • Team ${e.teamNum}',
                                      rows: e.detailRows()),
                                  onDelete: () => SyncService.instance
                                      .deleteScoutingRecord(entry: e, requester: user),
                                )),
                            ...supers.map((e) => _tile(
                                  context,
                                  title: '${e.competition} • Team ${e.teamNum}',
                                  subtitle:
                                      'BPS: ${e.bps.isEmpty ? '-' : e.bps} | Miss: ${e.missPercent.isEmpty ? '-' : e.missPercent}',
                                  synced: e.isSynced,
                                  onOpen: () => showEntryDetails(context,
                                      title: 'Super Scouting • Team ${e.teamNum}',
                                      rows: e.detailRows()),
                                  onDelete: () => SyncService.instance
                                      .deleteSuperScoutingRecord(
                                          entry: e, requester: user),
                                )),
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

Widget _tile(
  BuildContext context, {
  required String title,
  required String subtitle,
  required bool synced,
  required VoidCallback onOpen,
  required Future<void> Function() onDelete,
}) {
  return ElysiumCard(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      onTap: onOpen,
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
      subtitle: Row(
        children: [
          Flexible(child: Text(subtitle, overflow: TextOverflow.ellipsis)),
          if (!synced) ...[
            const SizedBox(width: 6),
            const Icon(Icons.cloud_off_rounded, size: 14, color: Elysium.warning),
          ],
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline_rounded, color: Elysium.danger),
        onPressed: () async {
          final ok = await confirmDialog(context,
              title: 'Delete this form?',
              message: 'This also removes it from the server.');
          if (ok) await onDelete();
        },
      ),
    ),
  );
}
