import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;

import '../../agenda/deadline_source.dart';
import '../../agenda/model.dart';
import '../../core/async/cancelable_request.dart';
import '../../core/json.dart';
import '../errors.dart';
import '../session.dart';

const _activityModules = {
  'assign',
  'choice',
  'feedback',
  'forum',
  'h5pactivity',
  'lesson',
  'quiz',
  'scorm',
  'workshop',
};

Future<List<AgendaEntry>> fetchLexueDeadlines(
  SchoolSession session,
  SchoolResponse page,
) async {
  final sesskey = RegExp(r'''["']sesskey["']\s*:\s*["']([^"']+)["']''')
      .firstMatch(page.text)?[1];
  final outcomes = await Future.wait([
    if (sesskey == null)
      Future.value((value: const <AgendaEntry>[], error: null, stack: null))
    else
      _attempt(() => _calendarDeadlines(session, sesskey)),
    _attempt(() => _activityDeadlines(session)),
  ], eagerError: true);
  final calendar = outcomes[0];
  final activities = outcomes[1];
  if (calendar.value == null && activities.value == null) {
    Error.throwWithStackTrace(
      calendar.error ?? activities.error!,
      calendar.stack ?? activities.stack!,
    );
  }
  return _mergeActivityDeadlines(
    calendar.value ?? const [],
    activities.value ?? const [],
  );
}

Future<List<AgendaEntry>> _calendarDeadlines(
  SchoolSession session,
  String sesskey,
) async {
  final source = DeadlineSource.lexue;
  final exported = await session.request(
    source.origin.resolve('/calendar/export.php'),
    form: {
      'sesskey': sesskey,
      '_qf__core_calendar_export_form': '1',
      'events[exportevents]': 'all',
      'period[timeperiod]': 'recentupcoming',
      'generateurl': '获取日历网址',
    },
    stopAtLogin: true,
  );
  final block = html.parse(exported.text).querySelector('.calendarurl');
  if (block == null) {
    throw const FormatException('乐学未返回日历导出地址');
  }
  final address = RegExp(r'https://\S+').firstMatch(block.text)?[0];
  final url = address == null ? null : Uri.tryParse(address);
  if (url == null ||
      url.host != source.host ||
      url.userInfo.isNotEmpty ||
      url.scheme != 'https') {
    throw const SchoolRequestError('乐学返回的日程地址无效。');
  }
  final calendar = await session.request(url, stopAtLogin: true);
  final entries = _parseLexueCalendar(calendar.text);
  if (entries.isEmpty) return entries;

  try {
    final completed = await _completedLexueEvents(session, sesskey, entries);
    return [
      for (final entry in entries)
        completed.contains(entry.id) ? entry.copyWith(done: true) : entry,
    ];
  } on RequestCancelled {
    rethrow;
  } on Exception {
    return entries;
  }
}

Future<List<AgendaEntry>> _activityDeadlines(SchoolSession session) async {
  final source = DeadlineSource.lexue;
  final home = await session.request(
    source.origin.resolve('/my/'),
    stopAtLogin: true,
  );
  final courses = _courseLinks(home.text, base: home.url);
  final scans = await Future.wait([
    for (final course in courses.values)
      _attempt(() => _courseActivities(session, course)),
  ], eagerError: true);

  final result = <AgendaEntry>[];
  final activityIds = <String>{};
  Object? firstFailure;
  StackTrace? firstStack;
  for (final scan in scans) {
    if (scan.value == null) {
      firstFailure ??= scan.error;
      firstStack ??= scan.stack;
      continue;
    }
    for (final entry in scan.value!.entries) {
      if (activityIds.add(entry.id)) result.add(entry);
    }
    firstFailure ??= scan.value!.error;
    firstStack ??= scan.value!.stack;
  }
  if (result.isEmpty && firstFailure != null) {
    Error.throwWithStackTrace(firstFailure, firstStack!);
  }
  return result;
}

Future<_ActivityScan> _courseActivities(
  SchoolSession session,
  _CourseLink course,
) async {
  final coursePage = await session.request(course.url, stopAtLogin: true);
  final document = html.parse(coursePage.text);
  final courseName = _courseName(document) ?? course.name;
  final sectionIds = _sectionIds(document, course.id, base: coursePage.url);
  final sections = await Future.wait([
    for (final section in sectionIds)
      _attempt(() => _courseSection(session, course, section)),
  ], eagerError: true);

  Object? firstFailure;
  StackTrace? firstStack;
  final pages = <({dom.Document document, Uri url})>[
    (document: document, url: coursePage.url),
  ];
  for (final section in sections) {
    final page = section.value;
    if (page != null) {
      pages.add(page);
    } else {
      firstFailure ??= section.error;
      firstStack ??= section.stack;
    }
  }

  final modules = <String, _ActivityLink>{};
  for (final page in pages) {
    final root =
        page.document.querySelector('#region-main') ?? page.document.body;
    if (root == null) continue;
    for (final anchor in root.querySelectorAll('.activityinstance > a[href]')) {
      final link = _activityLink(anchor, courseName, base: page.url);
      if (link == null) continue;
      modules[link.id] = link;
    }
  }

  final outcomes = await Future.wait([
    for (final module in modules.values)
      _attempt(() async {
        final response = await session.request(module.url, stopAtLogin: true);
        return _parseActivity(module, html.parse(response.text));
      }),
  ], eagerError: true);
  final entries = <AgendaEntry>[];
  for (final outcome in outcomes) {
    final entry = outcome.value;
    if (entry != null) {
      entries.add(entry);
    } else {
      firstFailure ??= outcome.error;
      firstStack ??= outcome.stack;
    }
  }
  return (entries: entries, error: firstFailure, stack: firstStack);
}

Future<({dom.Document document, Uri url})?> _courseSection(
  SchoolSession session,
  _CourseLink course,
  int section,
) async {
  final response = await session.request(
    course.url.replace(
      queryParameters: {'id': course.id, 'section': '$section'},
    ),
    stopAtLogin: true,
  );
  return (document: html.parse(response.text), url: response.url);
}

Map<String, _CourseLink> _courseLinks(String source, {required Uri base}) {
  final result = <String, _CourseLink>{};
  for (final anchor
      in html.parse(source).querySelectorAll('a[href*="course/view.php"]')) {
    final url = _schoolUri(anchor.attributes['href'], base: base);
    final courseId = url?.queryParameters['id'];
    if (url == null || courseId == null || courseId.isEmpty) continue;
    result[courseId] = (
      id: courseId,
      name: _text(anchor) ?? '乐学课程',
      url: url.replace(queryParameters: {'id': courseId}),
    );
  }
  return result;
}

Set<int> _sectionIds(dom.Document page, String courseId, {required Uri base}) =>
    {
      for (final anchor in page.querySelectorAll('a[href*="course/view.php"]'))
        if (int.tryParse(
              _schoolUri(
                    anchor.attributes['href'],
                    base: base,
                  )?.queryParameters['section'] ??
                  '',
            )
            case final section?)
          if (_schoolUri(
                anchor.attributes['href'],
                base: base,
              )?.queryParameters['id'] ==
              courseId)
            section,
    };

_ActivityLink? _activityLink(
  dom.Element anchor,
  String course, {
  required Uri base,
}) {
  final url = _schoolUri(anchor.attributes['href'], base: base);
  final id = url?.queryParameters['id'];
  if (url == null || id == null || id.isEmpty) return null;
  final path = url.pathSegments;
  if (path.length < 3 ||
      path.first != 'mod' ||
      path[2] != 'view.php' ||
      !_activityModules.contains(path[1])) {
    return null;
  }
  final title = _text(anchor);
  if (title == null) return null;
  return (
    id: 'lexue-cmid-$id',
    course: course,
    title: title,
    url: url.replace(queryParameters: {'id': id}, fragment: ''),
  );
}

AgendaEntry? _parseActivity(_ActivityLink module, dom.Document page) {
  final dates = page.querySelector('[data-region="activity-dates"]');
  if (dates == null) return null;
  final due = _activityDueDate(dates);
  if (due == null) return null;
  return AgendaEntry(
    id: module.id,
    title: module.title,
    kind: AgendaKind.deadline,
    startsAt: due,
    done: _activityCompleted(page),
    notes: '',
    course: module.course,
    source: DeadlineSource.lexue,
    local: false,
    url: module.url,
  );
}

DateTime? _activityDueDate(dom.Element dates) {
  final lines = dates.children.isEmpty
      ? [dates.text]
      : [for (final line in dates.children) line.text];
  for (final text in lines) {
    final normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (!RegExp(
      r'\b(?:due|closes?)\b|到期|截止',
      caseSensitive: false,
    ).hasMatch(normalized)) {
      continue;
    }
    final value = _moodleDate(normalized);
    if (value != null) return value;
  }
  return null;
}

DateTime? _moodleDate(String text) {
  final match = RegExp(
    r'(\d{4})年\s*(\d{1,2})月\s*(\d{1,2})日[^\d]*'
    r'(上午|下午|晚上)?\s*(\d{1,2}):(\d{2})',
  ).firstMatch(text);
  if (match == null) return null;
  var hour = int.parse(match[5]!);
  if (match[4] == '下午' || match[4] == '晚上') {
    if (hour < 12) hour += 12;
  }
  return DateTime.utc(
    int.parse(match[1]!),
    int.parse(match[2]!),
    int.parse(match[3]!),
    hour,
    int.parse(match[6]!),
  );
}

bool _activityCompleted(dom.Document page) {
  if (page.querySelector(
        '[data-region="completion-info"] [data-toggletype="manual:undo"]',
      ) !=
      null) {
    return true;
  }
  if (page.querySelector('.submissionstatussubmitted') != null) return true;
  final conditions = page.querySelectorAll(
    '[data-region="completionrequirements"] [role="listitem"]',
  );
  return conditions.isNotEmpty &&
      conditions.every(
        (condition) => condition.classes.contains('badge-success'),
      );
}

List<AgendaEntry> _mergeActivityDeadlines(
  List<AgendaEntry> calendar,
  List<AgendaEntry> activities,
) {
  final result = [...calendar];
  for (final activity in activities) {
    final index = result.indexWhere(
      (entry) => _sameLexueDeadline(entry, activity),
    );
    if (index < 0) {
      if (!result.any((entry) => entry.id == activity.id)) {
        result.add(activity);
      }
      continue;
    }
    final existing = result[index];
    result[index] = AgendaEntry(
      id: existing.id,
      title: activity.title,
      kind: activity.kind,
      startsAt: activity.startsAt,
      allDay: activity.allDay,
      notes: activity.notes,
      done: existing.done || activity.done,
      deleted: existing.deleted,
      local: existing.local,
      source: activity.source,
      course: activity.course,
      url: activity.url,
    );
  }
  return result;
}

bool _sameLexueDeadline(AgendaEntry left, AgendaEntry right) {
  final leftUrl = left.url;
  final rightUrl = right.url;
  if (leftUrl != null &&
      rightUrl != null &&
      leftUrl.host == rightUrl.host &&
      leftUrl.path == rightUrl.path &&
      leftUrl.queryParameters['id'] == rightUrl.queryParameters['id']) {
    return true;
  }
  return left.course == right.course &&
      left.title == right.title &&
      left.startsAt == right.startsAt &&
      left.allDay == right.allDay;
}

Future<Set<String>> _completedLexueEvents(
  SchoolSession session,
  String sesskey,
  List<AgendaEntry> entries,
) async {
  if (entries.isEmpty) return {};

  // Moodle's ICS UID is the calendar event ID followed by the site's hostname.
  final events = await _lexueAjax(session, sesskey, [
    for (final entry in entries) _eventRequest(entry),
  ]);
  if (events.length != entries.length) {
    throw const FormatException('乐学返回的日历事件数量不一致');
  }
  final modulesByEvent = <String, int>{};
  for (var index = 0; index < events.length; index++) {
    final moduleId = _moduleId(events[index]);
    if (moduleId != null) modulesByEvent[entries[index].id] = moduleId;
  }
  final moduleIds = modulesByEvent.values.toSet().toList();
  if (moduleIds.isEmpty) return {};

  final modules = await _lexueAjax(session, sesskey, [
    for (final id in moduleIds)
      (method: 'core_course_get_module', args: {'id': id}),
  ]);
  if (modules.length != moduleIds.length) {
    throw const FormatException('乐学返回的课程模块数量不一致');
  }
  final completedModules = <int>{};
  for (var index = 0; index < modules.length; index++) {
    final activity = html.parseFragment(jsonString(modules[index], '课程模块'));
    final manuallyCompleted =
        activity.querySelector('[data-toggletype="manual:undo"]') != null;
    final submitted =
        activity.querySelector('.submissionstatussubmitted') != null;
    final conditions = activity.querySelectorAll(
      '[data-region="completionrequirements"] [role="listitem"]',
    );
    final automaticallyCompleted =
        conditions.isNotEmpty &&
        conditions.every(
          (condition) => condition.classes.contains('badge-success'),
        );

    if (manuallyCompleted || submitted || automaticallyCompleted) {
      completedModules.add(moduleIds[index]);
    }
  }
  return {
    for (final entry in modulesByEvent.entries)
      if (completedModules.contains(entry.value)) entry.key,
  };
}

int? _moduleId(Object? value) {
  final result = jsonObject(value, '日历事件响应');
  final event = jsonObjectField(result, 'event');
  final moduleId = event['instance'];
  if (moduleId == null) return null;
  return jsonInt(moduleId, 'event.instance');
}

({String method, Map<String, Object> args}) _eventRequest(AgendaEntry entry) {
  final value = entry.id.substring('lexue-'.length).split('@').first;
  final eventId = int.tryParse(value);
  if (eventId == null) {
    throw FormatException('乐学事件编号格式不正确：${entry.id}');
  }
  return (
    method: 'core_calendar_get_calendar_event_by_id',
    args: {'eventid': eventId},
  );
}

Future<List<dynamic>> _lexueAjax(
  SchoolSession session,
  String sesskey,
  List<({String method, Map<String, Object> args})> calls,
) async {
  final response = await session.request(
    DeadlineSource.lexue.origin
        .resolve('/lib/ajax/service.php')
        .replace(queryParameters: {'sesskey': sesskey}),
    jsonBody: [
      for (final (index, call) in calls.indexed)
        {'index': index, 'methodname': call.method, 'args': call.args},
    ],
    headers: {
      'Accept': 'application/json',
      'X-Requested-With': 'XMLHttpRequest',
    },
    stopAtLogin: true,
  );
  final results = [
    for (final value in jsonList(jsonDecode(response.text), '乐学接口响应'))
      jsonObject(value, '乐学接口响应[]'),
  ];
  return [
    for (final result in results)
      if (jsonBool(result['error'], 'error', fallback: false))
        throw SchoolRequestError(
          jsonStringOrNull(
                jsonObjectField(result, 'exception')['message'],
                'exception.message',
              ) ??
              '乐学接口返回错误',
        )
      else
        result['data'],
  ];
}

List<AgendaEntry> _parseLexueCalendar(String calendar) {
  final unfolded = calendar.replaceAll(RegExp(r'\r?\n[ \t]'), '');
  final result = <AgendaEntry>[];
  for (final block in unfolded.split('BEGIN:VEVENT').skip(1)) {
    final properties = <String, ({String parameters, String value})>{};
    for (final line
        in block.split('END:VEVENT').first.split(RegExp(r'\r?\n'))) {
      final colon = line.indexOf(':');
      if (colon < 0) continue;
      final key = line.substring(0, colon);
      properties[key.split(';').first] = (
        parameters: key,
        value: _unescapeCalendarText(line.substring(colon + 1)),
      );
    }
    final start = _property(properties, 'DTSTART');
    final dateOnly = start.value.length == 8;
    final rawUrl = properties['URL']?.value;
    final taskUrl = rawUrl == null ? null : Uri.tryParse(rawUrl);
    result.add(
      AgendaEntry(
        id: 'lexue-${_property(properties, 'UID').value}',
        title: _property(properties, 'SUMMARY').value,
        kind: AgendaKind.deadline,
        startsAt: _calendarDate(start.value, start.parameters),
        allDay: dateOnly,
        notes:
            html
                .parse(properties['DESCRIPTION']?.value ?? '')
                .body
                ?.text
                .trim() ??
            '',
        course: properties['CATEGORIES']?.value ?? '',
        source: DeadlineSource.lexue,
        local: false,
        url:
            taskUrl != null &&
                taskUrl.scheme == 'https' &&
                taskUrl.host == DeadlineSource.lexue.host &&
                taskUrl.userInfo.isEmpty &&
                (taskUrl.path.startsWith('/mod/') ||
                    taskUrl.path.startsWith('/course/'))
            ? taskUrl
            : null,
      ),
    );
  }
  return result;
}

({String parameters, String value}) _property(
  Map<String, ({String parameters, String value})> properties,
  String key,
) => properties[key] ?? (throw FormatException('乐学日历事件缺少 $key'));

String _unescapeCalendarText(String value) => value.replaceAllMapped(
  RegExp(r'\\([nN,;\\])'),
  (match) => switch (match[1]) {
    'n' || 'N' => '\n',
    _ => match[1]!,
  },
);

DateTime _calendarDate(String value, String parameters) {
  final parsed = DateTime.parse(value);
  final date = DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
  );
  final timezone = parameters
      .split(';')
      .where((part) => part.startsWith('TZID='))
      .firstOrNull
      ?.substring(5)
      .replaceAll('"', '');
  if (parsed.isUtc || timezone == 'UTC') {
    return date.add(const Duration(hours: 8));
  }
  return date;
}

String? _courseName(dom.Document page) {
  final heading =
      page.querySelector('#page-header h1') ?? page.querySelector('h1');
  return _text(heading);
}

String? _text(dom.Element? element) {
  final value = element?.text.trim().replaceAll(RegExp(r'\s+'), ' ');
  return value == null || value.isEmpty ? null : value;
}

Uri? _schoolUri(String? value, {required Uri base}) {
  if (value == null) return null;
  final parsed = Uri.tryParse(value.trim());
  if (parsed == null || parsed.userInfo.isNotEmpty) return null;
  final uri = parsed.hasScheme ? parsed : base.resolveUri(parsed);
  if (!uri.hasScheme ||
      uri.host != DeadlineSource.lexue.host ||
      (uri.scheme != 'https' && uri.scheme != 'http')) {
    return null;
  }
  return uri.replace(scheme: 'https');
}

Future<({T? value, Object? error, StackTrace? stack})> _attempt<T>(
  Future<T> Function() operation,
) async {
  try {
    return (value: await operation(), error: null, stack: null);
  } on RequestCancelled {
    rethrow;
  } on SessionExpired {
    rethrow;
  } on Exception catch (error, stack) {
    return (value: null, error: error, stack: stack);
  }
}

typedef _CourseLink = ({String id, String name, Uri url});
typedef _ActivityLink = ({String id, String course, String title, Uri url});
typedef _ActivityScan = ({
  List<AgendaEntry> entries,
  Object? error,
  StackTrace? stack,
});
