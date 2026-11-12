part of 'calendar_screen.dart';

class _AgendaOverflowMenu extends StatelessWidget {
  const _AgendaOverflowMenu({
    required this.terms,
    required this.currentTerm,
    required this.selectedTerm,
    required this.onTermChanged,
    required this.timeline,
    required this.deletedDeadlineCount,
    required this.deletedDeadlinesEnabled,
    required this.onViewModeChanged,
    required this.onOpenDeletedDeadlines,
  });

  final List<String> terms;
  final String? currentTerm;
  final String? selectedTerm;
  final ValueChanged<String?> onTermChanged;
  final bool timeline;
  final int deletedDeadlineCount;
  final bool deletedDeadlinesEnabled;
  final VoidCallback onViewModeChanged;
  final VoidCallback onOpenDeletedDeadlines;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final orderedTerms = orderedSemesterTerms(terms, currentTerm: currentTerm);
    final values = <String?>[...orderedTerms, null];

    return AppMenuAnchor(
      menuChildren: [
        AppMenuItemButton(
          leadingIcon: Icon(
            timeline ? Icons.view_list_outlined : Icons.view_timeline_outlined,
          ),
          onPressed: onViewModeChanged,
          child: Text(
            timeline ? l10n.agendaSwitchToList : l10n.agendaSwitchToTimeline,
          ),
        ),
        if (deletedDeadlineCount > 0)
          AppMenuItemButton(
            leadingIcon: const Icon(Icons.restore_from_trash_outlined),
            trailingIcon: Text('$deletedDeadlineCount'),
            onPressed: deletedDeadlinesEnabled ? onOpenDeletedDeadlines : null,
            child: Text(l10n.deletedDeadlinesRecycleBin),
          ),
        const Divider(height: 9),
        for (final term in values)
          AppMenuItemButton(
            selected: selectedTerm == term,
            onPressed: () => onTermChanged(term),
            child: Text(
              term == null ? l10n.allSemesters : localizedTerm(l10n, term),
            ),
          ),
      ],
      builder: (context, menu, isOpen) => IconButton(
        tooltip: l10n.more,
        onPressed: () => isOpen ? menu.close() : menu.open(),
        icon: const Icon(Icons.more_horiz_rounded),
      ),
    );
  }
}

class _AgendaStatusList extends StatelessWidget {
  const _AgendaStatusList({
    super.key,
    required this.controller,
    required this.entries,
    required this.completed,
    required this.now,
  });

  final AgendaController controller;
  final List<AgendaEntry> entries;
  final bool completed;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final visible =
        entries.where((entry) => entry.isFinished(now) == completed).toList()
          ..sort((a, b) {
            final time = a.startsAt.compareTo(b.startsAt);
            final order = time == 0 ? a.id.compareTo(b.id) : time;
            return completed ? -order : order;
          });
    final days = <DateTime, List<AgendaEntry>>{};
    final overdueDays = <DateTime, List<AgendaEntry>>{};
    for (final entry in visible) {
      final group = entry.overdue(now) ? overdueDays : days;
      group.putIfAbsent(calendarDate(entry.startsAt), () => []).add(entry);
    }

    List<Widget> dayRows(Map<DateTime, List<AgendaEntry>> groups) => [
      for (final day in groups.entries) ...[
        _AgendaDateHeading(
          key: ValueKey(('day', day.key)),
          date: day.key,
          now: now,
        ),
        for (final entry in day.value)
          AgendaListTile(
            key: ValueKey(entry.id),
            controller: controller,
            entry: entry,
            now: now,
          ),
      ],
    ];

    final overdueCount = overdueDays.values.fold(
      0,
      (count, entries) => count + entries.length,
    );

    return PullToRevealList(
      hiddenLabel: l10n.agendaOverdueHiddenLabel(overdueCount),
      hiddenChildren: dayRows(overdueDays),
      children: [
        if (days.isEmpty && controller.ready)
          Padding(
            key: const ValueKey('empty-state'),
            padding: const EdgeInsets.symmetric(vertical: 64),
            child: Center(
              child: Text(
                completed
                    ? l10n.agendaNoCompleted
                    : overdueCount > 0
                    ? l10n.agendaNoUpcoming
                    : l10n.agendaNoPending,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ...dayRows(days),
      ],
    );
  }
}

class _AgendaKindFilter extends StatelessWidget {
  const _AgendaKindFilter({required this.value, required this.onChanged});

  final AgendaKind? value;
  final ValueChanged<AgendaKind?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return AppMenuAnchor(
      menuChildren: [
        for (final kind in [
          null,
          AgendaKind.deadline,
          AgendaKind.event,
          AgendaKind.exam,
        ])
          AppMenuItemButton(
            selected: value == kind,
            onPressed: () => onChanged(kind),
            child: Text(kind?.localizedLabel(l10n) ?? l10n.all),
          ),
      ],
      builder: (context, menu, isOpen) => AppMenuTrigger(
        label: value?.localizedLabel(l10n) ?? l10n.all,
        semanticsLabel: l10n.agendaType,
        isOpen: isOpen,
        foregroundColor: value == null
            ? scheme.onSurfaceVariant
            : scheme.primary,
        onPressed: () => isOpen ? menu.close() : menu.open(),
      ),
    );
  }
}

class _AgendaDateHeading extends StatelessWidget {
  const _AgendaDateHeading({super.key, required this.date, required this.now});

  final DateTime date;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final days = date.difference(calendarDate(now)).inDays;
    final label = switch (days) {
      0 => l10n.today,
      1 => l10n.tomorrow,
      -1 => l10n.yesterday,
      _ => localizedWeekday(l10n, date.weekday),
    };
    final dateLabel = date.year == now.year
        ? localizedMonthDay(l10n, date.month, date.day)
        : localizedYearMonthDay(l10n, date.year, date.month, date.day);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: label,
              style: TextStyle(
                color: days == 0 ? scheme.primary : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextSpan(
              text: '  $dateLabel',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        style: const TextStyle(fontSize: 13),
      ),
    );
  }
}
