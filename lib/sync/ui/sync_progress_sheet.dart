part of 'sync.dart';

class _SyncProgressSheet extends StatefulWidget {
  const _SyncProgressSheet({required this.app});
  final AppController app;
  @override
  State<_SyncProgressSheet> createState() => _SyncProgressSheetState();
}

class _SyncProgressSheetState extends State<_SyncProgressSheet> {
  bool _authenticating = false;

  Future<void> _retry() async {
    if (_authenticating || widget.app.sync.busy) return;
    final app = widget.app;
    final selected = app.sync.incompleteTargets;
    final term = app.sync.term;
    setState(() => _authenticating = true);
    try {
      if (!mounted) return;
      await startSync(
        context,
        app,
        targets: selected,
        term: term,
        verify: (request) => verifySchoolLogin(context, request),
      );
    } finally {
      if (mounted) setState(() => _authenticating = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.app.sync,
    builder: (context, _) {
      final model = widget.app.sync;
      final theme = Theme.of(context);
      final results = model.results;
      final l10n = context.l10n;
      return SheetLayout(
        header: SheetHeader(
          title: Text(l10n.syncProgress),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.collapse),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (model.term case final term?) ...[
              Text(term, style: theme.textTheme.bodySmall),
              const SizedBox(height: 6),
            ],
            Text(
              model.busy
                  ? l10n.syncProcessed(results.length, model.targets.length)
                  : model.cancelled
                  ? l10n.syncCancelled
                  : model.incompleteTargets.isEmpty
                  ? l10n.syncComplete
                  : l10n.syncPartial,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: model.targets.isEmpty
                  ? 0
                  : results.length / model.targets.length,
              minHeight: 3,
            ),
            const SizedBox(height: 16),
            for (final target in model.targets)
              _SyncProgressRow(controller: model, target: target, l10n: l10n),
          ],
        ),
        actions: model.busy
            ? Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.continueAfterCollapse,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: model.cancelled ? null : model.cancel,
                    child: Text(
                      model.cancelled ? l10n.cancelling : l10n.cancelSync,
                    ),
                  ),
                ],
              )
            : model.incompleteTargets.isNotEmpty
            ? SheetActionBar.primary(
                primary: FilledButton(
                  onPressed: _authenticating ? null : _retry,
                  child: Text(
                    _authenticating ? l10n.verifying : l10n.retryIncomplete,
                  ),
                ),
              )
            : null,
      );
    },
  );
}

class _SyncProgressRow extends StatelessWidget {
  const _SyncProgressRow({
    required this.controller,
    required this.target,
    required this.l10n,
  });

  final SyncController controller;
  final SyncTarget target;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outcome = controller.results[target]?.outcome;
    final failed = switch (outcome) {
      SyncOutcome.failed ||
      SyncOutcome.needsLogin ||
      SyncOutcome.needsVerification ||
      SyncOutcome.saveFailed => true,
      _ => false,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 14),
            child: controller.isRunning(target)
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    switch (outcome) {
                      SyncOutcome.synced => Icons.check_circle_outline_rounded,
                      SyncOutcome.failed ||
                      SyncOutcome.needsLogin ||
                      SyncOutcome.needsVerification ||
                      SyncOutcome.saveFailed => Icons.error_outline_rounded,
                      SyncOutcome.cancelled => Icons.close_rounded,
                      SyncOutcome.noSchedule => Icons.event_busy_rounded,
                      null => Icons.schedule_rounded,
                    },
                    size: 20,
                    color: failed
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  target.localizedTitle(l10n),
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  syncProgressText(l10n, controller, target),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
