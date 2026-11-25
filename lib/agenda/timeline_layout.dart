import 'dart:math' as math;

import '../core/time.dart';
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
    required this.paintedWidthDays,
  });

  final AgendaEntry entry;
  final int lane;
  final DateTime start;
  final DateTime end;
  final DateTime layoutEnd;
  final DateTime paintStart;
  final DateTime paintEnd;

  /// Screen-space baseline days occupied by the card's fixed-width body
  /// (DDL tail or event/exam left information bar).
  final double paintedWidthDays;
}

/// Smoothly compacted vertical lane geometry for the current horizontal window.
class CompactedTimelineLanes {
  const CompactedTimelineLanes({
    required this.laneTops,
    required this.laneWeights,
    required this.totalHeight,
  });

  final List<double> laneTops;
  final List<double> laneWeights;
  final double totalHeight;
}

typedef _LaneReservation = ({
  AgendaEntry entry,
  int lane,
  DateTime start,
  DateTime end,
  DateTime layoutEnd,
  double paintedWidthDays,
});

/// Reserve the full feature intervals once; zoom only projects paint geometry.
/// In particular a fixed-width information card never changes an entry's lane.
/// Live exams claim the top lanes first, followed by other live entries
/// (keeping simultaneous same-course/same-window clusters contiguous), and
/// finished entries backfill any earlier hole before opening a new lane.
class AgendaTimelineLayout {
  AgendaTimelineLayout(
    Iterable<AgendaEntry> entries, {
    required Duration minimumEventSpan,
    required Duration deadlineCardSpan,
    required DateTime now,
    int layoutDays = AgendaEntry.defaultTailDays,
    bool reserveEventInformation = true,
    Map<String, double> eventInfoDays = const {},
  }) : this._reserved(
         deadlineCardSpan,
         layoutDays,
         reserveEventInformation,
         _reserveLanes(
           entries,
           minimumEventSpan: minimumEventSpan,
           layoutDays: layoutDays,
           reserveEventInformation: reserveEventInformation,
           eventInfoDays: eventInfoDays,
           now: now,
         ),
       );

  AgendaTimelineLayout._reserved(
    this.deadlineCardSpan,
    this._layoutDays,
    this.reserveEventInformation,
    this._reservations,
  );

  /// Default painted width (in baseline days) for an event or exam's left
  /// information card when the caller does not pass measured per-entry widths.
  static const defaultEventInfoDays = 2.25;

  /// Visual gutter (in baseline days, ~4px on phones) left of a bordered
  /// event/exam information card so adjacent cards never kiss.
  static const eventInfoGutterDays = 0.08;

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
            paintedWidthDays: reservation.paintedWidthDays,
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
    Duration fixedWidthSpan(double paintedDays) => Duration(
      microseconds:
          (deadlineCardSpan.inMicroseconds *
                  paintedDays /
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
          paintedWidthDays: interval.paintedWidthDays,
          paintStart:
              interval.entry.startOnly ||
                  (!interval.entry.isDeadline && !reserveEventInformation)
              ? interval.entry.startsAt
              : (interval.entry.isDeadline
                        ? interval.entry.dueAt
                        : interval.entry.startsAt)
                    .subtract(fixedWidthSpan(interval.paintedWidthDays)),
          paintEnd: interval.entry.startOnly
              ? interval.entry.startsAt.add(
                  fixedWidthSpan(interval.paintedWidthDays),
                )
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
  Map<String, double> eventInfoDays = const {},
}) => AgendaTimelineLayout(
  entries,
  minimumEventSpan: minimumEventSpan,
  deadlineCardSpan: Duration(
    microseconds: (Duration.microsecondsPerDay * (layoutDays - .25)).round(),
  ),
  now: now,
  layoutDays: layoutDays,
  reserveEventInformation: reserveEventInformation,
  eventInfoDays: eventInfoDays,
).atZoom(1);

/// Collapses trailing empty lanes below the lowest active lane near
/// `[left, right]` with smoothstep feathering across [featherSpan].
///
/// A suffix maximum keeps every lane above an active lane at full height so
/// visible cards never shift vertically while panning horizontally, while
/// trailing blank height below the active lanes still collapses smoothly.
CompactedTimelineLanes compactTimelineLanes(
  List<AgendaTimelinePlacement> placements, {
  required DateTime left,
  required DateTime right,
  required Duration featherSpan,
  required double laneHeight,
}) {
  var laneCount = 0;
  for (final placement in placements) {
    if (placement.lane + 1 > laneCount) laneCount = placement.lane + 1;
  }
  if (laneCount == 0) {
    return const CompactedTimelineLanes(
      laneTops: [],
      laneWeights: [],
      totalHeight: 0,
    );
  }
  final weights = List<double>.filled(laneCount, 0.0);
  final featherUs = featherSpan.inMicroseconds;
  for (final placement in placements) {
    final double weight;
    if (placement.paintEnd.isAfter(left) &&
        placement.paintStart.isBefore(right)) {
      weight = 1.0;
    } else if (featherUs > 0) {
      final gapUs = !placement.paintEnd.isAfter(left)
          ? left.difference(placement.paintEnd).inMicroseconds
          : placement.paintStart.difference(right).inMicroseconds;
      if (gapUs < featherUs) {
        final t = 1.0 - gapUs / featherUs;
        weight = t * t * (3.0 - 2.0 * t);
      } else {
        weight = 0.0;
      }
    } else {
      weight = 0.0;
    }
    if (weight > weights[placement.lane]) {
      weights[placement.lane] = weight;
    }
  }
  var suffixMax = 0.0;
  for (var index = laneCount - 1; index >= 0; index--) {
    if (weights[index] > suffixMax) {
      suffixMax = weights[index];
    } else {
      weights[index] = suffixMax;
    }
  }
  final tops = List<double>.filled(laneCount, 0.0);
  var y = 0.0;
  for (var index = 0; index < laneCount; index++) {
    tops[index] = y;
    y += weights[index] * laneHeight;
  }
  return CompactedTimelineLanes(
    laneTops: tops,
    laneWeights: weights,
    totalHeight: y,
  );
}

typedef _CandidateInterval = ({
  AgendaEntry entry,
  int tier,
  DateTime start,
  DateTime end,
  DateTime layoutEnd,
  double paintedWidthDays,
});

int _timelineTier(AgendaEntry entry, DateTime now) {
  if (!entry.timelinePriority(now)) return 2;
  return entry.kind == AgendaKind.exam ? 0 : 1;
}

({double painted, double reserved}) _cardDaysFor(
  AgendaEntry entry,
  int layoutDays,
  Map<String, double> eventInfoDays,
) {
  if (entry.isDeadline) {
    final painted = math.max(
      0.25,
      entry.effectiveLayoutDays(layoutDays) - .25,
    );
    // DDL cards fade to transparent across their leading 18%, so reserving
    // their exact painted span avoids phantom collisions without touching text.
    return (painted: painted, reserved: painted);
  }
  final maxPainted = layoutDays < 3
      ? math.max(0.5, layoutDays - .25)
      : math.max(3.25 * 1.35, layoutDays - .25);
  final preferred =
      eventInfoDays[entry.id] ?? AgendaTimelineLayout.defaultEventInfoDays;
  final painted = preferred.clamp(0.5, maxPainted).toDouble();
  return (
    painted: painted,
    reserved: painted + AgendaTimelineLayout.eventInfoGutterDays,
  );
}

bool _sameLiveCluster(_CandidateInterval a, _CandidateInterval b) {
  if (a.tier != b.tier || a.tier >= 2) return false;
  if (!a.end.isAfter(b.start) || !b.end.isAfter(a.start)) return false;
  if (a.start == b.start && a.end == b.end) return true;
  return a.entry.course.isNotEmpty &&
      a.entry.course == b.entry.course &&
      calendarDate(a.end) == calendarDate(b.end);
}

List<_LaneReservation> _reserveLanes(
  Iterable<AgendaEntry> entries, {
  required Duration minimumEventSpan,
  required int layoutDays,
  required bool reserveEventInformation,
  required Map<String, double> eventInfoDays,
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
  DateTime reservationStart(AgendaEntry entry, double reservedDays) =>
      entry.startOnly || (!entry.isDeadline && !reserveEventInformation)
      ? entry.startsAt
      : (entry.isDeadline ? entry.dueAt : entry.startsAt).subtract(
          Duration(
            microseconds: (reservedDays * Duration.microsecondsPerDay).round(),
          ),
        );
  DateTime reservationEnd(AgendaEntry entry, double reservedDays) =>
      entry.isDeadline
      ? entry.startOnly
            ? entry.startsAt.add(
                Duration(
                  microseconds: (reservedDays * Duration.microsecondsPerDay)
                      .round(),
                ),
              )
            : entry.realDueAt
      : entry.endsAt!;

  final intervals = <_CandidateInterval>[
    for (final entry in entries.where((entry) => !entry.deleted))
      () {
        final days = _cardDaysFor(entry, layoutDays, eventInfoDays);
        final start = reservationStart(entry, days.reserved);
        final end = reservationEnd(entry, days.reserved);
        final minimumEnd = entry.startsAt.add(minimumEventSpan);
        final layoutEnd = !entry.isDeadline && end.isBefore(minimumEnd)
            ? minimumEnd
            : end;
        return (
          entry: entry,
          tier: _timelineTier(entry, now),
          start: start,
          end: end,
          layoutEnd: layoutEnd,
          paintedWidthDays: days.painted,
        );
      }(),
  ]..sort((a, b) {
    if (a.tier != b.tier) return a.tier.compareTo(b.tier);
    final byStart = a.start.compareTo(b.start);
    if (byStart != 0) return byStart;
    final byEnd = a.end.compareTo(b.end);
    if (byEnd != 0) return byEnd;
    final byCourse = a.entry.course.compareTo(b.entry.course);
    if (byCourse != 0) return byCourse;
    return a.entry.id.compareTo(b.entry.id);
  });

  final lanes = <List<_LaneSpan>>[];
  final reservations = <_LaneReservation>[];

  void placeInLane(int lane, _CandidateInterval interval) {
    while (lanes.length <= lane) {
      lanes.add([]);
    }
    final insertion = _insertionPoint(lanes[lane], interval.start);
    lanes[lane].insert(insertion, (
      start: interval.start,
      end: interval.layoutEnd,
    ));
    reservations.add((
      entry: interval.entry,
      lane: lane,
      start: interval.start,
      end: interval.end,
      layoutEnd: interval.layoutEnd,
      paintedWidthDays: interval.paintedWidthDays,
    ));
  }

  for (var index = 0; index < intervals.length;) {
    final first = intervals[index];
    var end = index + 1;
    while (end < intervals.length && _sameLiveCluster(first, intervals[end])) {
      end++;
    }
    final clusterSize = end - index;
    if (clusterSize == 1) {
      var lane = lanes.length;
      for (var candidate = 0; candidate < lanes.length; candidate++) {
        final insertion = _insertionPoint(lanes[candidate], first.start);
        if (!_collides(
          lanes[candidate],
          insertion,
          first.start,
          first.layoutEnd,
        )) {
          lane = candidate;
          break;
        }
      }
      placeInLane(lane, first);
    } else {
      // Prefer one contiguous block of lanes for a simultaneous live cluster,
      // unless doing so would bury it far below an earlier open lane.
      var firstFree = lanes.length;
      for (var candidate = 0; candidate < lanes.length; candidate++) {
        final insertion = _insertionPoint(lanes[candidate], first.start);
        if (!_collides(
          lanes[candidate],
          insertion,
          first.start,
          first.layoutEnd,
        )) {
          firstFree = candidate;
          break;
        }
      }
      var base = lanes.length;
      for (var candidate = firstFree; candidate < lanes.length; candidate++) {
        var fits = true;
        for (var offset = 0; offset < clusterSize; offset++) {
          final laneIndex = candidate + offset;
          if (laneIndex >= lanes.length) continue;
          final member = intervals[index + offset];
          final insertion = _insertionPoint(lanes[laneIndex], member.start);
          if (_collides(
            lanes[laneIndex],
            insertion,
            member.start,
            member.layoutEnd,
          )) {
            fits = false;
            break;
          }
        }
        if (fits) {
          base = candidate;
          break;
        }
      }
      if (base - firstFree <= 3) {
        for (var offset = 0; offset < clusterSize; offset++) {
          placeInLane(base + offset, intervals[index + offset]);
        }
      } else {
        for (var offset = 0; offset < clusterSize; offset++) {
          final member = intervals[index + offset];
          var lane = lanes.length;
          for (var candidate = 0; candidate < lanes.length; candidate++) {
            final insertion = _insertionPoint(lanes[candidate], member.start);
            if (!_collides(
              lanes[candidate],
              insertion,
              member.start,
              member.layoutEnd,
            )) {
              lane = candidate;
              break;
            }
          }
          placeInLane(lane, member);
        }
      }
    }
    index = end;
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
