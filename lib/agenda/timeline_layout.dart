import 'model.dart';

/// Stable lane reservation plus the current zoom's actual painted bounds.
class AgendaTimelinePlacement {
  const AgendaTimelinePlacement({
    required this.entry,
    required this.lane,
    required this.start,
    required this.end,
    required this.layoutEnd,
    required this.paintStart,
    required this.paintEnd,
  });

  final AgendaEntry entry;
  final int lane;
  final DateTime start;
  final DateTime end;
  final DateTime layoutEnd;
  final DateTime paintStart;
  final DateTime paintEnd;
}

typedef _LaneReservation = ({
  AgendaEntry entry,
  int lane,
  DateTime start,
  DateTime end,
  DateTime layoutEnd,
});

/// Reserve the full feature intervals once; zoom only projects paint geometry.
/// In particular a fixed-width information card never changes an entry's lane.
class AgendaTimelineLayout {
  AgendaTimelineLayout(
    Iterable<AgendaEntry> entries, {
    required Duration minimumEventSpan,
    required this.deadlineCardSpan,
    int layoutDays = AgendaEntry.defaultTailDays,
  }) : _reservations = _reserveLanes(
         entries,
         minimumEventSpan: minimumEventSpan,
         layoutDays: layoutDays,
       );

  final Duration deadlineCardSpan;
  final List<_LaneReservation> _reservations;

  List<AgendaTimelinePlacement> atZoom(double zoom) {
    if (!zoom.isFinite || zoom < 1) {
      throw RangeError.value(zoom, 'zoom', 'Must be finite and at least one');
    }
    final fixedWidthSpan = Duration(
      microseconds: (deadlineCardSpan.inMicroseconds / zoom).ceil(),
    );
    return [
      for (final interval in _reservations)
        AgendaTimelinePlacement(
          entry: interval.entry,
          lane: interval.lane,
          start: interval.start,
          end: interval.end,
          layoutEnd: interval.layoutEnd,
          paintStart: interval.entry.startOnly
              ? interval.entry.startsAt
              : (interval.entry.isDeadline
                        ? interval.entry.dueAt
                        : interval.entry.startsAt)
                    .subtract(fixedWidthSpan),
          paintEnd: interval.entry.startOnly
              ? interval.entry.startsAt.add(fixedWidthSpan)
              : interval.end,
        ),
    ];
  }
}

/// Compatibility entry point for pure layout consumers. Reservations keep their
/// real times; callers displaying a viewport should retain AgendaTimelineLayout
/// and use atZoom rather than reassigning lanes for every zoom value.
List<AgendaTimelinePlacement> layoutAgendaTimeline(
  Iterable<AgendaEntry> entries, {
  required Duration minimumEventSpan,
  int layoutDays = AgendaEntry.defaultTailDays,
}) => AgendaTimelineLayout(
  entries,
  minimumEventSpan: minimumEventSpan,
  deadlineCardSpan: Duration(
    microseconds: (Duration.microsecondsPerDay * (layoutDays - .25)).round(),
  ),
  layoutDays: layoutDays,
).atZoom(1);

List<_LaneReservation> _reserveLanes(
  Iterable<AgendaEntry> entries, {
  required Duration minimumEventSpan,
  required int layoutDays,
}) {
  if (layoutDays < 1 || layoutDays > AgendaEntry.maxTailDays) {
    throw RangeError.range(layoutDays, 1, AgendaEntry.maxTailDays, 'layoutDays');
  }
  DateTime reservationStart(AgendaEntry entry) => entry.startOnly
      ? entry.startsAt
      : (entry.isDeadline ? entry.dueAt : entry.startsAt)
            .subtract(Duration(days: layoutDays));
  DateTime reservationEnd(AgendaEntry entry) => entry.isDeadline
      ? entry.startOnly
            ? entry.startsAt.add(Duration(days: layoutDays))
            : entry.realDueAt
      : entry.endsAt!;
  final intervals = [
    for (final entry in entries.where((entry) => !entry.deleted))
      (entry: entry, start: reservationStart(entry), end: reservationEnd(entry)),
  ]..sort((a, b) {
    final byStart = a.start.compareTo(b.start);
    if (byStart != 0) return byStart;
    final byEnd = a.end.compareTo(b.end);
    return byEnd != 0 ? byEnd : a.entry.id.compareTo(b.entry.id);
  });
  final laneEnds = <DateTime>[];
  final reservations = <_LaneReservation>[];
  for (final interval in intervals) {
    final minimumEnd = interval.entry.startsAt.add(minimumEventSpan);
    final layoutEnd =
        !interval.entry.isDeadline && interval.end.isBefore(minimumEnd)
        ? minimumEnd
        : interval.end;
    var lane = laneEnds.indexWhere((end) => !interval.start.isBefore(end));
    if (lane < 0) {
      lane = laneEnds.length;
      laneEnds.add(layoutEnd);
    } else {
      laneEnds[lane] = layoutEnd;
    }
    reservations.add((
      entry: interval.entry,
      lane: lane,
      start: interval.start,
      end: interval.end,
      layoutEnd: layoutEnd,
    ));
  }
  return reservations;
}
