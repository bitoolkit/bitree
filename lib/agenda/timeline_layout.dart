import 'model.dart';

/// Event end times stay intact; layoutEnd includes their minimum display span.
/// DDLs reserve their configured tail days; their painted width is separate.
class AgendaTimelinePlacement {
  const AgendaTimelinePlacement({
    required this.entry,
    required this.lane,
    required this.start,
    required this.end,
    required this.layoutEnd,
  });

  final AgendaEntry entry;
  final int lane;
  final DateTime start;
  final DateTime end;
  final DateTime layoutEnd;
}

/// Pack visible event spans and configured DDL reservations.
/// The view converts its minimum card width to campus time at the current zoom.
List<AgendaTimelinePlacement> layoutAgendaTimeline(
  Iterable<AgendaEntry> entries, {
  required Duration minimumEventSpan,
}) {
  final intervals =
      [
        for (final entry in entries.where((entry) => !entry.deleted))
          (
            entry: entry,
            start: entry.isDeadline
                ? entry.dueAt.subtract(Duration(days: entry.tailDays))
                : entry.startsAt,
            end: entry.isDeadline ? entry.dueAt : entry.endsAt!,
          ),
      ]..sort((a, b) {
        final byStart = a.start.compareTo(b.start);
        if (byStart != 0) return byStart;
        final byEnd = a.end.compareTo(b.end);
        return byEnd != 0 ? byEnd : a.entry.id.compareTo(b.entry.id);
      });
  final laneEnds = <DateTime>[];
  final result = <AgendaTimelinePlacement>[];
  for (final interval in intervals) {
    final minimumEnd = interval.start.add(minimumEventSpan);
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
    result.add(
      AgendaTimelinePlacement(
        entry: interval.entry,
        lane: lane,
        start: interval.start,
        end: interval.end,
        layoutEnd: layoutEnd,
      ),
    );
  }
  return result;
}
