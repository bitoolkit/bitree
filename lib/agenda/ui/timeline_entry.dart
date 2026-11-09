import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/time.dart';
import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../model.dart';
import 'adjusted_deadline_painter.dart';
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
    this.adjustedGeometry,
  });

  final AgendaEntry entry;
  final DateTime now;
  final double barWidth;
  final double deadlineWidth;
  final VoidCallback onTap;
  final AdjustedDeadlineGeometry? adjustedGeometry;

  @override
  Widget build(BuildContext context) {
    final body = _buildBody(context);
    final geometry = adjustedGeometry;
    if (geometry == null) return body;
    final colors = agendaTimelineColors(context, entry, now);
    return AdjustedDeadlineSurface(
      key: ValueKey(('agenda-timeline-adjusted', entry.id)),
      geometry: geometry,
      bodyWidth: deadlineWidth,
      fill: colors.fill,
      // colors.accent already includes the ordinary completed alpha. Applying
      // another half gives 0.5 when pending and 0.25 when completed.
      realMarkerColor: colors.accent.withValues(alpha: colors.accent.a * 0.5),
      body: body,
      onTap: onTap,
      semanticsLabel: _preview(context.l10n, entry, now),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final colors = agendaTimelineColors(context, entry, now);
    final overdue = entry.overdue(now);
    final scale = math.max(
      1.0,
      MediaQuery.textScalerOf(context).scale(14) / 14,
    );
    final date = entry.scheduledAt;
    final caption = _caption(l10n, entry);
    final overdueCaption = l10n.agendaReminderOverdue(
      entry.effectiveAllDay ? l10n.allDay : clockText(entry.dueAt),
    );
    final warningBackground = scheme.errorContainer;
    final warningForeground = scheme.onErrorContainer;
    final deadlineFill = overdue ? warningBackground : colors.fill;
    final contentColor = overdue ? warningForeground : colors.text;
    final titleText = localizedAgendaTitle(l10n, entry);
    // An open-ended deadline mirrors the ordinary deadline card: the accent
    // line becomes its left edge, the fill fades out towards the right, and
    // the text hugs the line on the left instead of the right.
    final openEnded = entry.isDeadline && entry.startOnly;
    final accentEdge = BorderSide(
      color: overdue ? scheme.error : colors.accent,
      width: 3,
    );
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
      textAlign: entry.isDeadline && !openEnded
          ? TextAlign.right
          : TextAlign.left,
      style: TextStyle(
        fontSize: 14,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: contentColor,
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
                              colors: openEnded
                                  ? [
                                      deadlineFill,
                                      deadlineFill,
                                      deadlineFill.withValues(alpha: 0),
                                    ]
                                  : [
                                      deadlineFill.withValues(alpha: 0),
                                      deadlineFill,
                                      deadlineFill,
                                    ],
                              stops: openEnded
                                  ? const [0, 0.82, 1]
                                  : const [0, 0.18, 1],
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
                            ? openEnded
                                  ? Border(left: accentEdge)
                                  : Border(right: accentEdge)
                            : Border.all(color: colors.accent),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (overdue)
                            Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Icon(
                                  key: ValueKey((
                                    'agenda-timeline-overdue-watermark',
                                    entry.id,
                                  )),
                                  Icons.warning_amber_rounded,
                                  size: 56 * scale,
                                  color: warningForeground.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              ),
                            ),
                          Padding(
                            padding: EdgeInsets.only(
                              left: entry.isDeadline && !openEnded
                                  ? deadlineWidth * 0.37
                                  : 8,
                              right: openEnded ? deadlineWidth * 0.37 : 8,
                              top: 4,
                              bottom: 4,
                            ),
                            child: barWidth < 48
                                ? const SizedBox.shrink()
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        entry.isDeadline && !openEnded
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
                                                  : kindIcon,
                                              size: 13 * scale,
                                              color: contentColor,
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
                                                  color: contentColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      const SizedBox(height: 2),
                                      if (overdue)
                                        _OverdueStatusBadge(
                                          key: ValueKey((
                                            'agenda-timeline-overdue-status',
                                            entry.id,
                                          )),
                                          label: overdueCaption,
                                        )
                                      else
                                        Text(
                                          caption,
                                          maxLines: entry.isDeadline ? 1 : 2,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: entry.isDeadline &&
                                                  !openEnded
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
    );
  }
}

class _OverdueStatusBadge extends StatelessWidget {
  const _OverdueStatusBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.error,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 11, color: scheme.onError),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: scheme.onError,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _day(DateTime date) => '${date.month}/${date.day}';

String _caption(AppLocalizations l10n, AgendaEntry entry) {
  if (entry.isDeadline) {
    // An open-ended deadline has no due time, so it reports when it opened.
    if (entry.startOnly) {
      return l10n.agendaTimelineStarts(clockText(entry.startsAt));
    }
    if (entry.hasAdjustedDeadline) {
      return '${clockText(entry.dueAt)} ${l10n.agendaAdjustedDeadline}';
    }
    return entry.effectiveAllDay
        ? l10n.allDayUntil
        : l10n.dueAt(clockText(entry.dueAt));
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

/// The date line of a deadline preview. Open-ended deadlines never claim a
/// time is due; they state when the task opened instead.
String _previewDeadlineLine(AppLocalizations l10n, AgendaEntry entry) {
  if (entry.hasDeadlineCutoff) {
    return [
      l10n.agendaCutoffAdjusted(_fullTime(l10n, entry.dueAt)),
      l10n.agendaCutoffOriginal(_fullTime(l10n, entry.realDueAt)),
    ].join('\n');
  }
  if (entry.startOnly) {
    return l10n.agendaTimelineStarts(
      entry.allDay
          ? '${_fullDate(l10n, entry.startsAt)} ${l10n.allDay}'
          : _fullTime(l10n, entry.startsAt),
    );
  }
  if (entry.allDay) {
    return l10n.agendaTimelineDue(
      '${_fullDate(l10n, entry.startsAt)} ${l10n.agendaDueBeforeEndOfDay}',
    );
  }
  return l10n.agendaTimelineDue(_fullTime(l10n, entry.dueAt));
}

String _preview(AppLocalizations l10n, AgendaEntry entry, DateTime now) => [
  '${entry.kind.localizedLabel(l10n)} · ${localizedAgendaTitle(l10n, entry)}',
  if (entry.isDeadline) _previewDeadlineLine(l10n, entry)
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
