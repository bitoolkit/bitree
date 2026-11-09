import '../agenda/deadline_source.dart';
import '../agenda/model.dart';
import '../sources/course_selection.dart';

class MoocCourse {
  const MoocCourse({
    required this.id,
    required this.termId,
    required this.name,
    required this.spoc,
  });

  factory MoocCourse.fromPlatformCourse(PlatformCourse course) {
    final termId = course.remoteTermId;
    if (termId == null) {
      throw const FormatException('MOOC 课程缺少开课期次。');
    }
    return MoocCourse(
      id: course.remoteId,
      termId: termId,
      name: course.name,
      spoc: course.params['spoc'] == true,
    );
  }

  final String id;
  final String termId;
  final String name;
  final bool spoc;

  Uri get url => Uri.https(
    'www.icourse163.org',
    '${spoc ? '/spoc' : ''}/learn/$id',
    {'tid': termId},
  );

  PlatformCourse toPlatformCourse() => PlatformCourse(
    remoteId: id,
    name: name,
    url: url,
    remoteTermId: termId,
    params: {'spoc': spoc},
  );
}

class MoocTask {
  const MoocTask._(this.entry, {this.reviewTestId});
  final AgendaEntry entry;
  final String? reviewTestId;
}

/// Reads the learner's term DTO. usedTryCount counts valid submissions, not
/// opened attempts; peer review completion comes from its separate status API.
List<MoocTask> readMoocTasks(
  Map<String, dynamic> term,
  MoocCourse course,
  String memberId,
) {
  if (moocId(term['id']) != course.termId ||
      moocId(term['courseId']) != course.id) {
    throw const FormatException('课程结构与所选课程不匹配。');
  }
  final entries = <String, MoocTask>{};

  void add(
    Map<String, dynamic> activity,
    MoocDeadlineKind kind, {
    bool exam = false,
  }) {
    final test = moocMap(activity['test']) ?? activity;
    if (activity['test'] != null && moocMap(activity['test']) == null) {
      throw const FormatException('课程任务格式不正确。');
    }
    final id = moocId(test['id']);
    if (id == null) throw const FormatException('课程任务缺少编号。');
    final rawName = test['name'];
    if (rawName is! String || rawName.trim().isEmpty) {
      throw const FormatException('课程任务缺少标题。');
    }
    final name = rawName.trim();
    final key =
        'mooc:$memberId:${course.termId}:${_persistentKindToken(kind)}:$id';
    final deadline = _time(test['deadline']);
    final release = _time(test['releaseTime'] ?? activity['releaseTime']);
    if (deadline != null) {
      entries[key] = MoocTask._(
        AgendaEntry(
          id: key,
          title: name,
          kind: AgendaKind.deadline,
          startsAt: deadline,
          course: course.name,
          source: DeadlineSource.mooc,
          url: course.url,
          local: false,
          done: _submitted(test, exam: exam),
          details: MoocDeadlineDetails(
            kind: kind,
            spoc: course.spoc,
            releaseAt: release,
          ),
        ),
      );
    }
    // Official JUDGE_TYPE_EVALUATE=1; JUDGE_TYPE_LECTOR=2 is teacher grading.
    final peer = exam ? moocMap(test['subjectTest']) ?? test : test;
    final end = _time(peer['evaluateEnd']);
    if (peer['evaluateJudgeType'] == 1 && end != null) {
      final start = _time(peer['evaluateStart']);
      if (start != null && !end.isAfter(start)) {
        throw const FormatException('互评的结束时间早于开始时间。');
      }
      final reviewTestId =
          moocId(exam ? test['subjectTestId'] : null) ?? moocId(peer['id']);
      if (reviewTestId == null) throw const FormatException('互评任务缺少编号。');
      entries['$key:review'] = MoocTask._(
        AgendaEntry(
          id: '$key:review',
          title: name,
          kind: AgendaKind.deadline,
          startsAt: end,
          course: course.name,
          source: DeadlineSource.mooc,
          url: course.url,
          local: false,
          details: MoocDeadlineDetails(
            kind: MoocDeadlineKind.peerReview,
            spoc: course.spoc,
            releaseAt: start,
            submissionDueAt: deadline,
          ),
        ),
        reviewTestId: reviewTestId,
      );
    }
  }

  void exam(Object? value) {
    final record = moocMap(value);
    if (record != null) add(record, MoocDeadlineKind.exam, exam: true);
  }

  for (final value in moocList(
    term['chapters'],
    optional: true,
    field: '课程章节',
  )) {
    final chapter = moocMap(value);
    if (chapter == null) throw const FormatException('课程章节格式不正确。');
    if (chapter['published'] == false || chapter['visible'] == 0) continue;
    for (final (field, kind) in [
      ('homeworks', MoocDeadlineKind.homework),
      ('quizs', MoocDeadlineKind.quiz),
    ]) {
      for (final value in moocList(
        chapter[field],
        optional: true,
        field: field == 'homeworks' ? '章节作业' : '章节测验',
      )) {
        final activity = moocMap(value);
        if (activity == null) throw const FormatException('课程任务格式不正确。');
        add(activity, kind);
      }
    }
    exam(chapter['exam']);
    for (final value in moocList(
      chapter['lessons'],
      optional: true,
      field: '课程课时',
    )) {
      final lesson = moocMap(value);
      if (lesson == null) throw const FormatException('课程课时格式不正确。');
      if (lesson['visible'] == 0) continue;
      switch (lesson['contentType']) {
        case 2:
          add(lesson, MoocDeadlineKind.quiz);
        case 3:
          add(lesson, MoocDeadlineKind.homework);
        case 4:
          exam(lesson['exam']);
      }
    }
  }
  for (final value in moocList(term['exams'], optional: true, field: '课程考试')) {
    exam(value);
  }
  return entries.values.toList()
    ..sort((a, b) => a.entry.startsAt.compareTo(b.entry.startsAt));
}

bool _submitted(Map<String, dynamic> test, {bool exam = false}) {
  bool submitted(Map<String, dynamic> value) {
    final score = value['userScore'];
    final count = value['usedTryCount'];
    return value['userSubmitStatus'] == 2 ||
        (count is int && count > 0) ||
        (score is num && score.isFinite && score >= 0);
  }

  if (submitted(test)) return true;
  if (!exam) return false;
  final components = [
    ?moocMap(test['objectTest']),
    ?moocMap(test['subjectTest']),
  ];
  return components.isNotEmpty && components.every(submitted);
}

String _persistentKindToken(MoocDeadlineKind kind) => switch (kind) {
  // Keep the original key tokens so saved entries update instead of duplicating.
  MoocDeadlineKind.homework => '作业',
  MoocDeadlineKind.quiz => '测验',
  MoocDeadlineKind.exam => '考试',
  MoocDeadlineKind.peerReview => throw ArgumentError('互评任务使用原任务编号'),
};

DateTime? _time(Object? raw) {
  if (raw == null || raw == 0 || raw == -1) return null;
  if (raw is! int || raw < 0) throw const FormatException('课程任务时间格式不正确。');
  try {
    return DateTime.fromMillisecondsSinceEpoch(
      raw,
      isUtc: true,
    ).add(const Duration(hours: 8));
  } on RangeError {
    throw const FormatException('课程任务时间超出有效范围。');
  }
}

Map<String, dynamic>? moocMap(Object? value) =>
    value is Map<String, dynamic> ? value : null;
List<dynamic> moocList(
  Object? value, {
  bool optional = false,
  String field = '列表',
}) {
  if (optional && value == null) {
    return const [];
  }
  if (value is List) return value;
  throw FormatException('$field格式不正确。');
}

String? moocId(Object? value) {
  final text = value is int || value is String ? '$value' : '';
  return RegExp(r'^[1-9]\d*$').hasMatch(text) ? text : null;
}
