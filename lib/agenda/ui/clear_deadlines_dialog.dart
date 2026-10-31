import 'package:flutter/material.dart';

import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../ui/app_notice.dart';
import '../../ui/selection_controls.dart';
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
  final count = await showDialog<int>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ClearDeadlinesDialog(agenda: agenda),
  );
  if (!context.mounted || count == null) return;
  showAppNotice(context, context.l10n.clearDeadlinesDeleted(count));
}

class _ClearDeadlinesDialog extends StatefulWidget {
  const _ClearDeadlinesDialog({required this.agenda});

  final AgendaController agenda;

  @override
  State<_ClearDeadlinesDialog> createState() => _ClearDeadlinesDialogState();
}

class _ClearDeadlinesDialogState extends State<_ClearDeadlinesDialog> {
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
        child: AlertDialog(
          title: Text(l10n.clearDeadlinesTitle),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.clearDeadlinesIntro),
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
              Text(
                l10n.clearDeadlinesWarning,
                style: TextStyle(color: scheme.error),
              ),
              const SizedBox(height: 8),
              Text(l10n.clearDeadlinesRecovery),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            FilledButton(
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
          ],
        ),
      );
    },
  );
}
