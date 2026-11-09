import 'package:flutter/material.dart';

import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../schedule/controller.dart';
import '../../schedule/ui/conflicting_courses.dart';
import '../../schedule/ui/course_tile.dart';
import '../../ui/course_palette.dart';
import '../../ui/design.dart';
import '../calendar.dart';
import '../controller.dart';
import '../model.dart';
import 'agenda_color_palette.dart';
import 'calendar_list.dart';

class CalendarBlockTile extends StatelessWidget {
  const CalendarBlockTile({
    super.key,
    required this.items,
    required this.timetable,
    required this.agenda,
    required this.isToday,
    this.courseProgress,
  });

  final List<CalendarItem> items;
  final TimetableController timetable;
  final AgendaController agenda;
  final bool isToday;
  final double? courseProgress;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (items.every((item) => item.course != null)) {
      return items.length == 1
          ? CourseTile(
              course: items.single.course!,
              controller: timetable,
              isToday: isToday,
              date: items.single.startsAt,
              progress: courseProgress,
            )
          : ConflictingCourses(
              courses: items.map((item) => item.course!).toList(),
              controller: timetable,
              isToday: isToday,
              date: items.first.startsAt,
            );
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final exam = items.any((item) => item.entry?.kind == AgendaKind.exam);
    final customColors = items.length == 1 && items.single.entry?.color != null
        ? agendaColorValues(theme.colorScheme, items.single.entry!.color!)
        : null;
    final palette = agendaPaletteColors(theme);
    // The outline carries contrast for subtle fills in both palette modes.
    final background = exam
        ? scheme.errorContainer
        : customColors != null
        ? customColors.fill
        : palette == null
        ? scheme.primaryContainer
        : Color(palette.fill);
    final foreground = exam
        ? scheme.onErrorContainer
        : customColors != null
        ? customColors.text
        : palette == null
        ? scheme.onPrimaryContainer
        : Color(palette.text);
    final outline = exam
        ? scheme.error
        : customColors != null
        ? customColors.accent
        : palette == null
        ? scheme.primary
        : Color(palette.accent);
    final summary = items
        .map(
          (item) =>
              '${item.entry?.kind.localizedLabel(l10n) ?? l10n.course} '
              '${localizedCalendarItemTitle(l10n, item)}\n'
              '${item.entry == null ? localizedCourseTime(l10n, item.course!) : localizedAgendaTime(l10n, item.entry!)}',
        )
        .join('\n');
    return Semantics(
      button: true,
      label: summary,
      child: Tooltip(
        triggerMode: TooltipTriggerMode.manual,
        message: summary,
        child: Material(
          color: background,
          shape: RoundedRectangleBorder(
            borderRadius: AppCorners.compact,
            side: BorderSide(color: outline, width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => items.length == 1
                ? openCalendarItem(context, timetable, agenda, items.single)
                : showCalendarItems(
                    context,
                    timetable,
                    agenda,
                    l10n.agendaChooseItems,
                    items,
                  ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final scale = MediaQuery.textScalerOf(context).scale(1);
                if (constraints.maxHeight < 40 * scale ||
                    constraints.maxWidth < 20) {
                  if (constraints.maxHeight < 15 * scale ||
                      constraints.maxWidth < 4) {
                    return const SizedBox.expand();
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Center(
                      child: Text(
                        items
                            .map(
                              (item) => localizedCalendarItemTitle(l10n, item),
                            )
                            .join(' / '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.25,
                          color: foreground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }
                final detailed = constraints.maxHeight >= 90 * scale;
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (constraints.maxHeight >= 48 * scale &&
                          (exam || items.length > 1)) ...[
                        Text(
                          items.length == 1
                              ? l10n.exam
                              : l10n.agendaItemCount(items.length),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            height: 1.2,
                            color: foreground,
                          ),
                        ),
                        const SizedBox(height: 3),
                      ],
                      Flexible(
                        child: Text(
                          items
                              .map(
                                (item) =>
                                    localizedCalendarItemTitle(l10n, item),
                              )
                              .join(' / '),
                          textAlign: TextAlign.start,
                          maxLines: detailed ? 4 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                            color: foreground,
                          ),
                        ),
                      ),
                      if (detailed &&
                          items.length == 1 &&
                          items.single.location.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          items.single.location,
                          textAlign: TextAlign.start,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.2,
                            color: foreground,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
