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
/// Live entries per [AgendaEntry.timelinePriority] are placed first, so they
/// claim the top lanes whenever they compete with finished ones; finished
/// entries then backfill any hole in an existing lane before opening a new
/// lane at the bottom.
class AgendaTimelineLayout {
  AgendaTimelineLayout(
    Iterable<AgendaEntry> entries, {
    required Duration minimumEventSpan,
    required Duration deadlineCardSpan,
    required DateTime now,
    int layoutDays = AgendaEntry.defaultTailDays,
    bool reserveEventInformation = true,
  }) : this._reserved(
         deadlineCardSpan,
         layoutDays,
         reserveEventInformation,
         _reserveLanes(
           entries,
           minimumEventSpan: minimumEventSpan,
           layoutDays: layoutDays,
           reserveEventInformation: reserveEventInformation,
           now: now,
         ),
       );

  AgendaTimelineLayout._reserved(
    this.deadlineCardSpan,
    this._layoutDays,
    this.reserveEventInformation,
    this._reservations,
  );

  /// Adopts new instances of the same entries while keeping this exact lane
  /// plan. An in-place status change (done, notes, colour) must not reshuffle
  /// lanes; the caller guarantees the structural fields are unchanged.
  AgendaTimelineLayout reboundTo(Iterable<AgendaEntry> entries) {
    final byId = {for (final entry in entries) entry.id: entry};
    return AgendaTimelineLayout._reserved(
      deadlineCardSpan,
      _layoutDays,
      reserveEventInformation,
      [
        for (final reservation in _reservations)
          (
            entry: byId[reservation.entry.id] ?? reservation.entry,
            lane: reservation.lane,
            start: reservation.start,
            end: reservation.end,
            layoutEnd: reservation.layoutEnd,
          ),
      ],
    );
  }

  final Duration deadlineCardSpan;
  final int _layoutDays;

  /// When the event information card is hidden, events reserve and paint only
  /// their real interval instead of an information-width lead on the left.
  final bool reserveEventInformation;
  final List<_LaneReservation> _reservations;

  List<AgendaTimelinePlacement> atZoom(double zoom) {
    if (!zoom.isFinite || zoom < 1) {
      throw RangeError.value(zoom, 'zoom', 'Must be finite and at least one');
    }
    Duration fixedWidthSpan(AgendaEntry entry) => Duration(
      microseconds:
          (deadlineCardSpan.inMicroseconds *
                  (entry.effectiveLayoutDays(_layoutDays) - .25) /
                  (_layoutDays - .25) /
                  zoom)
              .ceil(),
    );
    return [
      for (final interval in _reservations)
        AgendaTimelinePlacement(
          entry: interval.entry,
          lane: interval.lane,
          start: interval.start,
          end: interval.end,
          layoutEnd: interval.layoutEnd,
          paintStart:
              interval.entry.startOnly ||
                  (!interval.entry.isDeadline && !reserveEventInformation)
              ? interval.entry.startsAt
              : (interval.entry.isDeadline
                        ? interval.entry.dueAt
                        : interval.entry.startsAt)
                    .subtract(fixedWidthSpan(interval.entry)),
          paintEnd: interval.entry.startOnly
              ? interval.entry.startsAt.add(fixedWidthSpan(interval.entry))
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
  required DateTime now,
  int layoutDays = AgendaEntry.defaultTailDays,
  bool reserveEventInformation = true,
}) => AgendaTimelineLayout(
  entries,
  minimumEventSpan: minimumEventSpan,
  deadlineCardSpan: Duration(
    microseconds: (Duration.microsecondsPerDay * (layoutDays - .25)).round(),
  ),
  now: now,
  layoutDays: layoutDays,
  reserveEventInformation: reserveEventInformation,
).atZoom(1);

List<_LaneReservation> _reserveLanes(
  Iterable<AgendaEntry> entries, {
  required Duration minimumEventSpan,
  required int layoutDays,
  required bool reserveEventInformation,
  required DateTime now,
}) {
  if (layoutDays < AgendaEntry.minTailDays ||
      layoutDays > AgendaEntry.maxTailDays) {
    throw RangeError.range(
      layoutDays,
      AgendaEntry.minTailDays,
      AgendaEntry.maxTailDays,
      'layoutDays',
    );
  }
  DateTime reservationStart(AgendaEntry entry) =>
      entry.startOnly || (!entry.isDeadline && !reserveEventInformation)
      ? entry.startsAt
      : (entry.isDeadline ? entry.dueAt : entry.startsAt).subtract(
          Duration(days: entry.effectiveLayoutDays(layoutDays)),
        );
  DateTime reservationEnd(AgendaEntry entry) => entry.isDeadline
      ? entry.startOnly
            ? entry.startsAt.add(
                Duration(days: entry.effectiveLayoutDays(layoutDays)),
              )
            : entry.realDueAt
      : entry.endsAt!;
  final intervals =
      [
        for (final entry in entries.where((entry) => !entry.deleted))
          (
            entry: entry,
            priority: entry.timelinePriority(now),
            start: reservationStart(entry),
            end: reservationEnd(entry),
          ),
      ]..sort((a, b) {
        // Live entries reserve lanes first; time order only breaks ties
        // within one priority class.
        if (a.priority != b.priority) return a.priority ? -1 : 1;
        final byStart = a.start.compareTo(b.start);
        if (byStart != 0) return byStart;
        final byEnd = a.end.compareTo(b.end);
        return byEnd != 0 ? byEnd : a.entry.id.compareTo(b.entry.id);
      });
  // Per lane, every reserved span already placed there in start order. Live
  // entries are processed first in ascending starts, where "first lane with a
  // gap" degenerates into the classic "first free lane tail". Finished entries
  // then backfill any earlier hole they fit into — only when no lane has one
  // do they open a new lane below everything.
  final lanes = <List<_LaneSpan>>[];
  final reservations = <_LaneReservation>[];
  for (final interval in intervals) {
    final minimumEnd = interval.entry.startsAt.add(minimumEventSpan);
    final layoutEnd =
        !interval.entry.isDeadline && interval.end.isBefore(minimumEnd)
        ? minimumEnd
        : interval.end;
    var lane = -1;
    var insertion = 0;
    for (var index = 0; index < lanes.length; index++) {
      insertion = _insertionPoint(lanes[index], interval.start);
      if (!_collides(lanes[index], insertion, interval.start, layoutEnd)) {
        lane = index;
        break;
      }
    }
    if (lane < 0) {
      lane = lanes.length;
      lanes.add([]);
      insertion = 0;
    }
    lanes[lane].insert(insertion, (start: interval.start, end: layoutEnd));
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

/// A reserved collision span `[start, layoutEnd]` inside one lane.
typedef _LaneSpan = ({DateTime start, DateTime end});

/// The index after the last span starting at or before [start].
int _insertionPoint(List<_LaneSpan> spans, DateTime start) {
  var low = 0;
  var high = spans.length;
  while (low < high) {
    final mid = (low + high) ~/ 2;
    if (!spans[mid].start.isAfter(start)) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  return low;
}

/// Touching endpoints are free, mirroring the tail comparison this planner
/// replaces: a span may start exactly where its neighbour's layout ends.
bool _collides(
  List<_LaneSpan> spans,
  int insertion,
  DateTime start,
  DateTime end,
) {
  if (insertion > 0 && spans[insertion - 1].end.isAfter(start)) return true;
  if (insertion < spans.length && end.isAfter(spans[insertion].start)) {
    return true;
  }
  return false;
}
