import 'package:flutter/material.dart';

import '../../core/time.dart';
import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../model.dart';
import 'adjusted_deadline_painter.dart';
import 'timeline_colors.dart';

/// All coordinates are relative to a viewport-bounded card surface.
class EventTimelineGeometry {
  const EventTimelineGeometry({
    required this.informationLeft,
    required this.startX,
    required this.endX,
  });

  final double informationLeft;
  final double startX;
  final double endX;
}

/// Width of the start/end indicator lines; the hidden card's painted surface
/// extends by this much left of the real start so the indicator stays visible.
const double eventTimelineLineWidth = 3;

/// Event information has the same fixed screen width as a DDL tail. The actual
/// event interval retains its time-scaled width, independently of the text.
class EventTimelinePainter extends CustomPainter {
  const EventTimelinePainter({
    required this.geometry,
    required this.fill,
    required this.accent,
    this.lineWidth = eventTimelineLineWidth,
    this.showInformation = true,
  });

  final EventTimelineGeometry geometry;
  final Color fill;
  final Color accent;
  final double lineWidth;
  final bool showInformation;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final information = Rect.fromLTRB(
      geometry.informationLeft, 0, geometry.startX, size.height,
    );
    if (showInformation) {
      // Palette alpha already contains completion fading. Multiply the stripe
      // bands without replacing (and losing) the existing alpha.
      AdjustedDeadlineExtensionPainter(
        effectiveX: geometry.informationLeft,
        realX: geometry.startX,
        color: fill,
        highOpacity: 1,
        lowOpacity: .5,
      ).paint(canvas, size);
      final borderWidth = lineWidth / 2;
      if (information.width >= borderWidth && size.height >= borderWidth) {
        canvas.drawRect(
          information.deflate(borderWidth / 2),
          Paint()
            ..color = accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = borderWidth,
        );
      }
    }
    // The real interval alternates whole fill and accent bands, the first
    // band being the fill anchored at the start line.
    AdjustedDeadlineExtensionPainter(
      effectiveX: geometry.startX,
      realX: geometry.endX,
      color: fill,
      secondColor: accent,
    ).paint(canvas, size);
    for (final x in [geometry.startX, geometry.endX]) {
      canvas.drawRect(
        Rect.fromLTRB(x - lineWidth, 0, x, size.height),
        Paint()..color = accent,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(EventTimelinePainter oldDelegate) =>
      oldDelegate.geometry.informationLeft != geometry.informationLeft ||
      oldDelegate.geometry.startX != geometry.startX ||
      oldDelegate.geometry.endX != geometry.endX ||
      oldDelegate.fill != fill ||
      oldDelegate.accent != accent ||
      oldDelegate.lineWidth != lineWidth ||
      oldDelegate.showInformation != showInformation;
}

class EventTimelineEntry extends StatefulWidget {
  const EventTimelineEntry({
    super.key,
    required this.entry,
    required this.now,
    required this.geometry,
    required this.informationWidth,
    required this.onTap,
    this.showInformation = true,
  });

  final AgendaEntry entry;
  final DateTime now;
  final EventTimelineGeometry geometry;
  final double informationWidth;
  final VoidCallback onTap;

  /// Hides the left information card's text, stripes and inner border. The
  /// real interval, its fill and both boundary lines always stay painted.
  final bool showInformation;

  @override
  State<EventTimelineEntry> createState() => _EventTimelineEntryState();
}

class _EventTimelineEntryState extends State<EventTimelineEntry> {
  Widget? _information;

  AgendaEntry get entry => widget.entry;
  DateTime get now => widget.now;
  EventTimelineGeometry get geometry => widget.geometry;
  double get informationWidth => widget.informationWidth;
  void _open() => widget.onTap();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _information = null;
  }

  @override
  void didUpdateWidget(covariant EventTimelineEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry != widget.entry ||
        oldWidget.now != widget.now ||
        oldWidget.informationWidth != widget.informationWidth) {
      _information = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = agendaTimelineColors(context, entry, now);
    final overdue = entry.overdue(now);
    final title = localizedAgendaTitle(l10n, entry);
    final preview = [
      '${entry.kind.localizedLabel(l10n)} · $title',
      l10n.agendaTimelineStarts(localizedAgendaDateTime(l10n, entry.startsAt)),
      l10n.agendaTimelineEnds(localizedAgendaDateTime(l10n, entry.endsAt!)),
      if (entry.course.isNotEmpty) l10n.agendaTimelineCourse(entry.course),
      if (entry.location.isNotEmpty) l10n.agendaTimelineLocation(entry.location),
      if (entry.done) l10n.agendaTimelineStatusCompleted
      else if (overdue) l10n.agendaTimelineStatusOverdue,
    ].join('\n');
    final caption = overdue
        ? l10n.agendaReminderOverdue(clockText(entry.endsAt!))
        : _eventCaption(l10n, entry);
    final semantics = l10n.agendaTimelineSemanticsEntry(
      entry.kind.localizedLabel(l10n),
      title,
      '${localizedAgendaDateTime(l10n, entry.startsAt)} '
          '${_eventCaption(l10n, entry).replaceAll('\n', ' ')}',
      entry.course.isEmpty ? '' : l10n.listSeparator + entry.course,
      entry.location.isEmpty ? '' : l10n.listSeparator + entry.location,
      entry.done
          ? l10n.listSeparator + l10n.agendaTimelineStatusCompleted
          : overdue
          ? l10n.listSeparator + l10n.agendaTimelineStatusOverdue
          : '',
    );
    return Semantics(
      button: true,
      label: semantics,
      onTap: _open,
      child: ExcludeSemantics(
        child: Tooltip(
          message: preview,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _open,
            child: ClipRect(
              child: CustomPaint(
                painter: EventTimelinePainter(
                  geometry: geometry,
                  fill: colors.fill,
                  accent: colors.accent,
                  showInformation: widget.showInformation,
                ),
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    if (widget.showInformation)
                      Positioned(
                        left: geometry.informationLeft,
                        top: 0,
                        bottom: 0,
                        width: informationWidth,
                        child: _information ??= RepaintBoundary(
                          child: SizedBox(
                            key: ValueKey(('agenda-timeline-bar', entry.id)),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.2,
                                      fontWeight: FontWeight.w600,
                                      color: colors.text,
                                      decoration: entry.done
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    caption,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.2,
                                      fontWeight: FontWeight.w600,
                                      color: colors.accent,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _eventCaption(AppLocalizations l10n, AgendaEntry entry) {
  String day(DateTime value) => '${value.month}/${value.day}';
  final end = entry.endsAt!;
  if (entry.allDay) {
    final last = end.subtract(const Duration(days: 1));
    return calendarDate(last) == calendarDate(entry.startsAt)
        ? l10n.allDay
        : '${day(entry.startsAt)}–${day(last)}\n${l10n.allDay}';
  }
  if (calendarDate(entry.startsAt) == calendarDate(end)) {
    return '${clockText(entry.startsAt)}–${clockText(end)}';
  }
  return '${day(entry.startsAt)} ${clockText(entry.startsAt)}\n'
      '→ ${day(end)} ${clockText(end)}';
}
