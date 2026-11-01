import 'package:flutter/material.dart';

import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../ui/app_notice.dart';
import '../../ui/design.dart';
import '../../ui/selection_controls.dart';
import '../../ui/sheet_layout.dart';
import '../controller.dart';
import '../deadline_clear_scope.dart';

Future<void> showClearDeadlines(
  BuildContext context,
  AgendaController agenda,
) async {
  if (!agenda.ready || agenda.busy) {
    showAppNotice(context, context.l10n.clearDeadlinesUnavailable);
    return;
  }
  final count = await showAppSheet<int>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => _ClearDeadlinesSheet(agenda: agenda),
  );
  if (!context.mounted || count == null) return;
  showAppNotice(context, context.l10n.clearDeadlinesDeleted(count));
}

class _ClearDeadlinesSheet extends StatefulWidget {
  const _ClearDeadlinesSheet({required this.agenda});

  final AgendaController agenda;

  @override
  State<_ClearDeadlinesSheet> createState() => _ClearDeadlinesSheetState();
}

class _ClearDeadlinesSheetState extends State<_ClearDeadlinesSheet> {
  final _selected = <DeadlineClearScope>{};
  bool _saving = false;

  Future<void> _clear(
    Set<DeadlineClearScope> scopes,
    Set<String> expectedIds,
  ) async {
    if (_saving || scopes.isEmpty || expectedIds.isEmpty) return;
    final agenda = widget.agenda;
    if (!agenda.ready || agenda.busy) {
      showAppNotice(context, context.l10n.clearDeadlinesUnavailable);
      return;
    }
    setState(() => _saving = true);
    final cleared = await agenda.clearDeadlines(
      scopes,
      expectedIds: expectedIds,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (cleared) Navigator.pop<int>(context, expectedIds.length);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.agenda,
    builder: (context, _) {
      final l10n = context.l10n;
      final agenda = widget.agenda;
      final scheme = Theme.of(context).colorScheme;
      final enabled = !_saving && agenda.ready && !agenda.busy;
      final scopes = Set<DeadlineClearScope>.of(_selected);
      final expectedIds = agenda.deadlineIdsIn(scopes);
      final count = expectedIds.length;
      return PopScope(
        canPop: !_saving,
        child: SheetLayout(
          header: SheetHeader(
            title: Text(l10n.clearDeadlinesTitle),
            actions: [SheetCloseButton(enabled: !_saving)],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.clearDeadlinesIntro),
              const SizedBox(height: AppSpacing.md),
              AppSelectionBar(
                selectedCount: scopes.length,
                totalCount: DeadlineClearScope.values.length,
                summary: l10n.clearDeadlinesSelection(scopes.length, count),
                enabled: enabled,
                onSelectAll: () =>
                    setState(() => _selected.addAll(DeadlineClearScope.values)),
                onClear: () => setState(_selected.clear),
              ),
              for (final scope in DeadlineClearScope.values)
                AppSelectionTile(
                  title: Text(
                    l10n.clearDeadlinesSourceCount(
                      scope.localizedLabel(l10n),
                      agenda.countDeadlines(scope),
                    ),
                  ),
                  subtitle: Text(scope.localizedDescription(l10n)),
                  value: _selected.contains(scope),
                  onChanged: enabled
                      ? (checked) => setState(() {
                          if (checked == true) {
                            _selected.add(scope);
                          } else {
                            _selected.remove(scope);
                          }
                        })
                      : null,
                ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.clearDeadlinesWarning,
                style: TextStyle(color: scheme.error),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.clearDeadlinesRecovery),
            ],
          ),
          actions: SheetActionBar.split(
            leading: TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            primary: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: enabled && scopes.isNotEmpty && count > 0
                  ? () => _clear(scopes, expectedIds)
                  : null,
              child: Text(
                _saving
                    ? l10n.clearDeadlinesDeleting
                    : l10n.clearDeadlinesDeleteCount(count),
              ),
            ),
          ),
        ),
      );
    },
  );
}
