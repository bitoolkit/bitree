import 'dart:math' as math;

import '../agenda/calendar.dart';
import '../agenda/model.dart';
import '../core/time.dart';
import '../schedule/model.dart';

class ExamConflict {
  const ExamConflict(this.exam, this.other);

  final CalendarItem exam;
  final CalendarItem other;

  int get minutes =>
      (math.min(
            exam.endsAt!.millisecondsSinceEpoch,
            other.endsAt!.millisecondsSinceEpoch,
          ) -
          math.max(
            exam.startsAt.millisecondsSinceEpoch,
            other.startsAt.millisecondsSinceEpoch,
          )) ~/
      60000;
}

List<ExamConflict> findExamConflicts(
  Iterable<AgendaEntry> entries,
  Iterable<SemesterSchedule> schedules, {
  required bool includeClasses,
}) {
  final exams = entries.where((entry) => entry.kind == AgendaKind.exam).toList()
    ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  final result = <ExamConflict>[];
  bool overlaps(CalendarItem a, CalendarItem b) =>
      a.startsAt.isBefore(b.endsAt!) && b.startsAt.isBefore(a.endsAt!);

  for (var i = 0; i < exams.length; i++) {
    final exam = exams[i];
    final item = CalendarItem.agenda(exam);
    for (final other in exams.skip(i + 1)) {
      if (!other.startsAt.isBefore(exam.endsAt!)) break;
      final otherItem = CalendarItem.agenda(other);
      if (overlaps(item, otherItem)) result.add(ExamConflict(item, otherItem));
    }
    if (!includeClasses) continue;
    for (final schedule in schedules) {
      if (exam.term != null && schedule.term != exam.term) continue;
      for (
        var day = calendarDate(exam.startsAt);
        day.isBefore(exam.endsAt!);
        day = day.add(const Duration(days: 1))
      ) {
        for (final course in schedule.coursesAt(
          schedule.weekAt(day),
          weekday: day.weekday,
        )) {
          final lesson = CalendarItem.course(course, day);
          if (overlaps(item, lesson)) result.add(ExamConflict(item, lesson));
        }
      }
    }
  }
  return result;
}
