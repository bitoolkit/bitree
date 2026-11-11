import '../schedule/model.dart';
import '../schedule/selection.dart';
import '../schedule/timetable_axis.dart';
import 'model.dart';

class CalendarItem {
  factory CalendarItem.course(Course value, DateTime date) {
    final selection = TimetableSelection(
      date: date,
      startSection: value.startSection!,
      endSection: value.endSection!,
    );
    return CalendarItem._(
      course: value,
      entry: null,
      location: value.room,
      startsAt: selection.startsAt,
      endsAt: selection.endsAt,
    );
  }

  CalendarItem.agenda(AgendaEntry value)
    : this._(
        course: null,
        entry: value,
        location: value.location,
        startsAt: value.startsAt,
        endsAt: value.endsAt,
      );

  const CalendarItem._({
    required this.course,
    required this.entry,
    required this.location,
    required this.startsAt,
    required this.endsAt,
  });

  final Course? course;
  final AgendaEntry? entry;
  final String location;
  final DateTime startsAt;
  final DateTime? endsAt;

  bool get pinned => entry?.allDay == true || entry?.isDeadline == true;

  /// Stable source text for ordering, never for display.
  String get stableTitle => course?.name ?? entry!.title;
}

List<CalendarItem> calendarItemsOn(
  DateTime date,
  SemesterSchedule? schedule,
  Iterable<AgendaEntry> entries,
) {
  final items = [
    if (schedule != null)
      for (final course in schedule.coursesAt(
        schedule.weekAt(date),
        weekday: date.weekday,
      ))
        CalendarItem.course(course, date),
    for (final entry in entries)
      if (!entry.done && entry.occursOn(date)) CalendarItem.agenda(entry),
  ];
  items.sort((a, b) {
    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
    return a.startsAt.compareTo(b.startsAt);
  });
  return items;
}

double timetableOffset(DateTime time, DateTime date) =>
    const TimetableAxis().offsetAt(time, date);

bool outsideTimetable(CalendarItem item, DateTime date) =>
    !item.pinned &&
    timetableOffset(item.startsAt, date) == timetableOffset(item.endsAt!, date);
