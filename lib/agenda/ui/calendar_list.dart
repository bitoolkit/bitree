import 'package:flutter/material.dart';

import '../../app/controller.dart';
import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../schedule/model.dart';
import '../../schedule/ui/course_detail.dart';
import '../../ui/campus_time_builder.dart';
import '../../ui/design.dart';
import '../../ui/sheet_layout.dart';
import '../calendar.dart';
import '../model.dart';
import 'agenda_detail.dart';
import 'agenda_list_tile.dart';
import 'completion_text.dart';

IconData agendaIcon(AgendaKind kind) => switch (kind) {
  AgendaKind.event => Icons.event_outlined,
  AgendaKind.deadline => Icons.flag_outlined,
  AgendaKind.exam => Icons.edit_note_rounded,
};

Future<void> showAgendaDay(
  BuildContext context,
  AppController controller,
  DateTime date,
) async {
  final l10n = context.l10n;
  final selected = await showModalBottomSheet<AgendaEntry>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => CampusTimeBuilder(
      active: true,
      builder: (context, now) => ListenableBuilder(
        listenable: controller.agenda,
        builder: (context, _) {
          final pending = controller.agenda.pendingOn(date, now: now);
          final completed =
              controller.agenda.entries
                  .where((entry) => entry.done && entry.occursOn(date))
                  .toList()
                ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
          Widget row(AgendaEntry entry) => AgendaListTile(
            key: ValueKey(entry.id),
            controller: controller,
            entry: entry,
            now: now,
            onTap: () => Navigator.pop(context, entry),
          );
          return SafeArea(
            top: false,
            child: SheetLayout(
              header: SheetHeader(
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(localizedAgendaDate(l10n, date)),
                    if (pending.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        l10n.agendaCount(pending.length),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
                actions: const [SheetCloseButton()],
              ),
              content: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final entry in pending) row(entry),
                    if (pending.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                        child: Text(
                          l10n.agendaNoPendingShort,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ),
                    if (completed.isNotEmpty)
                      ExpansionTile(
                        title: Text(
                          l10n.agendaCompletedCount(completed.length),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        shape: const Border(),
                        collapsedShape: const Border(),
                        children: [for (final entry in completed) row(entry)],
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
  if (selected != null && context.mounted) {
    await showAgendaEntry(context, controller, selected);
  }
}

Future<void> openCalendarItem(
  BuildContext context,
  AppController controller,
  CalendarItem item,
) => item.course != null
    ? showCourse(context, controller, item.course!, date: item.startsAt)
    : showAgendaEntry(context, controller, item.entry!);

Future<void> showCalendarItems(
  BuildContext context,
  AppController controller,
  String title,
  List<CalendarItem> items, {
  bool showDates = false,
  String? emptyMessage,
}) async {
  final l10n = context.l10n;
  final selected = await showModalBottomSheet<CalendarItem>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      top: false,
      child: SheetLayout(
        header: SheetHeader(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (items.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  l10n.agendaCount(items.length),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
          actions: const [SheetCloseButton()],
        ),
        content: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < items.length; index++) ...[
                if (index > 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Divider(height: 1),
                  ),
                _CalendarItemRow(
                  item: items[index],
                  now: campusNow(),
                  showDate: showDates,
                  onTap: () => Navigator.pop(context, items[index]),
                ),
              ],
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 20, 12, 28),
                  child: Text(
                    emptyMessage ?? l10n.agendaDayEmpty,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
  if (selected != null && context.mounted) {
    await openCalendarItem(context, controller, selected);
  }
}

class _CalendarItemRow extends StatelessWidget {
  const _CalendarItemRow({
    required this.item,
    required this.now,
    required this.showDate,
    required this.onTap,
  });

  final CalendarItem item;
  final DateTime now;
  final bool showDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final entry = item.entry;
    final overdue = entry?.overdue(now) == true;
    final dueToday =
        entry?.isDeadline == true &&
        !entry!.done &&
        calendarDate(item.startsAt) == calendarDate(now);
    final timeColor = overdue
        ? scheme.error
        : dueToday
        ? scheme.primary
        : scheme.onSurface;
    final captionStyle = theme.textTheme.bodySmall?.copyWith(
      color: overdue
          ? scheme.error
          : dueToday
          ? scheme.primary
          : scheme.onSurfaceVariant,
    );
    final clock = entry == null
        ? clockText(item.startsAt)
        : localizedAgendaClock(l10n, entry);
    final caption = entry == null
        ? l10n.endsAt(clockText(item.endsAt!))
        : localizedAgendaTimeCaption(l10n, entry, now);
    final metadata = [
      entry?.kind.localizedLabel(l10n) ?? l10n.course,
      if (entry?.source case final source?) source.localizedLabel(l10n),
    ].join(' · ');

    Widget time({required bool inline}) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          clock,
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 20,
            height: 1.2,
            color: timeColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (!inline && caption.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(caption, style: captionStyle),
        ],
      ],
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        CompletionText(
          item.title,
          completed: entry?.done == true,
          style: theme.textTheme.titleMedium?.copyWith(fontSize: 17),
        ),
        if (entry?.course.isNotEmpty == true) ...[
          const SizedBox(height: 5),
          Text(
            entry!.course,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        if (item.location.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            item.location,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 7),
        Text(metadata, style: theme.textTheme.bodySmall),
        if (showDate) ...[
          const SizedBox(height: 4),
          Text(
            localizedAgendaDate(l10n, item.startsAt),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 330 ||
            MediaQuery.textScalerOf(context).scale(14) > 20;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppCorners.control,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!stacked) ...[
                    SizedBox(width: 76, child: time(inline: false)),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (stacked) ...[
                          Wrap(
                            spacing: 10,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              time(inline: true),
                              if (caption.isNotEmpty)
                                Text(caption, style: captionStyle),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],
                        content,
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
