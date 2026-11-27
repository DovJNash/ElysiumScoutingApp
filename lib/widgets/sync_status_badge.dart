import 'package:flutter/material.dart' hide Text;
import '../services/sync_service.dart';
import '../theme/elysium_theme.dart';
import 'localized_text.dart';

/// Small status pill for the blue app bar:
/// Live / Syncing / Offline / Sync problem. Tap = sync now (and, when there is
/// a problem, shows the reason).
class SyncStatusBadge extends StatelessWidget {
  const SyncStatusBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SyncService.instance,
      builder: (context, _) {
        final sync = SyncService.instance;
        final theme = Theme.of(context);
        final dark = theme.brightness == Brightness.dark;
        final pending = sync.pendingCount;
        final problem = sync.isOnline && !sync.isSyncing && sync.lastError != null;

        Color color;
        IconData icon;
        String label;

        if (!sync.isOnline) {
          color = Elysium.warning;
          icon = Icons.cloud_off_rounded;
          label = pending > 0 ? 'Offline ($pending)' : 'Offline';
        } else if (problem) {
          color = Elysium.danger;
          icon = Icons.error_outline_rounded;
          label = pending > 0 ? 'Problem ($pending)' : 'Problem';
        } else if (sync.isSyncing || pending > 0) {
          color = Elysium.info;
          icon = Icons.sync_rounded;
          label = 'Syncing ($pending)';
        } else {
          color = Elysium.success;
          icon = Icons.cloud_done_rounded;
          label = 'Live';
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: InkWell(
            onTap: () {
              if (problem) {
                _showProblem(context, sync);
              } else if (sync.isOnline) {
                sync.syncAll();
              }
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF243A56) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.fade(0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 15, color: color),
                  const SizedBox(width: 5),
                  Text(label,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: color)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showProblem(BuildContext context, SyncService sync) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Theme.of(ctx).dividerColor),
        ),
        title: const Text('Sync problem',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text(
          '${sync.lastError}\n\nYour forms are safe on this device and will '
          'upload automatically once this is fixed.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              sync.syncAll();
            },
            child: const Text('Retry now'),
          ),
        ],
      ),
    );
  }
}
