import 'package:flutter/material.dart';

import '../../core/time.dart';
import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../ui/app_dialog.dart';
import '../../ui/app_menu_anchor.dart';
import '../../ui/app_notice.dart';
import '../../ui/app_page.dart';
import '../../ui/design.dart';
import '../controller.dart';
import '../model.dart';

part 'deleted_deadlines_components.dart';

Future<void> showDeletedDeadlines(
  BuildContext context,
  AgendaController controller,
) => Navigator.of(context).push<void>(
  MaterialPageRoute<void>(
    builder: (_) => DeletedDeadlinesScreen(controller: controller),
  ),
);

class DeletedDeadlinesScreen extends StatefulWidget {
  const DeletedDeadlinesScreen({super.key, required this.controller});

  final AgendaController controller;

  @override
  State<DeletedDeadlinesScreen> createState() => _DeletedDeadlinesScreenState();
}

class _DeletedDeadlinesScreenState extends State<DeletedDeadlinesScreen> {
  final _selected = <String>{};
  final _search = TextEditingController();
  bool _restoring = false;
  bool _emptying = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _empty(List<AgendaEntry> entries) async {
    final controller = widget.controller;
    if (_emptying ||
        _restoring ||
        entries.isEmpty ||
        !controller.ready ||
        controller.busy) {
      return;
    }

    final l10n = context.l10n;
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.deletedDeadlinesEmptyTitle,
      body: l10n.deletedDeadlinesEmptyConfirm(entries.length),
      confirmLabel: l10n.deletedDeadlinesDeleteForever,
      destructive: true,
    );
    if (!mounted || !confirmed) return;

    setState(() => _emptying = true);
    final emptied = await controller.emptyDeletedDeadlines();
    if (!mounted) return;
    setState(() => _emptying = false);
    if (!emptied) {
      showAppNotice(context, l10n.operationDeleteFailed);
      return;
    }

    showAppNotice(context, l10n.deletedDeadlinesEmptied(entries.length));
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  Future<void> _restore(List<AgendaEntry> entries) async {
    final controller = widget.controller;
    if (_restoring ||
        _emptying ||
        entries.isEmpty ||
        !controller.ready ||
        controller.busy) {
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
    if (!saved) {
      showAppNotice(context, context.l10n.operationRestoreFailed);
      return;
    }

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

  void _setSelected(AgendaEntry entry, bool selected) {
    setState(() {
      if (selected) {
        _selected.add(entry.id);
      } else {
        _selected.remove(entry.id);
      }
    });
  }

  void _toggleVisible(List<AgendaEntry> entries) {
    final ids = {for (final entry in entries) entry.id};
    setState(() {
      if (ids.isNotEmpty && ids.every(_selected.contains)) {
        _selected.removeAll(ids);
      } else {
        _selected.addAll(ids);
      }
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final l10n = context.l10n;
    final controller = widget.controller;
    final entries = controller.deletedDeadlines.toList()
      ..sort((a, b) {
        final time = b.scheduledAt.compareTo(a.scheduledAt);
        return time == 0 ? a.id.compareTo(b.id) : time;
      });
    final query = _search.text.trim().toLowerCase();
    final visible = query.isEmpty
        ? entries
        : entries.where((entry) => _matches(entry, query)).toList();
    final selectedEntries = entries
        .where((entry) => _selected.contains(entry.id))
        .toList();
    final enabled =
        !_restoring && !_emptying && controller.ready && !controller.busy;
    final groups = <DateTime, List<AgendaEntry>>{};
    for (final entry in visible) {
      groups.putIfAbsent(calendarDate(entry.scheduledAt), () => []).add(entry);
    }
    final rows = <({DateTime? day, AgendaEntry? entry})>[
      for (final group in groups.entries) ...[
        (day: group.key, entry: null),
        for (final entry in group.value) (day: null, entry: entry),
      ],
    ];

    return AppRoutePage(
      title: l10n.deletedDeadlinesRecycleBin,
      actions: [
        AppMenuAnchor(
          menuChildren: [
            AppMenuItemButton(
              leadingIcon: Icon(
                Icons.delete_forever_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: enabled && entries.isNotEmpty
                  ? () => _empty(entries)
                  : null,
              child: Text(l10n.deletedDeadlinesEmptyAction),
            ),
          ],
          builder: (context, menu, isOpen) => IconButton(
            tooltip: l10n.more,
            onPressed: () => isOpen ? menu.close() : menu.open(),
            icon: const Icon(Icons.more_horiz_rounded),
          ),
        ),
      ],
      child: entries.isEmpty
          ? _EmptyRecoveryList(
              icon: Icons.delete_sweep_outlined,
              message: l10n.deletedDeadlinesNone,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.xs,
                  ),
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: l10n.deletedDeadlinesSearchHint,
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: l10n.clearSelection,
                              onPressed: () {
                                _search.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                      filled: true,
                      fillColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: AppCorners.control,
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                _RecoverySelectionBar(
                  selectedCount: selectedEntries.length,
                  totalCount: entries.length,
                  visible: visible,
                  selected: _selected,
                  enabled: enabled,
                  onToggleVisible: () => _toggleVisible(visible),
                  onClear: () => setState(_selected.clear),
                ),
                Expanded(
                  child: visible.isEmpty
                      ? _EmptyRecoveryList(
                          icon: Icons.search_off_rounded,
                          message: l10n.deletedDeadlinesNoMatches,
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                          itemCount: rows.length,
                          itemBuilder: (context, index) {
                            final row = rows[index];
                            if (row.entry case final entry?) {
                              return _DeletedDeadlineTile(
                                key: ValueKey(entry.id),
                                entry: entry,
                                selected: _selected.contains(entry.id),
                                enabled: enabled,
                                onChanged: (selected) =>
                                    _setSelected(entry, selected),
                                onRestore: () => _restore([entry]),
                              );
                            }
                            return _RecoveryDateHeader(date: row.day!);
                          },
                        ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: appSheetActionPadding,
                    child: FilledButton.icon(
                      onPressed: enabled && selectedEntries.isNotEmpty
                          ? () => _restore(selectedEntries)
                          : null,
                      icon: _restoring
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.restore_rounded),
                      label: Text(
                        selectedEntries.length == entries.length
                            ? l10n.deletedDeadlinesRestoreAll
                            : l10n.deletedDeadlinesRestoreSelected,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  bool _matches(AgendaEntry entry, String query) {
    final l10n = context.l10n;
    final source = entry.source?.localizedLabel(l10n) ?? l10n.deadlineManual;
    final term = entry.term == null ? '' : localizedTerm(l10n, entry.term!);
    return [
      localizedAgendaTitle(l10n, entry),
      localizedAgendaNotes(l10n, entry),
      entry.course,
      source,
      term,
    ].join(' ').toLowerCase().contains(query);
  }
}
