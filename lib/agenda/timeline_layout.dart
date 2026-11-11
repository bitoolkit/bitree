import 'model.dart';

/// Displayed card and tail bounds for an entry in its assigned lane.
/// Event end times stay intact; layoutEnd includes their minimum display span.
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
});

/// Assign lanes once for a set of entries, then project them at any zoom.
class AgendaTimelineLayout {
  AgendaTimelineLayout(
    Iterable<AgendaEntry> entries, {
    required Duration minimumEventSpan,
    required Duration deadlineCardSpan,
  }) : _minimumEventSpan = minimumEventSpan,
       _deadlineCardSpan = deadlineCardSpan,
       _reservations = _reserveLanes(
         entries,
         minimumEventSpan: minimumEventSpan,
         deadlineCardSpan: deadlineCardSpan,
       );

  final Duration _minimumEventSpan;
  final Duration _deadlineCardSpan;
  final List<_LaneReservation> _reservations;

  List<AgendaTimelinePlacement> atZoom(double zoom) {
    final displayedEventSpan = Duration(
      microseconds: (_minimumEventSpan.inMicroseconds / zoom).ceil(),
    );
    final displayedCardSpan = Duration(
      microseconds: (_deadlineCardSpan.inMicroseconds / zoom).ceil(),
    );
    final paintedLaneEnds = <int, DateTime>{};
    final cards =
        <
          ({
            AgendaEntry entry,
            int lane,
            DateTime start,
            DateTime end,
            DateTime layoutEnd,
            DateTime paintStart,
          })
        >[];
    for (final interval in _reservations) {
      final start = interval.entry.isDeadline && !interval.entry.startOnly
          ? interval.end.subtract(displayedCardSpan)
          : interval.start;
      final end = interval.entry.startOnly
          ? start.add(displayedCardSpan)
          : interval.end;
      final displayedMinimumEnd = start.add(displayedEventSpan);
      final layoutEnd =
          !interval.entry.isDeadline && end.isBefore(displayedMinimumEnd)
          ? displayedMinimumEnd
          : end;
      final previousEnd = paintedLaneEnds[interval.lane];
      final tailStart = interval.entry.isDeadline && !interval.entry.startOnly
          ? end.subtract(
              const Duration(days: 1) * (interval.entry.tailDays - 0.25),
            )
          : start;
      final unobstructedStart =
          previousEnd != null && previousEnd.isAfter(tailStart)
          ? previousEnd
          : tailStart;
      cards.add((
        entry: interval.entry,
        lane: interval.lane,
        start: start,
        end: end,
        layoutEnd: layoutEnd,
        paintStart: unobstructedStart.isBefore(start)
            ? unobstructedStart
            : start,
      ));
      paintedLaneEnds[interval.lane] = layoutEnd;
    }
    final nextByLane = <int, DateTime>{};
    final result = <AgendaTimelinePlacement>[];
    for (final card in cards.reversed) {
      final tailEnd = card.entry.startOnly
          ? card.start.add(
              const Duration(days: 1) * (card.entry.tailDays - 0.25),
            )
          : card.layoutEnd;
      final nextStart = nextByLane[card.lane];
      final unobstructedEnd = nextStart != null && nextStart.isBefore(tailEnd)
          ? nextStart
          : tailEnd;
      result.add(
        AgendaTimelinePlacement(
          entry: card.entry,
          lane: card.lane,
          start: card.start,
          end: card.end,
          layoutEnd: card.layoutEnd,
          paintStart: card.paintStart,
          paintEnd: unobstructedEnd.isAfter(card.layoutEnd)
              ? unobstructedEnd
              : card.layoutEnd,
        ),
      );
      nextByLane[card.lane] = card.start;
    }
    return result.reversed.toList(growable: false);
  }
}

List<_LaneReservation> _reserveLanes(
  Iterable<AgendaEntry> entries, {
  required Duration minimumEventSpan,
  required Duration deadlineCardSpan,
}) {
  final intervals =
      [
        for (final entry in entries.where((entry) => !entry.deleted))
          (
            entry: entry,
            start: entry.isDeadline && !entry.startOnly
                ? entry.dueAt.subtract(deadlineCardSpan)
                : entry.startsAt,
            end: entry.isDeadline
                ? entry.startOnly
                      ? entry.startsAt.add(deadlineCardSpan)
                      : entry.dueAt
                : entry.endsAt!,
          ),
      ]..sort((a, b) {
        final byStart = a.start.compareTo(b.start);
        if (byStart != 0) return byStart;
        final byEnd = a.end.compareTo(b.end);
        return byEnd != 0 ? byEnd : a.entry.id.compareTo(b.entry.id);
      });
  final laneEnds = <DateTime>[];
  final cards = <_LaneReservation>[];
  for (final interval in intervals) {
    final minimumEnd = interval.start.add(minimumEventSpan);
    final reservationEnd =
        !interval.entry.isDeadline && interval.end.isBefore(minimumEnd)
        ? minimumEnd
        : interval.end;
    var lane = laneEnds.indexWhere((end) => !interval.start.isBefore(end));
    if (lane < 0) {
      lane = laneEnds.length;
    }
    if (lane == laneEnds.length) {
      laneEnds.add(reservationEnd);
    } else {
      laneEnds[lane] = reservationEnd;
    }
    cards.add((
      entry: interval.entry,
      lane: lane,
      start: interval.start,
      end: interval.end,
    ));
  }
  return cards;
}
