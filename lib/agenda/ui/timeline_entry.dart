import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/time.dart';
import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../model.dart';
import 'timeline_colors.dart';

/// Renders entry content independently of timeline coordinates and lane packing.
class AgendaTimelineEntry extends StatelessWidget {
  const AgendaTimelineEntry({
    super.key,
    required this.entry,
    required this.now,
    required this.barWidth,
    required this.deadlineWidth,
    required this.onTap,
  });

  final AgendaEntry entry;
  final DateTime now;
  final double barWidth;
  final double deadlineWidth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = agendaTimelineColors(context, entry, now);
    final scale = math.max(
      1.0,
      MediaQuery.textScalerOf(context).scale(14) / 14,
    );
    final date = entry.startsAt;
    final caption = _caption(l10n, entry);
    final titleText = localizedAgendaTitle(l10n, entry);
    final radius = entry.isDeadline ? null : BorderRadius.circular(8);
    final description = l10n.agendaTimelineSemanticsEntry(
      entry.kind.localizedLabel(l10n),
      titleText,
      '${localizedYearMonthDay(l10n, date.year, date.month, date.day)} '
          '${caption.replaceAll('\n', ' ')}',
      '',
      entry.location.isEmpty ? '' : l10n.listSeparator + entry.location,
      '',
    );
    final kindIcon = switch (entry.kind) {
      AgendaKind.event => Icons.event_outlined,
      AgendaKind.exam => Icons.school_outlined,
      AgendaKind.deadline => Icons.flag_outlined,
    };
    final source = entry.course.isNotEmpty
        ? entry.course
        : entry.source?.localizedLabel(l10n) ?? entry.kind.localizedLabel(l10n);
    final title = Text(
      titleText,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: entry.isDeadline ? TextAlign.right : TextAlign.left,
      style: TextStyle(
        fontSize: 14,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: colors.text,
        decoration: entry.done ? TextDecoration.lineThrough : null,
      ),
    );

    return Semantics(
      button: true,
      label: description,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Tooltip(
          message: _preview(l10n, entry, now),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  key: ValueKey(('agenda-timeline-bar', entry.id)),
                  width: barWidth,
                  height: double.infinity,
                  child: Ink(
                    decoration: BoxDecoration(
                      color: entry.isDeadline ? null : colors.fill,
                      gradient: entry.isDeadline
                          ? LinearGradient(
                              colors: [
                                colors.fill.withValues(alpha: 0),
                                colors.fill,
                                colors.fill,
                              ],
                              stops: const [0, 0.35, 1],
                            )
                          : null,
                      borderRadius: radius,
                    ),
                    // Ink includes border widths in its padding. Paint the
                    // outline separately so it never reduces the text space.
                    child: DecoratedBox(
                      position: DecorationPosition.foreground,
                      decoration: BoxDecoration(
                        borderRadius: radius,
                        border: entry.isDeadline
                            ? Border(
                                right: BorderSide(
                                  color: entry.overdue(now)
                                      ? Theme.of(context).colorScheme.error
                                      : colors.accent,
                                  width: 3,
                                ),
                              )
                            : Border.all(color: colors.accent),
                      ),
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: entry.isDeadline ? deadlineWidth * 0.37 : 8,
                          right: 8,
                          top: 4,
                          bottom: 4,
                        ),
                        child: barWidth < 48
                            ? const SizedBox.shrink()
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: entry.isDeadline
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  if (entry.isDeadline)
                                    title
                                  else
                                    Row(
                                      children: [
                                        Icon(
                                          kindIcon,
                                          size: 13 * scale,
                                          color: colors.text,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(child: title),
                                      ],
                                    ),
                                  if (entry.isDeadline)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          entry.done
                                              ? Icons.check_circle_outline
                                              : entry.overdue(now)
                                              ? Icons.warning_amber_rounded
                                              : kindIcon,
                                          size: 13 * scale,
                                          color: colors.text,
                                        ),
                                        const SizedBox(width: 3),
                                        Flexible(
                                          child: Text(
                                            source,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              height: 1.1,
                                              color: colors.text,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  const SizedBox(height: 2),
                                  Text(
                                    caption,
                                    maxLines: entry.isDeadline ? 1 : 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: entry.isDeadline
                                        ? TextAlign.right
                                        : TextAlign.left,
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.2,
                                      fontWeight: FontWeight.w600,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                      color: colors.accent,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _day(DateTime date) => '${date.month}/${date.day}';

String _caption(AppLocalizations l10n, AgendaEntry entry) {
  if (entry.isDeadline) {
    return entry.allDay ? l10n.allDayUntil : l10n.dueAt(clockText(entry.dueAt));
  }
  final end = entry.endsAt!;
  if (entry.allDay) {
    final lastDay = end.subtract(const Duration(days: 1));
    return calendarDate(lastDay) == calendarDate(entry.startsAt)
        ? l10n.allDay
        : '${_day(entry.startsAt)}–${_day(lastDay)}\n${l10n.allDay}';
  }
  if (calendarDate(entry.startsAt) == calendarDate(end)) {
    return '${clockText(entry.startsAt)}–${clockText(end)}';
  }
  return '${_day(entry.startsAt)} ${clockText(entry.startsAt)}\n'
      '→ ${_day(end)} ${clockText(end)}';
}

String _fullDate(AppLocalizations l10n, DateTime date) =>
    '${dateText(date)} ${localizedShortWeekday(l10n, date.weekday)}';
String _fullTime(AppLocalizations l10n, DateTime date) =>
    '${_fullDate(l10n, date)} ${clockText(date)}';

String _preview(AppLocalizations l10n, AgendaEntry entry, DateTime now) => [
  '${entry.kind.localizedLabel(l10n)} · ${localizedAgendaTitle(l10n, entry)}',
  if (entry.isDeadline)
    entry.allDay
        ? l10n.agendaTimelineDue(
            '${_fullDate(l10n, entry.startsAt)} '
            '${l10n.agendaDueBeforeEndOfDay}',
          )
        : l10n.agendaTimelineDue(_fullTime(l10n, entry.dueAt))
  else if (entry.allDay) ...[
    l10n.agendaTimelineStarts(
      '${_fullDate(l10n, entry.startsAt)} ${l10n.allDay}',
    ),
    l10n.agendaTimelineEnds(
      '${_fullDate(l10n, entry.endsAt!.subtract(const Duration(days: 1)))} '
      '${l10n.allDay}',
    ),
  ] else ...[
    l10n.agendaTimelineStarts(_fullTime(l10n, entry.startsAt)),
    l10n.agendaTimelineEnds(_fullTime(l10n, entry.endsAt!)),
  ],
  if (entry.course.isNotEmpty) l10n.agendaTimelineCourse(entry.course),
  if (entry.location.isNotEmpty) l10n.agendaTimelineLocation(entry.location),
  if (entry.done)
    l10n.agendaTimelineStatusCompleted
  else if (entry.overdue(now))
    l10n.agendaTimelineStatusOverdue
  else if (entry.isFinished(now))
    l10n.agendaTimelineStatusEnded,
].join('\n');
