import '../agenda/calendar.dart';
import 'section_times.dart';

typedef CalendarBlock = ({List<CalendarItem> items, double start, double end});

/// Overlapping entries share one column without widening the week.
List<CalendarBlock> groupCalendarItems(
  List<CalendarItem> items,
  DateTime date,
) {
  final length = sectionTimes.length.toDouble();
  double startOf(CalendarItem item) => timetableOffset(
    item.startsAt,
    date,
  ).clamp(0, item.course == null ? length - 0.6 : length).toDouble();
  double endOf(CalendarItem item) => timetableOffset(
    item.endsAt!,
    date,
  ).clamp(startOf(item) + (item.course == null ? 0.6 : 0), length).toDouble();
  final sorted = [...items]
    ..sort((first, second) {
      final time = first.startsAt.compareTo(second.startsAt);
      return time != 0 ? time : first.stableTitle.compareTo(second.stableTitle);
    });
  final result = <CalendarBlock>[];
  var group = <CalendarItem>[];
  var groupEnd = 0.0;

  void finish() {
    result.add((
      items: List.unmodifiable(group),
      start: startOf(group.first),
      end: groupEnd,
    ));
    group = [];
    groupEnd = 0;
  }

  for (final item in sorted) {
    final start = startOf(item);
    final end = endOf(item);
    if (group.isNotEmpty && start >= groupEnd) finish();
    group.add(item);
    if (end > groupEnd) groupEnd = end;
  }
  if (group.isNotEmpty) finish();

  return result;
}
