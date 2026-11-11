import '../agenda/calendar.dart';
import '../core/time.dart';
import 'timetable_axis.dart';

typedef CalendarBlock = ({List<CalendarItem> items, double start, double end});

/// Every day shares the union of this week's visible timed occurrences.
/// Clip overnight events to each calendar day before combining clock bounds.
TimetableAxis weekTimetableAxis(
  List<List<CalendarItem>> days,
  DateTime monday, {
  required bool expanded,
}) {
  if (!expanded) return const TimetableAxis();
  double? first;
  double? last;
  for (var day = 0; day < days.length; day++) {
    final date = calendarDate(monday).add(Duration(days: day));
    for (final item in days[day]) {
      if (item.pinned ||
          item.entry?.done == true ||
          item.entry?.deleted == true) {
        continue;
      }
      final end = item.endsAt;
      if (end == null) continue;
      final startMinute =
          (item.startsAt.difference(date).inMicroseconds /
                  Duration.microsecondsPerMinute)
              .clamp(0.0, TimetableAxis.dayEnd.toDouble());
      final endMinute =
          (end.difference(date).inMicroseconds / Duration.microsecondsPerMinute)
              .clamp(0.0, TimetableAxis.dayEnd.toDouble());
      if (endMinute <= startMinute) continue;
      if (first == null || startMinute < first) first = startMinute;
      if (last == null || endMinute > last) last = endMinute;
    }
  }
  if (first == null || last == null) return const TimetableAxis(expanded: true);
  return TimetableAxis(
    expanded: true,
    startMinute: (first / 60).floor() * 60,
    endMinute: (last / 60).ceil() * 60,
  );
}

/// Overlapping entries share one column without widening the week.
List<CalendarBlock> groupCalendarItems(
  List<CalendarItem> items,
  DateTime date, {
  TimetableAxis axis = const TimetableAxis(),
  double minimumSpan = 0.6,
}) {
  final length = axis.length;
  final minimum = minimumSpan.clamp(0.0, length).toDouble();
  double startOf(CalendarItem item) => axis
      .offsetAt(item.startsAt, date)
      .clamp(0, item.course == null ? length - minimum : length)
      .toDouble();
  double endOf(CalendarItem item) => axis
      .offsetAt(item.endsAt!, date)
      .clamp(startOf(item) + (item.course == null ? minimum : 0), length)
      .toDouble();
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
