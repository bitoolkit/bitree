import 'dart:convert';

import '../core/time.dart';
import '../schedule/model.dart';
import '../schedule/selection.dart';
import 'model.dart';

const _physicsLabPrefix = 'physics-lab:';

/// This is a local generator, not a learning-platform source. Automatic entries
/// start with local=false so later updates can refresh them; the editor marks
/// user edits local=true, just as it does for imported platform deadlines.
bool isPhysicsLabDeadline(AgendaEntry entry) =>
    entry.isDeadline &&
    entry.source == null &&
    entry.id.startsWith(_physicsLabPrefix);

List<AgendaEntry> physicsLabDeadlines(SemesterSchedule schedule) {
  final entries = <String, AgendaEntry>{};
  for (final course in schedule.courses) {
    if (!course.isScheduled ||
        !course.room.contains('物理') ||
        !course.room.contains('实验')) {
      continue;
    }
    final name = course.name.trim().split(RegExp(r'\s+')).first;
    for (final week in course.weeks) {
      if (week < schedule.firstWeek || week > schedule.lastWeek) {
        continue;
      }
      final date = schedule
          .mondayAt(week)
          .add(Duration(days: course.weekday! - 1));
      final selection = TimetableSelection(
        date: date,
        startSection: course.startSection!,
        endSection: course.endSection!,
      );
      // The night before next week's same weekday, not seven days at 23:59.
      final reportDate = date.add(const Duration(days: 6));
      final reportDue = DateTime.utc(
        reportDate.year,
        reportDate.month,
        reportDate.day,
        23,
        59,
      );
      for (final deadline in [
        (
          key: 'preview',
          kind: PhysicsLabDeadlineKind.preview,
          due: selection.startsAt,
        ),
        (key: 'report', kind: PhysicsLabDeadlineKind.report, due: reportDue),
      ]) {
        // No clock in the ID: editing a local course's section updates the same
        // occurrence. The semester and course ID isolate separate lab sessions.
        final identity = jsonEncode([
          schedule.term,
          course.id,
          dateText(date),
          deadline.key,
        ]);
        final id = '$_physicsLabPrefix$identity';
        entries[id] = AgendaEntry(
          id: id,
          title: name,
          kind: AgendaKind.deadline,
          startsAt: deadline.due,
          location: course.room,
          term: schedule.term,
          course: course.name,
          local: false,
          details: PhysicsLabDeadlineDetails(
            kind: deadline.kind,
            courseLabel: name,
            classStartsAt: selection.startsAt,
            classEndsAt: selection.endsAt,
          ),
        );
      }
    }
  }
  return entries.values.toList()..sort((a, b) {
    final time = a.startsAt.compareTo(b.startsAt);
    return time != 0 ? time : a.id.compareTo(b.id);
  });
}
