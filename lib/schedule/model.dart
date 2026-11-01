import 'dart:convert';
import 'dart:math' as math;

import '../core/json.dart';

/// Calendar dates are UTC midnights so DST never changes academic week numbers.
DateTime calendarDate(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

DateTime campusNow() => DateTime.now().toUtc().add(const Duration(hours: 8));

DateTime mondayOf(DateTime date) =>
    calendarDate(date).subtract(Duration(days: date.weekday - 1));

String dateText(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

// Week -1 directly precedes week 1; there is no week 0.
int weekOffset(int week) => week > 0 ? week - 1 : week;

int weekFromOffset(int offset) => offset >= 0 ? offset + 1 : offset;

List<int> academicWeeks(int first, int last) => [
  for (var offset = weekOffset(first); offset <= weekOffset(last); offset++)
    weekFromOffset(offset),
];

const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

const sectionTimes = [
  ('08:00', '08:45'),
  ('08:50', '09:35'),
  ('09:55', '10:40'),
  ('10:45', '11:30'),
  ('11:35', '12:20'),
  ('13:20', '14:05'),
  ('14:10', '14:55'),
  ('15:15', '16:00'),
  ('16:05', '16:50'),
  ('16:55', '17:40'),
  ('18:30', '19:15'),
  ('19:20', '20:05'),
  ('20:10', '20:55'),
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
  }) : weeks = List.unmodifiable(weeks.toSet().toList()..sort()) {
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

  String get sectionLabel {
    if (startSection == null) return '节次待定';
    if (startSection == endSection) return '第 $startSection 节';

    return '第 $startSection–$endSection 节';
  }

  String get timeLabel => startSection == null
      ? '时间待定'
      : '${sectionTimes[startSection! - 1].$1}–${sectionTimes[endSection! - 1].$2}';

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
  };

  factory Course.fromJson(Map<String, dynamic> json) => Course(
    id: jsonStringField(json, 'id'),
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
    local: jsonBoolField(json, 'local'),
  );
}

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

String weeksLabel(List<int> weeks) {
  if (weeks.isEmpty) return '周次待定';

  final ranges = <String>[];
  var start = weeks.first;
  var end = start;

  for (final week in weeks.skip(1)) {
    if (week == end + 1) {
      end = week;
    } else {
      ranges.add(start == end ? '$start' : '$start–$end');
      start = end = week;
    }
  }

  ranges.add(start == end ? '$start' : '$start–$end');

  return '${ranges.join('、')} 周';
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

  String get termLabel {
    final parts = term.split('-');
    if (parts.length != 3 || !['1', '2'].contains(parts[2])) return term;

    return '${parts[0]}–${parts[1]} ${parts[2] == '1' ? '秋季' : '春季'}学期';
  }

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

  SemesterSchedule mergeLocalChanges(SemesterSchedule? previous) => copyWith(
    firstWeek: previous?.firstWeek,
    lastWeek: previous?.lastWeek,
    courses: {
      for (final course in courses) course.id: course,
      for (final course in previous?.courses ?? const <Course>[])
        if (course.local) course.id: course,
    }.values.toList(),
  );

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
