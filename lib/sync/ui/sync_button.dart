import 'package:flutter/material.dart';

import '../../app/controller.dart';
import '../../l10n/l10n.dart';
import '../../ui/app_menu_anchor.dart';
import 'sync.dart';

class SyncButton extends StatelessWidget {
  const SyncButton({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller.sync, controller.agenda]),
    builder: (context, _) {
      final l10n = context.l10n;
      final scheme = Theme.of(context).colorScheme;
      final sync = controller.sync;
      final skippedCount = sync.skippedUpdates.length;
      final hasIssues = sync.hasUnresolvedIssues;
      final Widget icon;
      if (sync.busy) {
        icon = const SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      } else if (skippedCount > 0) {
        icon = Badge.count(
          count: skippedCount,
          backgroundColor: hasIssues ? scheme.error : scheme.primary,
          textColor: hasIssues ? scheme.onError : scheme.onPrimary,
          child: const Icon(Icons.sync_rounded),
        );
      } else if (hasIssues) {
        icon = Badge(
          backgroundColor: scheme.error,
          child: const Icon(Icons.sync_rounded),
        );
      } else {
        icon = const Icon(Icons.sync_rounded);
      }
      return AppMenuAnchor(
        menuChildren: [
          AppMenuItemButton(
            leadingIcon: const Icon(Icons.sync_rounded),
            onPressed: controller.agenda.ready
                ? () => startSync(context, controller)
                : null,
            child: Text(l10n.syncAll),
          ),
          AppMenuItemButton(
            leadingIcon: const Icon(Icons.tune_rounded),
            onPressed: controller.agenda.ready
                ? () => customizeSync(context, controller)
                : null,
            child: Text(l10n.customSync),
          ),
          if (!sync.busy && skippedCount > 0)
            AppMenuItemButton(
              leadingIcon: const Icon(Icons.difference_outlined),
              onPressed: () => showSyncSkippedUpdates(context, controller),
              child: Text(l10n.syncReviewSkipped(skippedCount)),
            ),
          if (hasIssues)
            AppMenuItemButton(
              leadingIcon: Icon(
                Icons.error_outline_rounded,
                color: scheme.error,
              ),
              onPressed: () => showSyncProgress(context, controller),
              child: Text(l10n.viewSyncProgress),
            ),
        ],
        builder: (context, menu, isOpen) => IconButton(
          tooltip: sync.busy ? l10n.viewSyncProgress : l10n.syncTooltip,
          onPressed: () {
            if (sync.busy) {
              if (isOpen) menu.close();
              showSyncProgress(context, controller);
            } else {
              isOpen ? menu.close() : menu.open();
            }
          },
          icon: icon,
        ),
      );
    },
  );
}
