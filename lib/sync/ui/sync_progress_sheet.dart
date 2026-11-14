part of 'sync.dart';

class _SyncProgressSheet extends StatefulWidget {
  const _SyncProgressSheet({required this.app});
  final AppController app;
  @override
  State<_SyncProgressSheet> createState() => _SyncProgressSheetState();
}

class _SyncProgressSheetState extends State<_SyncProgressSheet> {
  bool _authenticating = false;

  Future<void> _authenticate({required bool school}) async {
    if (_authenticating) return;
    final app = widget.app;
    setState(() => _authenticating = true);
    final bool success;
    try {
      if (!school) {
        success = await showMoocAccount(context, app.mooc);
      } else if (app.school.username == null || app.school.loginExpired) {
        final target = app.sync.incompleteTargets.firstWhere(
          (target) => target.usesSchoolSession,
        );
        success =
            await openSchoolLogin(context, app.school, source: target.source) ==
            true;
      } else {
        success = await app.school.restoreAccount(
          verify: (request) => verifySchoolLogin(context, request),
        );
      }
    } finally {
      if (mounted) setState(() => _authenticating = false);
    }
    if (success && mounted && !app.sync.busy) {
      await _retry();
    }
  }

  Future<void> _retry() async {
    if (_authenticating || widget.app.sync.busy) return;
    await _completeSync(context, widget.app, widget.app.sync.retryIncomplete());
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.app.sync,
    builder: (context, _) {
      final model = widget.app.sync;
      final theme = Theme.of(context);
      final results = model.results;
      final l10n = context.l10n;
      final app = widget.app;
      final schoolNeedsLogin =
          app.school.username == null || app.school.loginExpired;
      final pendingSchoolTargets = model.incompleteTargets
          .where((target) => target.usesSchoolSession)
          .toList();
      final schoolNeedsAuthentication =
          pendingSchoolTargets.isNotEmpty &&
          (schoolNeedsLogin || app.school.verificationRequired);
      final moocNeedsLogin =
          model.incompleteTargets.contains(SyncTarget.mooc) &&
          app.mooc.needsLogin;
      final canRetry = model.incompleteTargets.any(
        (target) => target.usesSchoolSession
            ? !schoolNeedsAuthentication
            : target == SyncTarget.mooc
            ? !moocNeedsLogin
            : true,
      );
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
            if (model.busy ||
                model.cancelled ||
                canRetry ||
                model.incompleteTargets.isEmpty) ...[
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
            ],
            if (model.busy) ...[
              LinearProgressIndicator(
                value: model.targets.isEmpty
                    ? 0
                    : results.length / model.targets.length,
                minHeight: 3,
              ),
              const SizedBox(height: 12),
            ],
            for (final target in model.targets)
              if (schoolNeedsAuthentication &&
                  pendingSchoolTargets.contains(target)) ...[
                if (target == pendingSchoolTargets.first)
                  _SyncAuthenticationRow(
                    title: l10n.schoolAccount,
                    detail: pendingSchoolTargets
                        .map((target) => target.localizedTitle(l10n))
                        .join(' · '),
                    action: schoolNeedsLogin
                        ? l10n.loginAction
                        : l10n.verifyAction,
                    actionLabel: schoolNeedsLogin
                        ? l10n.schoolLogin
                        : l10n.verifySchoolAccount,
                    onPressed: _authenticating || app.school.busy
                        ? null
                        : () => _authenticate(school: true),
                  ),
              ] else if (target == SyncTarget.mooc && moocNeedsLogin)
                _SyncAuthenticationRow(
                  title: l10n.moocName,
                  detail: app.mooc.status.localizedLabel(l10n),
                  action: l10n.loginAction,
                  actionLabel: l10n.moocLoginTitle,
                  onPressed: _authenticating || app.mooc.busy
                      ? null
                      : () => _authenticate(school: false),
                )
              else
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
            : canRetry
            ? SheetActionBar.primary(
                primary: FilledButton(
                  onPressed: _authenticating ? null : _retry,
                  child: Text(l10n.retryIncomplete),
                ),
              )
            : null,
      );
    },
  );
}

class _SyncAuthenticationRow extends StatelessWidget {
  const _SyncAuthenticationRow({
    required this.title,
    required this.detail,
    required this.action,
    required this.actionLabel,
    required this.onPressed,
  });

  final String title;
  final String detail;
  final String action;
  final String actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minVerticalPadding: 12,
      minLeadingWidth: 20,
      horizontalTitleGap: 14,
      leading: const Icon(Icons.lock_outline_rounded, size: 20),
      title: Text(title, style: theme.textTheme.titleSmall),
      subtitle: Text(
        detail,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: TextButton(
        onPressed: onPressed,
        child: Text(action, semanticsLabel: actionLabel),
      ),
    );
  }
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
