import '../../agenda/deadline_source.dart';
import '../../agenda/model.dart';
import '../../core/async/cancelable_request.dart';
import '../../core/json.dart';
import '../errors.dart';
import '../session.dart';

Future<Map<String, dynamic>> _eclassJson(
  SchoolSession session,
  String path, {
  Object? body,
}) async {
  final response = await session.request(
    DeadlineSource.eclass.origin.resolve(path),
    jsonBody: body,
    headers: {
      'Accept': 'application/json',
      'X-Requested-With': 'XMLHttpRequest',
    },
    stopAtLogin: true,
  );
  if (response.text.trimLeft().startsWith('<')) throw const SessionExpired();
  return response.json;
}

Future<List<AgendaEntry>> fetchEclassDeadlines(SchoolSession session) async {
  final tasks = await _courseTasks(session);

  return [
    for (final task in tasks)
      AgendaEntry(
        id: 'eclass-${task.id}',
        title: task.title,
        kind: AgendaKind.deadline,
        startsAt: _eclassDate(task.deadline),
        done: task.done,
        course: task.course,
        source: DeadlineSource.eclass,
        local: false,
        url: DeadlineSource.eclass.origin.resolve(
          '/course/${Uri.encodeComponent(task.courseId)}'
          '/learning-activity/full-screen#/${task.id}',
        ),
      ),
  ];
}

Future<List<_EclassTask>> _courseTasks(SchoolSession session) async {
  final courses = <Map<String, dynamic>>[];
  var page = 1;
  while (true) {
    final response = await _eclassJson(
      session,
      '/api/my-courses',
      body: {
        'page': page,
        'page_size': 100,
        'fields': 'id,name',
        'conditions': {},
      },
    );
    final rows = [
      for (final value in jsonListField(response, 'courses'))
        jsonObject(value, 'courses[]'),
    ];
    courses.addAll(rows);
    final pagesValue = response['pages'];
    final pages = pagesValue == null
        ? null
        : pagesValue is num
        ? pagesValue
        : throw const FormatException('pages 格式不正确');
    if (pages != null ? page >= pages : rows.length < 100) break;
    page++;
  }

  final outcomes = await Future.wait([
    for (final course in courses) _courseTasksFor(session, course),
  ], eagerError: true);

  final result = <_EclassTask>[];
  final activityIds = <String>{};
  Object? firstFailure;
  StackTrace? firstStack;
  for (final outcome in outcomes) {
    if (outcome.tasks == null) {
      firstFailure ??= outcome.error;
      firstStack ??= outcome.stack;
      continue;
    }
    for (final task in outcome.tasks!) {
      if (activityIds.add(task.id)) result.add(task);
    }
  }
  if (result.isEmpty && firstFailure != null) {
    Error.throwWithStackTrace(firstFailure, firstStack!);
  }
  return result;
}

Future<_CourseTasks> _courseTasksFor(
  SchoolSession session,
  Map<String, dynamic> course,
) async {
  try {
    final courseId = _identifier(course['id'], 'course.id');
    final courseName = jsonStringField(course, 'name');
    final response = await _eclassJson(
      session,
      '/api/courses/${Uri.encodeComponent(courseId)}/activities',
    );
    final tasks = [
      for (final value in jsonListField(response, 'activities'))
        ?_taskFromActivity(
          jsonObject(value, 'activities[]'),
          courseId: courseId,
          courseName: courseName,
        ),
    ];

    final statuses = <String, bool>{};
    if (tasks.any((task) => task.activityType == 'homework')) {
      try {
        statuses.addAll(await _homeworkSubmissionStatuses(session, courseId));
      } on RequestCancelled {
        rethrow;
      } on SessionExpired {
        rethrow;
      } on Exception {
        // Older server builds may not expose the course-level endpoint.
      }
    }

    final pending = [
      for (final task in tasks)
        if (!statuses.containsKey(task.id)) task,
    ];
    final fallback = await Future.wait([
      for (final task in pending) _submitted(session, task.id),
    ], eagerError: true);
    var fallbackIndex = 0;

    return (
      tasks: [
        for (final task in tasks)
          (
            id: task.id,
            title: task.title,
            courseId: task.courseId,
            course: task.course,
            deadline: task.deadline,
            activityType: task.activityType,
            done:
                statuses[task.id] ??
                (statuses.containsKey(task.id)
                    ? false
                    : fallback[fallbackIndex++]),
          ),
      ],
      error: null,
      stack: null,
    );
  } on RequestCancelled {
    rethrow;
  } on SessionExpired {
    rethrow;
  } on Exception catch (error, stack) {
    return (tasks: null, error: error, stack: stack);
  }
}

Future<Map<String, bool>> _homeworkSubmissionStatuses(
  SchoolSession session,
  String courseId,
) async {
  final response = await _eclassJson(
    session,
    '/api/course/${Uri.encodeComponent(courseId)}'
    '/homework/submission-status?no-intercept=true',
  );
  return {
    for (final value in jsonListField(response, 'homework_activities'))
      if (jsonObject(value, 'homework_activities[]') case final activity)
        _identifier(activity['id'], 'homework_activities[].id'):
            jsonStringOrNull(
              activity['status_code'],
              'homework_activities[].status_code',
            ) ==
            'submitted',
  };
}

_EclassTask? _taskFromActivity(
  Map<String, dynamic> task, {
  required String courseId,
  required String courseName,
}) {
  if (task['type'] == 'material') return null;
  final deadline = _deadline(task);
  if (deadline == null) return null;
  return (
    id: _identifier(task['id'], 'activity.id'),
    title: jsonStringOrNull(task['title'], 'activity.title') ?? '未命名作业',
    courseId: courseId,
    course: courseName,
    deadline: deadline,
    activityType: jsonStringOrNull(task['type'], 'activity.type') ?? '',
    done: false,
  );
}

String? _deadline(Map<String, dynamic> task) {
  final deadline = jsonStringOrNull(
    task['end_time'] ?? task['visible_end_at'],
    'activity deadline',
  );
  return deadline == null || deadline.isEmpty || deadline == 'null'
      ? null
      : deadline;
}

Future<bool> _submitted(SchoolSession session, String id) async {
  final detail = await _eclassJson(
    session,
    '/api/activities/${Uri.encodeComponent(id)}',
  );
  return (jsonIntOrNull(detail['user_submit_count'], 'user_submit_count') ??
          0) >
      0;
}

String _identifier(Object? value, String field) {
  if (value is String && value.isNotEmpty) return value;
  if (value is int) return '$value';
  throw FormatException('$field 格式不正确');
}

DateTime _eclassDate(String value) {
  final parsed = DateTime.parse(value.replaceAll('/', '-'));
  if (RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value)) {
    return parsed.toUtc().add(const Duration(hours: 8));
  }
  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
  );
}

typedef _EclassTask = ({
  String id,
  String title,
  String courseId,
  String course,
  String deadline,
  String activityType,
  bool done,
});

typedef _CourseTasks = ({
  List<_EclassTask>? tasks,
  Object? error,
  StackTrace? stack,
});
