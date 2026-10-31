import 'package:flutter/material.dart';

import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../ui/app_notice.dart';
import '../../ui/design.dart';
import '../../ui/selection_controls.dart';
import '../../ui/sheet_layout.dart';
import '../controller.dart';
import '../model.dart';

Future<void> showDeletedDeadlines(
  BuildContext context,
  AgendaController controller,
) => showAppSheet<void>(
  context: context,
  builder: (_) => _DeletedDeadlinesSheet(controller: controller),
);

class _DeletedDeadlinesSheet extends StatefulWidget {
  const _DeletedDeadlinesSheet({required this.controller});

  final AgendaController controller;

  @override
  State<_DeletedDeadlinesSheet> createState() => _DeletedDeadlinesSheetState();
}

class _DeletedDeadlinesSheetState extends State<_DeletedDeadlinesSheet> {
  final _selected = <String>{};
  bool _restoring = false;

  Future<void> _restore(List<AgendaEntry> entries) async {
    final controller = widget.controller;
    if (_restoring || entries.isEmpty || !controller.ready || controller.busy) {
      return;
    }
    final restoringAll = entries.length == controller.deletedDeadlines.length;
    final restoredIds = {for (final entry in entries) entry.id};
    setState(() => _restoring = true);
    final saved = await controller.restoreEntries(entries);
    if (!mounted) return;
    setState(() {
      _restoring = false;
      if (saved) _selected.removeAll(restoredIds);
    });
    if (!saved) return;

    final l10n = context.l10n;
    final message = switch (entries.length) {
      1 => l10n.deletedDeadlinesRestored(entries.single.title),
      _ when restoringAll => l10n.deletedDeadlinesRestoredAll,
      _ => l10n.deletedDeadlinesRestoredCount(entries.length),
    };
    showAppNotice(context, message);
    if (controller.deletedDeadlines.isEmpty && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final l10n = context.l10n;
      final controller = widget.controller;
      final entries = controller.deletedDeadlines.toList()
        ..sort((a, b) {
          final time = b.startsAt.compareTo(a.startsAt);
          return time == 0 ? a.id.compareTo(b.id) : time;
        });
      final visibleIds = {for (final entry in entries) entry.id};
      final selectedEntries = entries
          .where((entry) => _selected.contains(entry.id))
          .toList();
      final enabled = !_restoring && controller.ready && !controller.busy;

      return SheetLayout(
        header: SheetHeader(
          title: Text(l10n.deletedDeadlinesTitle),
          actions: const [SheetCloseButton()],
        ),
        contentPadding: appSheetListPadding,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                child: Text(
                  l10n.deletedDeadlinesNone,
                  textAlign: TextAlign.center,
                ),
              )
            else ...[
              AppSelectionBar(
                selectedCount: selectedEntries.length,
                totalCount: entries.length,
                summary: l10n.selectedItems(selectedEntries.length),
                enabled: enabled,
                onSelectAll: () => setState(() => _selected.addAll(visibleIds)),
                onClear: () => setState(_selected.clear),
              ),
              const SizedBox(height: AppSpacing.xs),
              for (final entry in entries)
                AppSelectionTile(
                  key: ValueKey(entry.id),
                  value: _selected.contains(entry.id),
                  enabled: enabled,
                  title: Text(
                    entry.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(_entrySubtitle(context, entry)),
                  onChanged: (checked) => setState(() {
                    if (checked == true) {
                      _selected.add(entry.id);
                    } else {
                      _selected.remove(entry.id);
                    }
                  }),
                  trailing: IconButton(
                    tooltip: l10n.deletedDeadlinesRestoreAction,
                    onPressed: enabled ? () => _restore([entry]) : null,
                    icon: const Icon(Icons.restore_rounded, size: 20),
                  ),
                ),
            ],
          ],
        ),
        actions: entries.isEmpty
            ? null
            : SheetActionBar(
                children: [
                  FilledButton.icon(
                    onPressed: enabled && selectedEntries.isNotEmpty
                        ? () => _restore(selectedEntries)
                        : null,
                    icon: const Icon(Icons.restore_rounded, size: 18),
                    label: Text(
                      selectedEntries.length == entries.length
                          ? l10n.deletedDeadlinesRestoreAll
                          : l10n.deletedDeadlinesRestoreSelected,
                    ),
                  ),
                ],
              ),
      );
    },
  );

  String _entrySubtitle(BuildContext context, AgendaEntry entry) {
    final l10n = context.l10n;
    final source = [
      entry.source?.localizedLabel(l10n) ?? l10n.deadlineManual,
      if (entry.course.isNotEmpty) entry.course,
    ].join('  ');
    final time =
        '${localizedAgendaDate(l10n, entry.startsAt)} '
        '${localizedAgendaTime(l10n, entry)}';
    return '$source\n$time';
  }
}
