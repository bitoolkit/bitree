import 'model.dart';

/// Card bounds reserve lanes; paintStart also includes any unobstructed DDL tail.
/// Event end times stay intact; layoutEnd includes their minimum display span.
class AgendaTimelinePlacement {
  const AgendaTimelinePlacement({
    required this.entry,
    required this.lane,
    required this.start,
    required this.end,
    required this.layoutEnd,
    required this.paintStart,
  });

  final AgendaEntry entry;
  final int lane;
  final DateTime start;
  final DateTime end;
  final DateTime layoutEnd;
  final DateTime paintStart;
}

/// Card widths are converted to campus time by the view at the current zoom.
List<AgendaTimelinePlacement> layoutAgendaTimeline(
  Iterable<AgendaEntry> entries, {
  required Duration minimumEventSpan,
  required Duration deadlineCardSpan,
  required Duration deadlineTailDaySpan,
}) {
  final intervals =
      [
        for (final entry in entries.where((entry) => !entry.deleted))
          (
            entry: entry,
            start: entry.isDeadline
                ? entry.dueAt.subtract(deadlineCardSpan)
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
    }
    final previousEnd = lane < laneEnds.length ? laneEnds[lane] : null;
    final tailStart = interval.entry.isDeadline
        ? interval.end.subtract(
            deadlineTailDaySpan * (interval.entry.tailDays - 0.25),
          )
        : interval.start;
    final unobstructedStart =
        previousEnd != null && previousEnd.isAfter(tailStart)
        ? previousEnd
        : tailStart;
    final paintStart = unobstructedStart.isBefore(interval.start)
        ? unobstructedStart
        : interval.start;
    if (lane == laneEnds.length) {
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
        paintStart: paintStart,
      ),
    );
  }
  return result;
}
