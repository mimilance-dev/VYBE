import 'package:flutter/material.dart';
import 'playback_synchronizer.dart';

class PlaybackSyncIndicator extends StatelessWidget {
  const PlaybackSyncIndicator(this.status, {super.key});
  final SyncStatus status;
  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      SyncStatus.synced => 'Synced',
      SyncStatus.syncing => 'Getting in sync…',
      SyncStatus.reconnecting => 'Getting you back in sync…'
    };
    final icon = status == SyncStatus.synced
        ? Icons.cloud_done_outlined
        : Icons.cloud_sync_outlined;
    return Semantics(
        label: label,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]));
  }
}
