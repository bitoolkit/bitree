import 'package:flutter/material.dart';

import '../../app/controller.dart';
import '../../app/ui/add_menu.dart';
import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../schedule/model.dart';
import '../../sync/ui/sync_button.dart';
import '../../ui/app_menu_anchor.dart';
import '../../ui/app_menu_trigger.dart';
import '../../ui/app_page.dart';
import '../../ui/pull_to_reveal_list.dart';
import '../model.dart';
import '../view_mode.dart';
import 'agenda_list_tile.dart';
import 'agenda_timeline.dart';
import 'deleted_deadlines.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    required this.controller,
    required this.now,
    this.active = true,
  });

  final AppController controller;
  final DateTime now;
  final bool active;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  AgendaKind? _kind;
  int _status = 0;

  void _setStatus(int index) {
    if (_status != index) setState(() => _status = index);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.controller.agenda,
      widget.controller.school,
      widget.controller.timetable,
      widget.controller.agendaViewMode,
    ]),
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final l10n = context.l10n;
    final controller = widget.controller;
    final now = widget.now;
    final scheme = Theme.of(context).colorScheme;
    final entries = controller.agenda.entries
        .where((entry) => _kind == null || entry.kind == _kind)
        .toList();
    final doneCount = entries.where((entry) => entry.isFinished(now)).length;
    final deletedDeadlineCount = controller.agenda.deletedDeadlines.length;
    final timeline = controller.agendaViewMode.value == AgendaViewMode.timeline;

    Widget loadStatus() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!controller.agenda.ready && controller.agenda.busy)
          const LinearProgressIndicator(minHeight: 3),
        if (!controller.agenda.ready && !controller.agenda.busy)
          TextButton.icon(
            onPressed: controller.agenda.load,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(l10n.agendaReload),
          ),
      ],
    );

    Widget statusHeader() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: 0,
                label: Text(
                  l10n.agendaPendingTab(entries.length - doneCount),
                  textAlign: TextAlign.center,
                ),
              ),
              ButtonSegment(
                value: 1,
                label: Text(
                  l10n.agendaCompletedTab(doneCount),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            selected: {_status},
            onSelectionChanged: (selection) => _setStatus(selection.single),
          ),
        ),
        loadStatus(),
      ],
    );

    return AppPage(
      title: Row(
        children: [
          Text(l10n.agendaTitle),
          const SizedBox(width: 8),
          Flexible(
            child: _AgendaKindFilter(
              value: _kind,
              onChanged: (kind) => setState(() => _kind = kind),
            ),
          ),
        ],
      ),
      actions: [
        AddButton(controller: controller),
        SyncButton(controller: controller),
        if (deletedDeadlineCount > 0)
          IconButton(
            tooltip: l10n.deletedDeadlinesTitle,
            onPressed: controller.agenda.busy
                ? null
                : () => showDeletedDeadlines(context, controller.agenda),
            icon: Badge.count(
              count: deletedDeadlineCount,
              backgroundColor: scheme.primary,
              textColor: scheme.onPrimary,
              child: const Icon(Icons.restore_from_trash_outlined),
            ),
          ),
        IconButton(
          tooltip: timeline
              ? l10n.agendaSwitchToList
              : l10n.agendaSwitchToTimeline,
          icon: Icon(
            timeline ? Icons.view_list_outlined : Icons.view_timeline_outlined,
          ),
          onPressed: () => controller.setAgendaViewMode(
            timeline ? AgendaViewMode.list : AgendaViewMode.timeline,
          ),
        ),
      ],
      // Keep browsing positions while changing presentation or completion
      // filter. Horizontal gestures belong to rows or timeline navigation.
      child: IndexedStack(
        index: timeline ? 1 : 0,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              statusHeader(),
              Expanded(
                child: IndexedStack(
                  index: _status,
                  children: [
                    for (var index = 0; index < 2; index++)
                      _AgendaStatusList(
                        key: ValueKey((_kind, index)),
                        controller: controller,
                        entries: entries,
                        completed: index == 1,
                        now: now,
                      ),
                  ],
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              loadStatus(),
              Expanded(
                child: AgendaTimeline(
                  controller: controller,
                  entries: entries,
                  now: now,
                  active: widget.active,
                  visible: timeline,
                ),
              ),
            ],
          ),
        ],
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

  final AppController controller;
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
        if (days.isEmpty && controller.agenda.ready)
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
          Semantics(
            selected: value == kind,
            child: AppMenuItemButton(
              onPressed: () => onChanged(kind),
              trailingIcon: value == kind
                  ? const Icon(Icons.check_rounded, size: 18)
                  : const SizedBox(width: 18),
              child: Text(kind?.localizedLabel(l10n) ?? l10n.all),
            ),
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
