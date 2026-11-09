import 'dart:convert';
import 'dart:math' as math;

import '../core/json.dart';
import '../core/time.dart';
import '../sources/legacy.dart';
import '../sources/source.dart';
import 'section_times.dart';

// Week -1 directly precedes week 1; there is no week 0.
int weekOffset(int week) => week > 0 ? week - 1 : week;

int weekFromOffset(int offset) => offset >= 0 ? offset + 1 : offset;

List<int> academicWeeks(int first, int last) => [
  for (var offset = weekOffset(first); offset <= weekOffset(last); offset++)
    weekFromOffset(offset),
];

/// Finds the ongoing saved semester, preferring the later start when ranges overlap.
SemesterSchedule? semesterAt(
  Iterable<SemesterSchedule> schedules,
  DateTime date,
) {
  SemesterSchedule? current;
  for (final schedule in schedules) {
    final week = schedule.weekAt(date);
    if (week < schedule.firstWeek || week > schedule.lastWeek) continue;
    if (current == null || schedule.firstMonday.isAfter(current.firstMonday)) {
      current = schedule;
    }
  }
  return current;
}

class Course {
  Course({
    required this.id,
    required this.name,
    required this.weekday,
    required this.startSection,
    required this.endSection,
    required List<int> weeks,
    this.teacher = '',
    this.room = '',
    this.campus = '',
    this.number = '',
    this.description = '',
    this.local = false,
    this.origin,
    Set<String> overrides = const {},
    Map<String, dynamic> sourceValues = const {},
    this.sourceRemoved = false,
  }) : weeks = List.unmodifiable(weeks.toSet().toList()..sort()),
       overrides = Set.unmodifiable(overrides),
       sourceValues = Map<String, dynamic>.unmodifiable(sourceValues) {
    if (name.trim().isEmpty || id.isEmpty) {
      throw const FormatException('课程名称或编号缺失');
    }

    if (weekday != null && (weekday! < 1 || weekday! > 7)) {
      throw const FormatException('课程星期超出范围');
    }

    if ((startSection == null) != (endSection == null) ||
        (startSection != null &&
            (startSection! < 1 ||
                endSection! < startSection! ||
                endSection! > sectionTimes.length))) {
      throw const FormatException('课程节次超出作息表范围');
    }

    if (weeks.contains(0)) {
      throw const FormatException('没有第 0 周，请选择负数周或正数周');
    }
    final recordOrigin = origin;
    if (recordOrigin != null &&
        recordOrigin.resource != SourceResource.timetable) {
      throw const FormatException('课程来源类型不一致');
    }
    if (origin == null && overrides.isNotEmpty) {
      throw const FormatException('手动课程不能带有来源字段覆盖');
    }
    if (overrides.any((field) => !_editableFields.contains(field))) {
      throw const FormatException('课程包含未知的可覆盖字段');
    }
    if (sourceValues.keys.any((field) => !_editableFields.contains(field))) {
      throw const FormatException('课程来源字段包含未知字段');
    }
  }

  Course.imported({
    required String name,
    required int? weekday,
    required int? startSection,
    required int? endSection,
    required List<int> weeks,
    String teacher = '',
    String room = '',
    String campus = '',
    String number = '',
    String description = '',
  }) : this(
         id: _schoolCourseId(
           number: number,
           name: name,
           teacher: teacher,
           campus: campus,
           room: room,
           weekday: weekday,
           startSection: startSection,
           endSection: endSection,
           weeks: weeks,
         ),
         name: name,
         weekday: weekday,
         startSection: startSection,
         endSection: endSection,
         weeks: weeks,
         teacher: teacher,
         room: room,
         campus: campus,
         number: number,
         description: description,
       );

  final String id;
  final String name;
  final String teacher;
  final String room;
  final String campus;
  final String number;
  final String description;
  final int? weekday;
  final int? startSection;
  final int? endSection;
  final List<int> weeks;

  // Includes manual additions and local edits of imported courses.
  final bool local;

  final RecordOrigin? origin;
  final Set<String> overrides;
  final Map<String, dynamic> sourceValues;
  final bool sourceRemoved;

  static const _editableFields = {
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
    'record',
    'timing',
  };

  String get stableId => local
      ? id
      : _schoolCourseId(
          number: number,
          name: name,
          teacher: teacher,
          campus: campus,
          room: room,
          weekday: weekday,
          startSection: startSection,
          endSection: endSection,
          weeks: weeks,
        );

  bool get isScheduled =>
      weekday != null && startSection != null && weeks.isNotEmpty;

  bool get isEdited => overrides.isNotEmpty || sourceRemoved;

  bool occurs(int week) => isScheduled && weeks.contains(week);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'teacher': teacher,
    'room': room,
    'campus': campus,
    'number': number,
    'description': description,
    'weekday': weekday,
    'startSection': startSection,
    'endSection': endSection,
    'weeks': weeks,
    'local': local,
    if (origin != null) 'origin': origin!.toJson(),
    if (overrides.isNotEmpty) 'overrides': overrides.toList()..sort(),
    if (sourceValues.isNotEmpty) 'sourceValues': sourceValues,
    if (sourceRemoved) 'sourceRemoved': true,
  };

  factory Course.fromJson(Map<String, dynamic> json) {
    final id = jsonStringField(json, 'id');
    final local = jsonBoolField(json, 'local');
    final origin = json['origin'] == null
        ? (id.startsWith('local-') ? null : LegacyRecordIds.schoolOrigin(id))
        : RecordOrigin.fromJson(jsonObject(json['origin'], 'origin'));
    final rawOverrides = json['overrides'];
    final overrides = rawOverrides == null
        ? <String>{}
        : {
            for (final value in jsonList(rawOverrides, 'overrides'))
              jsonString(value, 'overrides[]'),
          };
    final rawSourceValues = json['sourceValues'];
    final sourceValues = rawSourceValues == null
        ? <String, dynamic>{}
        : jsonObject(rawSourceValues, 'sourceValues');
    final legacyEdited = local && origin != null;
    return Course(
      id: id,
    name: jsonStringField(json, 'name'),
    teacher: jsonStringField(json, 'teacher'),
    room: jsonStringField(json, 'room'),
    campus: jsonStringField(json, 'campus'),
    number: jsonStringField(json, 'number'),
    description: jsonStringField(json, 'description'),
    weekday: jsonIntFieldOrNull(json, 'weekday'),
    startSection: jsonIntFieldOrNull(json, 'startSection'),
    endSection: jsonIntFieldOrNull(json, 'endSection'),
    weeks: [
      for (final value in jsonListField(json, 'weeks'))
        jsonInt(value, 'weeks[]'),
    ],
    local: local,
    origin: origin,
    overrides: legacyEdited && overrides.isEmpty
        ? const {'record'}
        : overrides,
    sourceValues: legacyEdited && sourceValues.isEmpty
        ? {
            'name': jsonStringField(json, 'name'),
            'teacher': jsonStringField(json, 'teacher'),
            'room': jsonStringField(json, 'room'),
            'campus': jsonStringField(json, 'campus'),
            'number': jsonStringField(json, 'number'),
            'description': jsonStringField(json, 'description'),
            'weekday': jsonIntFieldOrNull(json, 'weekday'),
            'startSection': jsonIntFieldOrNull(json, 'startSection'),
            'endSection': jsonIntFieldOrNull(json, 'endSection'),
            'weeks': [
              for (final value in jsonListField(json, 'weeks'))
                jsonInt(value, 'weeks[]'),
            ],
          }
        : sourceValues,
    sourceRemoved: json['sourceRemoved'] == true,
  );
  }

  bool get wholeRecordOverridden =>
      overrides.contains('record') || overrides.contains('timing');

  Course applySource(Course incoming, {bool wholeRecord = true}) {
    final incomingOrigin = incoming.origin ?? origin;
    if (incomingOrigin == null) return incoming;
    final nextSourceValues = _sourceValuesOf(incoming);
    if (wholeRecord || wholeRecordOverridden) {
      return copyWith(
        origin: incomingOrigin,
        sourceValues: nextSourceValues,
        local: local || overrides.isNotEmpty,
        sourceRemoved: false,
      );
    }
    return copyWith(
      name: overrides.contains('name') ? name : incoming.name,
      teacher: overrides.contains('teacher') ? teacher : incoming.teacher,
      room: overrides.contains('room') ? room : incoming.room,
      campus: overrides.contains('campus') ? campus : incoming.campus,
      number: overrides.contains('number') ? number : incoming.number,
      description: overrides.contains('description')
          ? description
          : incoming.description,
      weekday: overrides.contains('timing') ? weekday : incoming.weekday,
      startSection: overrides.contains('timing')
          ? startSection
          : incoming.startSection,
      endSection: overrides.contains('timing')
          ? endSection
          : incoming.endSection,
      weeks: overrides.contains('timing') ? weeks : incoming.weeks,
      origin: incomingOrigin,
      sourceValues: nextSourceValues,
      local: local || overrides.isNotEmpty,
      sourceRemoved: false,
    );
  }

  Course withUserEdit({
    String? name,
    String? teacher,
    String? room,
    int? weekday,
    int? startSection,
    int? endSection,
    List<int>? weeks,
  }) {
    if (origin == null) {
      return copyWith(
        name: name,
        teacher: teacher,
        room: room,
        weekday: weekday,
        startSection: startSection,
        endSection: endSection,
        weeks: weeks,
        local: true,
      );
    }
    if (origin!.resource == SourceResource.timetable) {
      return copyWith(
        name: name,
        teacher: teacher,
        room: room,
        weekday: weekday,
        startSection: startSection,
        endSection: endSection,
        weeks: weeks,
        overrides: const {'record'},
        sourceValues: sourceValues.isEmpty
            ? _sourceValuesOf(this)
            : sourceValues,
        local: true,
      );
    }
    final nextOverrides = {...overrides};
    final nextSourceValues = {...sourceValues};
    void fix(String field, Object? oldValue, Object? newValue) {
      if (oldValue == newValue) return;
      nextOverrides.add(field);
      nextSourceValues.putIfAbsent(field, () => oldValue);
    }

    if (name != null) fix('name', this.name, name);
    if (teacher != null) fix('teacher', this.teacher, teacher);
    if (room != null) fix('room', this.room, room);
    if (weekday != null ||
        startSection != null ||
        endSection != null ||
        weeks != null) {
      if (weekday != this.weekday ||
          startSection != this.startSection ||
          endSection != this.endSection ||
          weeks != null) {
        nextOverrides.add('timing');
        nextSourceValues.putIfAbsent('weekday', () => this.weekday);
        nextSourceValues.putIfAbsent('startSection', () => this.startSection);
        nextSourceValues.putIfAbsent('endSection', () => this.endSection);
        nextSourceValues.putIfAbsent('weeks', () => this.weeks);
      }
    }
    return copyWith(
      name: name ?? this.name,
      teacher: teacher ?? this.teacher,
      room: room ?? this.room,
      weekday: weekday ?? this.weekday,
      startSection: startSection ?? this.startSection,
      endSection: endSection ?? this.endSection,
      weeks: weeks ?? this.weeks,
      overrides: nextOverrides,
      sourceValues: nextSourceValues,
      local: true,
    );
  }

  Course restoreSource() {
    if (origin == null || sourceValues.isEmpty) return this;
    return Course(
      id: id,
      name: sourceValues['name'] as String? ?? name,
      teacher: sourceValues['teacher'] as String? ?? teacher,
      room: sourceValues['room'] as String? ?? room,
      campus: sourceValues['campus'] as String? ?? campus,
      number: sourceValues['number'] as String? ?? number,
      description: sourceValues['description'] as String? ?? description,
      weekday:
          sourceValues['weekday'] as int? ??
          (sourceValues.containsKey('weekday') ? null : weekday),
      startSection:
          sourceValues['startSection'] as int? ??
          (sourceValues.containsKey('startSection') ? null : startSection),
      endSection:
          sourceValues['endSection'] as int? ??
          (sourceValues.containsKey('endSection') ? null : endSection),
      weeks: sourceValues['weeks'] is List
          ? [
              for (final value in sourceValues['weeks'] as List)
                if (value is int) value,
            ]
          : weeks,
      local: false,
      origin: origin,
      sourceValues: sourceValues,
      sourceRemoved: false,
    );
  }

  Course rebindOrigin(String sourceInstanceId) {
    final current = origin;
    if (current == null || current.sourceInstanceId == sourceInstanceId) {
      return this;
    }
    return copyWith(
      origin: current.copyWith(sourceInstanceId: sourceInstanceId),
    );
  }

  Course copyWith({
    String? id,
    String? name,
    String? teacher,
    String? room,
    String? campus,
    String? number,
    String? description,
    Object? weekday = _unset,
    Object? startSection = _unset,
    Object? endSection = _unset,
    List<int>? weeks,
    bool? local,
    Object? origin = _unset,
    Set<String>? overrides,
    Map<String, dynamic>? sourceValues,
    bool? sourceRemoved,
  }) => Course(
    id: id ?? this.id,
    name: name ?? this.name,
    teacher: teacher ?? this.teacher,
    room: room ?? this.room,
    campus: campus ?? this.campus,
    number: number ?? this.number,
    description: description ?? this.description,
    weekday: identical(weekday, _unset) ? this.weekday : weekday as int?,
    startSection: identical(startSection, _unset)
        ? this.startSection
        : startSection as int?,
    endSection: identical(endSection, _unset)
        ? this.endSection
        : endSection as int?,
    weeks: weeks ?? this.weeks,
    local: local ?? this.local,
    origin: identical(origin, _unset) ? this.origin : origin as RecordOrigin?,
    overrides: overrides ?? this.overrides,
    sourceValues: sourceValues ?? this.sourceValues,
    sourceRemoved: sourceRemoved ?? this.sourceRemoved,
  );
}

const _unset = Object();

Map<String, dynamic> _sourceValuesOf(Course course) => {
  'name': course.name,
  'teacher': course.teacher,
  'room': course.room,
  'campus': course.campus,
  'number': course.number,
  'description': course.description,
  'weekday': course.weekday,
  'startSection': course.startSection,
  'endSection': course.endSection,
  'weeks': course.weeks,
};

String _schoolCourseId({
  required String number,
  required String name,
  required String teacher,
  required String campus,
  required String room,
  required int? weekday,
  required int? startSection,
  required int? endSection,
  required List<int> weeks,
}) {
  final identity = [
    number,
    name,
    teacher,
    campus,
    room,
    weekday,
    startSection,
    endSection,
    weeks,
  ];

  return 'school-${jsonEncode(identity)}';
}

class SemesterSchedule {
  SemesterSchedule({
    required this.term,
    required DateTime firstMonday,
    required List<Course> courses,
    int? firstWeek,
    int? lastWeek,
    this.syncedAt,
  }) : firstMonday = calendarDate(firstMonday),
       courses = List.unmodifiable(courses),
       firstWeek =
           firstWeek ??
           courses.fold(
             1,
             (first, course) => course.weeks.isEmpty
                 ? first
                 : math.min(first, course.weeks.first),
           ),
       lastWeek =
           lastWeek ??
           courses.fold(
             25,
             (last, course) => course.weeks.isEmpty
                 ? last
                 : math.max(last, course.weeks.last),
           ) {
    if (term.trim().isEmpty || firstMonday.weekday != DateTime.monday) {
      throw const FormatException('学期或开学日期不正确；开学日期应为第一周周一');
    }
    if (this.firstWeek == 0 ||
        this.lastWeek == 0 ||
        this.firstWeek > this.lastWeek) {
      throw const FormatException('学期起止周次不正确');
    }
  }

  final String term;

  /// Monday of week 1, after any negative weeks.
  final DateTime firstMonday;
  final List<Course> courses;
  final DateTime? syncedAt;

  final int firstWeek;
  final int lastWeek;

  List<int> get weeks => academicWeeks(firstWeek, lastWeek);

  int weekAt(DateTime date) => weekFromOffset(
    (calendarDate(date).difference(firstMonday).inDays / 7).floor(),
  );

  DateTime mondayAt(int week) =>
      firstMonday.add(Duration(days: weekOffset(week) * 7));

  List<Course> coursesAt(int week, {int? weekday}) {
    final scheduled = courses
        .where(
          (course) =>
              course.occurs(week) &&
              (weekday == null || course.weekday == weekday),
        )
        .toList();

    scheduled.sort((first, second) {
      final day = first.weekday!.compareTo(second.weekday!);
      if (day != 0) return day;

      final section = first.startSection!.compareTo(second.startSection!);
      return section != 0 ? section : first.name.compareTo(second.name);
    });

    return scheduled;
  }

  SemesterSchedule copyWith({
    List<Course>? courses,
    int? firstWeek,
    int? lastWeek,
  }) => SemesterSchedule(
    term: term,
    firstMonday: firstMonday,
    courses: courses ?? this.courses,
    firstWeek: firstWeek ?? this.firstWeek,
    lastWeek: lastWeek ?? this.lastWeek,
    syncedAt: syncedAt,
  );

  SemesterSchedule mergeLocalChanges(SemesterSchedule? previous) {
    final saved = {
      for (final course in previous?.courses ?? const <Course>[])
        course.id: course,
    };
    final merged = <String, Course>{};
    for (final incoming in courses) {
      final origin =
          incoming.origin ??
          (incoming.id.startsWith('local-')
              ? null
              : LegacyRecordIds.schoolOrigin(incoming.id));
      final source = origin == null ? incoming : incoming.copyWith(origin: origin);
      final old = saved[incoming.id];
      if (old == null) {
        merged[source.id] = source;
      } else if (old.origin == null && old.local) {
        merged[old.id] = old;
      } else if (old.isEdited) {
        merged[old.id] = old.applySource(source);
      } else {
        merged[source.id] = source;
      }
    }
    for (final old in saved.values) {
      if (merged.containsKey(old.id)) continue;
      if (old.origin == null && old.local) {
        merged[old.id] = old;
      } else if (old.isEdited) {
        merged[old.id] = old.copyWith(
          sourceRemoved: true,
          local: true,
        );
      }
    }
    return copyWith(
      firstWeek: previous?.firstWeek,
      lastWeek: previous?.lastWeek,
      courses: merged.values.toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'term': term,
    'firstMonday': dateText(firstMonday),
    'firstWeek': firstWeek,
    'lastWeek': lastWeek,
    'courses': courses.map((course) => course.toJson()).toList(),
    'syncedAt': syncedAt?.toIso8601String(),
  };

  factory SemesterSchedule.fromJson(Map<String, dynamic> json) =>
      SemesterSchedule(
        term: jsonStringField(json, 'term'),
        firstMonday: jsonDateTime('firstMonday', json['firstMonday']),
        firstWeek: jsonIntFieldOrNull(json, 'firstWeek'),
        lastWeek: jsonIntFieldOrNull(json, 'lastWeek'),
        courses: [
          for (final row in jsonListField(json, 'courses'))
            Course.fromJson(jsonObject(row, 'courses[]')),
        ],
        syncedAt: jsonDateTimeOrNull('syncedAt', json['syncedAt']),
      );
}
