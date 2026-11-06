import '../agenda/model.dart';
import '../agenda/presentation.dart';
import '../schedule/model.dart';

/// Validated presentation copies. Every output row retains a host identity;
/// synchronization, persistence and user actions continue using the originals.
class AutomationProjection {
  AutomationProjection._(this.schedules, this.deadlines);

  final Map<String, SemesterSchedule> schedules;
  final Map<String, AgendaEntry> deadlines;

  static Map<String, dynamic> snapshot(
    Iterable<SemesterSchedule> schedules,
    Iterable<AgendaEntry> entries,
  ) => {
    'courses': [
      for (final schedule in schedules)
        for (final course in schedule.courses)
          {...course.toJson(), 'term': schedule.term},
    ],
    'deadlines': [
      for (final entry in entries)
        if (entry.isDeadline) entry.toJson(),
    ],
  };

  factory AutomationProjection.fromResult(
    Map<String, dynamic> result,
    Iterable<SemesterSchedule> schedules,
    Iterable<AgendaEntry> entries,
  ) {
    final originals = {
      for (final schedule in schedules)
        (schedule.term): {
          for (final course in schedule.courses) course.id: course,
        },
    };
    final courses = <String, List<Course>>{
      for (final schedule in schedules) schedule.term: [],
    };
    final seenCourses = <(String, String)>{};
    for (final row in _rows(result, 'courses')) {
      final id = row['id'];
      final term = row['term'];
      final original = originals[term]?[id];
      if (id is! String ||
          term is! String ||
          original == null ||
          !seenCourses.add((term, id))) {
        throw const FormatException(
          'Unknown or duplicate course identity. Keep id and term unchanged.',
        );
      }
      final json = original.toJson();
      _checkIdentity(row, {...json, 'term': term}, ['id', 'term', 'local']);
      _checkHidden(row);
      final projected = Course.fromJson({
        ...json,
        for (final key in [
          'name',
          'teacher',
          'room',
          'campus',
          'number',
          'description',
          'weekday',
          'startSection',
          'endSection',
          'weeks',
        ])
          if (row.containsKey(key)) key: row[key],
      });
      if (row['hidden'] != true) courses[term]!.add(projected);
    }

    final savedDeadlines = {
      for (final entry in entries)
        if (entry.isDeadline) entry.id: entry,
    };
    final deadlines = <String, AgendaEntry>{};
    final seenDeadlines = <String>{};
    for (final row in _rows(result, 'deadlines')) {
      final id = row['id'];
      final original = savedDeadlines[id];
      if (id is! String || original == null || !seenDeadlines.add(id)) {
        throw const FormatException(
          'Unknown or duplicate deadline identity. Keep id unchanged.',
        );
      }
      final json = original.toJson();
      _checkIdentity(row, json, [
        'id',
        'kind',
        'done',
        'deleted',
        'term',
        'local',
        'source',
        'url',
      ]);
      _checkHidden(row);
      final projected = AgendaEntry.fromJson({
        ...json,
        for (final key in [
          'title',
          'course',
          'location',
          'notes',
          'startsAt',
          'endsAt',
          'allDay',
        ])
          if (row.containsKey(key)) key: row[key],
      });
      if (row['hidden'] != true) {
        deadlines[id] = AgendaPresentation(
          projected,
          titleOverride: projected.title != original.title
              ? projected.title
              : null,
          notesOverride: projected.notes != original.notes
              ? projected.notes
              : null,
        );
      }
    }
    return AutomationProjection._(
      Map.unmodifiable({
        for (final schedule in schedules)
          schedule.term: schedule.copyWith(courses: courses[schedule.term]!),
      }),
      Map.unmodifiable(deadlines),
    );
  }

  static Iterable<Map<String, dynamic>> _rows(
    Map<String, dynamic> result,
    String key,
  ) sync* {
    final rows = result[key];
    if (rows is! List) throw FormatException('$key must be an array table.');
    for (final row in rows) {
      if (row is! Map<String, dynamic>) {
        throw FormatException('$key contains an invalid row.');
      }
      yield row;
    }
  }

  static void _checkIdentity(
    Map<String, dynamic> row,
    Map<String, dynamic> original,
    List<String> keys,
  ) {
    for (final key in keys) {
      if (row.containsKey(key) && row[key] != original[key]) {
        throw FormatException('$key is read-only.');
      }
    }
  }

  static void _checkHidden(Map<String, dynamic> row) {
    if (row.containsKey('hidden') && row['hidden'] is! bool) {
      throw const FormatException('hidden must be a boolean.');
    }
  }
}
