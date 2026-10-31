import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/controller.dart';
import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../mooc/ui/mooc_sheet.dart';
import '../../school/ui/school_screen.dart';
import '../../school/ui/school_verification_dialog.dart';
import '../../ui/app_notice.dart';
import '../../ui/design.dart';
import '../../ui/section_label.dart';
import '../../ui/selection_controls.dart';
import '../../ui/sheet_layout.dart';
import '../controller.dart';
import 'sync_text.dart';

final _progressSheets = <SyncController, Future<void>>{};

/// Starts one round silently. Only account authentication requires a page.
Future<bool> startSync(
  BuildContext context,
  AppController app, {
  Set<SyncTarget>? targets,
  String? term,
}) async {
  if (app.sync.busy) {
    await showSyncProgress(context, app);
    return false;
  }
  final selected = targets ?? app.sync.defaultTargets;
  if (selected.isEmpty) return false;
  final school = selected
      .where((target) => target.usesSchoolSession)
      .firstOrNull;
  if (school != null &&
      (app.school.username == null || app.school.loginExpired)) {
    if (await openSchoolLogin(context, app, source: school.source) != true ||
        !context.mounted) {
      return false;
    }
  }
  if (!context.mounted) return false;
  if (selected.contains(SyncTarget.mooc) && app.mooc.needsLogin) {
    if (!await showMoocAccount(context, app.mooc) || !context.mounted) {
      return false;
    }
  }
  if (!context.mounted) return false;
  final overlay = Overlay.of(context, rootOverlay: true);
  final l10n = context.l10n;
  final success = await app.sync.synchronize(selected, term: term, l10n: l10n);
  if (!overlay.mounted ||
      app.sync.cancelled ||
      _progressSheets.containsKey(app.sync)) {
    return success;
  }
  showOverlayNotice(
    overlay,
    success ? l10n.syncComplete : l10n.syncPartial,
    action: success
        ? null
        : (
            label: l10n.view,
            onPressed: () {
              if (overlay.mounted) {
                unawaited(showSyncProgress(overlay.context, app));
              }
            },
          ),
  );
  return success;
}

Future<void> customizeSync(BuildContext context, AppController app) async {
  final selected = await showAppSheet<Set<SyncTarget>>(
    context: context,
    builder: (_) => _CustomSyncSheet(app: app),
  );
  if (selected == null || !context.mounted) return;
  await startSync(context, app, targets: selected);
}

Future<void> showSyncProgress(BuildContext context, AppController app) {
  final existing = _progressSheets[app.sync];
  if (existing != null) return existing;
  dismissAppNotice();
  final sheet = showAppSheet<void>(
    context: context,
    builder: (_) => _SyncProgressSheet(app: app),
  );
  _progressSheets[app.sync] = sheet;
  return sheet.whenComplete(() => _progressSheets.remove(app.sync));
}

class _CustomSyncSheet extends StatefulWidget {
  const _CustomSyncSheet({required this.app});
  final AppController app;
  @override
  State<_CustomSyncSheet> createState() => _CustomSyncSheetState();
}

class _CustomSyncSheetState extends State<_CustomSyncSheet> {
  late final _availableTargets = widget.app.sync.bulkTargets;
  late final _selected = widget.app.sync.defaultTargets;

  @override
  Widget build(BuildContext context) => SheetLayout(
    header: SheetHeader(
      title: Text(context.l10n.customSync),
      actions: const [SheetCloseButton()],
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSelectionBar(
          selectedCount: _selected.length,
          totalCount: _availableTargets.length,
          summary: context.l10n.selectedItems(_selected.length),
          onSelectAll: () =>
              setState(() => _selected.addAll(_availableTargets)),
          onClear: () => setState(_selected.clear),
        ),
        const SizedBox(height: AppSpacing.md),
        AppSectionHeader(context.l10n.syncSchoolData),
        _SyncTargetChoices(
          targets: _availableTargets.where(
            (target) => target.category == SyncCategory.schoolData,
          ),
          selected: _selected,
          onChanged: _setSelected,
        ),
        const SizedBox(height: AppSpacing.md),
        AppSectionHeader(context.l10n.syncDeadlineData),
        _SyncTargetChoices(
          targets: _availableTargets.where(
            (target) => target.category == SyncCategory.deadlineData,
          ),
          selected: _selected,
          onChanged: _setSelected,
        ),
        if (_selected.contains(SyncTarget.mooc) &&
            widget.app.mooc.needsLogin) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.login_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  context.l10n.loginAfterSelection,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ],
    ),
    actions: FilledButton(
      onPressed: _selected.isEmpty
          ? null
          : () => Navigator.pop(context, _selected),
      child: Text(context.l10n.syncSelected),
    ),
  );

  void _setSelected(SyncTarget target, bool checked) {
    setState(() {
      if (checked) {
        _selected.add(target);
      } else {
        _selected.remove(target);
      }
    });
  }
}

class _SyncTargetChoices extends StatelessWidget {
  const _SyncTargetChoices({
    required this.targets,
    required this.selected,
    required this.onChanged,
  });

  final Iterable<SyncTarget> targets;
  final Set<SyncTarget> selected;
  final void Function(SyncTarget target, bool checked) onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final target in targets)
        AppSelectionTile(
          value: selected.contains(target),
          title: Text(target.localizedTitle(context.l10n)),
          onChanged: (checked) => onChanged(target, checked ?? false),
        ),
    ],
  );
}

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
      if (selected.any((target) => target.usesSchoolSession) &&
          app.school.verificationRequired) {
        final verified = await app.school.restoreAccount(
          verify: (request) => verifySchoolLogin(context, request),
        );
        if (!verified || !mounted) return;
      }
      if (!mounted) return;
      await startSync(context, app, targets: selected, term: term);
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
            ? FilledButton(
                onPressed: _authenticating ? null : _retry,
                child: Text(
                  _authenticating ? l10n.verifying : l10n.retryIncomplete,
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
