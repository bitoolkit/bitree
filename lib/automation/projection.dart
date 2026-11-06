import 'dart:convert';

import '../agenda/model.dart';
import '../agenda/presentation.dart';
import '../schedule/model.dart';
import 'presentation.dart';

class AutomationChanges {
  const AutomationChanges({
    this.added = 0,
    this.deleted = 0,
    this.modified = 0,
  });

  final int added;
  final int deleted;
  final int modified;

  factory AutomationChanges.between(
    Map<Object, Map<String, dynamic>> before,
    Map<Object, Map<String, dynamic>> after,
  ) => AutomationChanges(
    added: after.keys.where((key) => !before.containsKey(key)).length,
    deleted: before.keys.where((key) => !after.containsKey(key)).length,
    modified: before.keys
        .where(
          (key) =>
              after.containsKey(key) &&
              jsonEncode(before[key]) != jsonEncode(after[key]),
        )
        .length,
  );
}

/// Presentation copies retain original identities; new rows are display-only.
class AutomationProjection {
  AutomationProjection._(this.schedules, this.entries, this.changes);

  final Map<String, SemesterSchedule> schedules;
  final Map<String, AgendaEntry> entries;
  final AutomationChanges changes;

  Map<String, AgendaEntry> get deadlines => {
    for (final entry in entries.values)
      if (entry.isDeadline) entry.id: entry,
  };

  static const _agendaKeys = {
    AgendaKind.deadline: 'deadlines',
    AgendaKind.event: 'events',
    AgendaKind.exam: 'exams',
  };

  static Map<String, dynamic> snapshot(
    Iterable<SemesterSchedule> schedules,
    Iterable<AgendaEntry> entries,
  ) => {
    'courses': [
      for (final schedule in schedules)
        for (final course in schedule.courses)
          {...course.toJson(), 'term': schedule.term},
    ],
    for (final kind in _agendaKeys.entries)
      kind.value: [
        for (final entry in entries)
          if (!entry.deleted && entry.kind == kind.key) entry.toJson(),
      ],
  };

  factory AutomationProjection.fromResult(
    Map<String, dynamic> result,
    Iterable<SemesterSchedule> schedules,
    Iterable<AgendaEntry> entries,
  ) {
    final originals = {
      for (final schedule in schedules)
        schedule.term: {
          for (final course in schedule.courses) course.id: course,
        },
    };
    final courses = <String, List<Course>>{
      for (final schedule in schedules) schedule.term: [],
    };
    final courseIds = {
      for (final schedule in schedules)
        for (final course in schedule.courses) course.id,
    };
    final seenCourses = <(String, String)>{};
    var courseIndex = 0;
    for (final row in _rows(result, 'courses')) {
      final term = row['term'];
      final savedId = row['id'];
      if (term is! String || !originals.containsKey(term)) {
        throw const FormatException('Keep courses in a saved term.');
      }
      final original = originals[term]?[savedId];
      if (savedId != null && (savedId is! String || original == null)) {
        throw const FormatException(
          'Unknown course identity. Keep id and term unchanged.',
        );
      }
      final id = original?.id ?? _newId('course', courseIndex++, courseIds);
      if (!seenCourses.add((term, id))) {
        throw const FormatException('Duplicate course identity.');
      }
      final json =
          original?.toJson() ??
          {
            'id': id,
            'name': '',
            'teacher': '',
            'room': '',
            'campus': '',
            'number': '',
            'description': '',
            'weekday': null,
            'startSection': null,
            'endSection': null,
            'weeks': <int>[],
            'local': false,
          };
      _checkIdentity(
        row,
        {...json, 'term': term},
        [
          if (original != null) ...['id', 'term'],
          'local',
        ],
      );
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
      if (row['hidden'] != true) {
        courses[term]!.add(
          original == null ? ScriptCourse(projected) : projected,
        );
      }
    }

    final savedEntries = {
      for (final entry in entries)
        if (!entry.deleted) entry.id: entry,
    };
    final entryIds = savedEntries.keys.toSet();
    final projectedEntries = <String, AgendaEntry>{};
    final seenEntries = <String>{};
    var entryIndex = 0;
    for (final kind in _agendaKeys.entries) {
      final fallback = kind.key == AgendaKind.deadline
          ? null
          : [
              for (final entry in savedEntries.values)
                if (entry.kind == kind.key) entry.toJson(),
            ];
      for (final row in _rows(result, kind.value, fallback: fallback)) {
        final savedId = row['id'];
        final original = savedEntries[savedId];
        if (savedId != null &&
            (savedId is! String ||
                original == null ||
                original.kind != kind.key)) {
          throw const FormatException(
            'Unknown agenda identity. Keep id and kind unchanged.',
          );
        }
        final id = original?.id ?? _newId(kind.value, entryIndex++, entryIds);
        if (!seenEntries.add(id)) {
          throw const FormatException('Duplicate agenda identity.');
        }
        final json =
            original?.toJson() ??
            {
              'id': id,
              'title': '',
              'kind': kind.key.name,
              'startsAt': null,
              'endsAt': null,
              'allDay': false,
              'location': '',
              'notes': '',
              'done': false,
              'deleted': false,
              'term': null,
              'local': true,
              'source': null,
              'course': '',
              'url': null,
              'details': null,
            };
        _checkIdentity(row, json, [
          if (original != null) ...['id', 'term'],
          'kind',
          'done',
          'deleted',
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
            if (original == null) 'term',
          ])
            if (row.containsKey(key)) key: row[key],
        });
        if (row['hidden'] == true) continue;
        projectedEntries[id] = original == null
            ? ScriptAgendaEntry(projected)
            : jsonEncode(projected.toJson()) == jsonEncode(json)
            ? original
            : AgendaPresentation(
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
    final orderedEntries = <String, AgendaEntry>{
      for (final entry in savedEntries.values)
        if (projectedEntries.containsKey(entry.id))
          entry.id: projectedEntries[entry.id]!,
      for (final entry in projectedEntries.values)
        if (!savedEntries.containsKey(entry.id)) entry.id: entry,
    };
    final before = <Object, Map<String, dynamic>>{
      for (final schedule in schedules)
        for (final course in schedule.courses)
          (schedule.term, course.id): course.toJson(),
      for (final entry in savedEntries.values) entry.id: entry.toJson(),
    };
    final after = <Object, Map<String, dynamic>>{
      for (final term in courses.entries)
        for (final course in term.value) (term.key, course.id): course.toJson(),
      for (final entry in orderedEntries.values) entry.id: entry.toJson(),
    };
    return AutomationProjection._(
      Map.unmodifiable({
        for (final schedule in schedules)
          schedule.term: schedule.copyWith(courses: courses[schedule.term]!),
      }),
      Map.unmodifiable(orderedEntries),
      AutomationChanges.between(before, after),
    );
  }

  static String _newId(String kind, int index, Set<String> ids) {
    var id = 'automation:$kind:$index';
    while (!ids.add(id)) {
      id = 'automation:$kind:${++index}';
    }
    return id;
  }

  static Iterable<Map<String, dynamic>> _rows(
    Map<String, dynamic> result,
    String key, {
    List<Map<String, dynamic>>? fallback,
  }) sync* {
    final rows = result.containsKey(key) ? result[key] : fallback;
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
