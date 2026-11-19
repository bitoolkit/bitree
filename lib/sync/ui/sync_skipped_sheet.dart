part of 'sync.dart';

class _SyncSkippedUpdatesSheet extends StatefulWidget {
  const _SyncSkippedUpdatesSheet({required this.app});

  final AppController app;

  @override
  State<_SyncSkippedUpdatesSheet> createState() =>
      _SyncSkippedUpdatesSheetState();
}

class _SyncSkippedUpdatesSheetState extends State<_SyncSkippedUpdatesSheet> {
  final _selectedKeys = <String>{};
  bool _applying = false;

  Future<void> _overwrite(List<SyncSkippedUpdate> updates) async {
    final chosen = [
      for (final item in updates)
        if (_selectedKeys.contains(item.key)) item,
    ];
    if (_applying || chosen.isEmpty) return;
    final l10n = context.l10n;
    final overlay = Overlay.of(context, rootOverlay: true);
    setState(() => _applying = true);
    final success = await widget.app.sync.overwriteSkipped(chosen);
    if (!mounted) return;
    setState(() {
      _applying = false;
      final remainingKeys = {
        for (final item in widget.app.sync.skippedUpdates) item.key,
      };
      _selectedKeys.removeWhere((key) => !remainingKeys.contains(key));
    });
    if (!success) {
      if (overlay.mounted) {
        showOverlayNotice(overlay, l10n.syncResultSaveFailed);
      }
      return;
    }
    if (overlay.mounted) {
      showOverlayNotice(overlay, l10n.syncOverwrittenCount(chosen.length));
    }
    if (widget.app.sync.skippedUpdates.isEmpty) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.app.sync,
    builder: (context, _) {
      final l10n = context.l10n;
      final theme = Theme.of(context);
      final updates = widget.app.sync.skippedUpdates;
      final validKeys = {for (final item in updates) item.key};
      final selectedCount = _selectedKeys.where(validKeys.contains).length;
      final targets = <SyncTarget>[];
      for (final item in updates) {
        if (!targets.contains(item.target)) targets.add(item.target);
      }
      final showSections = targets.length > 1;

      return SheetLayout(
        header: SheetHeader(
          title: Text(l10n.syncSkippedTitle),
          actions: [SheetCloseButton(enabled: !_applying)],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSelectionBar(
              selectedCount: selectedCount,
              totalCount: updates.length,
              summary: l10n.selectedItems(selectedCount),
              onToggleAll: _applying
                  ? null
                  : (selectAll) => setState(() {
                      if (selectAll) {
                        _selectedKeys
                          ..clear()
                          ..addAll(validKeys);
                      } else {
                        _selectedKeys.clear();
                      }
                    }),
              onClear: _applying || selectedCount == 0
                  ? null
                  : () => setState(_selectedKeys.clear),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final (groupIndex, target) in targets.indexed) ...[
              if (showSections) ...[
                if (groupIndex > 0) const SizedBox(height: AppSpacing.sm),
                AppSectionHeader(target.localizedTitle(l10n)),
              ],
              for (final item in updates.where(
                (value) => value.target == target,
              ))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: AppSelectionTile(
                  value: _selectedKeys.contains(item.key),
                  enabled: !_applying,
                  title: Text(
                    _skippedItemTitle(l10n, item),
                    style: theme.textTheme.titleSmall,
                  ),
                  subtitle: Text(
                    _skippedItemDiffs(l10n, item).join('\n'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  onChanged: (checked) => setState(() {
                    if (checked == true) {
                      _selectedKeys.add(item.key);
                    } else {
                      _selectedKeys.remove(item.key);
                    }
                  }),
                ),
                ),
            ],
          ],
        ),
        actions: SheetActionBar.split(
          leading: TextButton(
            onPressed: _applying ? null : () => Navigator.pop(context),
            child: Text(l10n.syncKeepLocal),
          ),
          primary: FilledButton(
            onPressed: _applying || selectedCount == 0
                ? null
                : () => _overwrite(updates),
            child: Text(
              _applying ? l10n.saving : l10n.syncOverwriteSelected,
            ),
          ),
        ),
      );
    },
  );
}

String _skippedItemTitle(AppLocalizations l10n, SyncSkippedUpdate item) =>
    switch (item) {
      SyncSkippedAgendaUpdate(:final update) => _agendaTitle(l10n, update),
      SyncSkippedCourseUpdate(:final update) => update.saved.name,
    };

String _agendaTitle(AppLocalizations l10n, SkippedAgendaUpdate update) {
  final title = localizedAgendaTitle(l10n, update.saved);
  final course = update.saved.course.trim();
  if (course.isEmpty || course == title) return title;
  return '$title · $course';
}

List<String> _skippedItemDiffs(AppLocalizations l10n, SyncSkippedUpdate item) =>
    switch (item) {
      SyncSkippedAgendaUpdate(:final update) => _agendaDiffs(l10n, update),
      SyncSkippedCourseUpdate(:final update) => _courseDiffs(l10n, update),
    };

List<String> _agendaDiffs(AppLocalizations l10n, SkippedAgendaUpdate update) {
  final saved = update.saved;
  final incoming = update.incoming;
  final savedTitle = localizedAgendaTitle(l10n, saved);
  final incomingTitle = localizedAgendaTitle(l10n, incoming);
  return [
    if (savedTitle != incomingTitle)
      l10n.syncDiffTitle(savedTitle, incomingTitle),
    if (update.timeChanged)
      l10n.syncDiffTime(
        _compactAgendaTime(l10n, saved),
        _compactAgendaTime(l10n, incoming),
      ),
    if (update.doneChanged)
      l10n.syncDiffDone(
        saved.done ? l10n.syncValueDone : l10n.syncValuePending,
        incoming.done ? l10n.syncValueDone : l10n.syncValuePending,
      ),
    if (update.locationChanged)
      l10n.syncDiffLocation(
        _valueOrEmpty(l10n, saved.location),
        _valueOrEmpty(l10n, incoming.location),
      ),
    if (update.notesChanged) l10n.syncDiffNotes,
  ];
}

List<String> _courseDiffs(AppLocalizations l10n, SkippedCourseUpdate update) {
  final saved = update.saved;
  final incoming = update.incoming;
  return [
    if (update.nameChanged) l10n.syncDiffTitle(saved.name, incoming.name),
    if (update.timeChanged)
      l10n.syncDiffTime(
        _compactCourseSlot(l10n, saved),
        _compactCourseSlot(l10n, incoming),
      ),
    if (update.weeksChanged)
      l10n.syncDiffWeeks(
        localizedWeeks(l10n, saved.weeks),
        localizedWeeks(l10n, incoming.weeks),
      ),
    if (update.roomChanged)
      l10n.syncDiffLocation(
        _valueOrEmpty(l10n, saved.room),
        _valueOrEmpty(l10n, incoming.room),
      ),
    if (update.teacherChanged)
      l10n.syncDiffTeacher(
        _valueOrEmpty(l10n, saved.teacher),
        _valueOrEmpty(l10n, incoming.teacher),
      ),
  ];
}

String _compactAgendaTime(AppLocalizations l10n, AgendaEntry entry) {
  final day = localizedMonthDay(l10n, entry.startsAt.month, entry.startsAt.day);
  if (entry.allDay) return '$day ${l10n.allDay}';
  final start = '$day ${clockText(entry.startsAt)}';
  if (entry.isDeadline) return start;
  final end = entry.endsAt!;
  final endText = calendarDate(entry.startsAt) == calendarDate(end)
      ? clockText(end)
      : '${localizedMonthDay(l10n, end.month, end.day)} ${clockText(end)}';
  return '$start–$endText';
}

String _compactCourseSlot(AppLocalizations l10n, Course course) {
  final day = course.weekday == null
      ? l10n.syncValueEmpty
      : localizedShortWeekday(l10n, course.weekday!);
  return '$day ${localizedCourseSection(l10n, course)}';
}

String _valueOrEmpty(AppLocalizations l10n, String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? l10n.syncValueEmpty : trimmed;
}
