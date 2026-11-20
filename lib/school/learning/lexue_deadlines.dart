import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;

import '../../agenda/deadline_source.dart';
import '../../agenda/model.dart';
import '../../core/async/cancelable_request.dart';
import '../../core/json.dart';
import '../errors.dart';
import '../session.dart';

part 'lexue_calendar.dart';
part 'lexue_merge.dart';

const _activityModules = {
  'assign',
  'choice',
  'feedback',
  'forum',
  'h5pactivity',
  'lesson',
  'programming',
  'quiz',
  'scorm',
  'workshop',
};

Future<List<AgendaEntry>> fetchLexueDeadlines(
  SchoolSession session,
  SchoolResponse page,
) async {
  final sesskey = _sesskey(page.text);
  final outcomes = await Future.wait([
    if (sesskey == null)
      Future.value((value: const <AgendaEntry>[], error: null, stack: null))
    else
      _attempt(() => _calendarDeadlines(session, sesskey)),
    _attempt(() => _activityDeadlines(session, sesskey: sesskey)),
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
    return await _resolveCalendarEvents(session, sesskey, entries);
  } on RequestCancelled {
    rethrow;
  } on SessionExpired {
    rethrow;
  } on Exception {
    return [for (final entry in entries) _canonicalizeLexueEntry(entry)];
  }
}

Future<List<AgendaEntry>> _activityDeadlines(
  SchoolSession session, {
  String? sesskey,
}) async {
  final source = DeadlineSource.lexue;
  final home = await session.request(
    source.origin.resolve('/my/'),
    stopAtLogin: true,
  );
  final courses = _courseLinks(home.text, base: home.url);
  final effectiveSesskey = sesskey ?? _sesskey(home.text);
  if (effectiveSesskey != null) {
    final enrolled = await _attempt(
      () => _enrolledCourses(session, effectiveSesskey),
    );
    if (enrolled.value case final extra?) {
      for (final entry in extra.entries) {
        courses.putIfAbsent(entry.key, () => entry.value);
      }
    }
  }
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
    for (final anchor in root.querySelectorAll(
      '.activityinstance > a[href], .activityname a[href]',
    )) {
      final link = _activityLink(anchor, courseName, base: page.url);
      if (link == null) continue;
      modules[link.id] = link;
    }
  }

  final outcomes = await Future.wait([
    for (final module in modules.values)
      _attempt(() => _fetchActivity(session, module)),
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
    module: path[1],
    course: course,
    title: title,
    url: url.removeFragment().replace(queryParameters: {'id': id}),
  );
}

Future<AgendaEntry?> _fetchActivity(
  SchoolSession session,
  _ActivityLink module,
) async {
  final response = await session.request(module.url, stopAtLogin: true);
  final page = html.parse(response.text);
  if (module.module == 'programming') {
    return _parseProgrammingActivity(session, module, page);
  }
  return _parseActivity(module, page);
}

AgendaEntry? _parseActivity(_ActivityLink module, dom.Document page) {
  final due = _parseActivityDueDate(module, page);
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

Future<AgendaEntry?> _parseProgrammingActivity(
  SchoolSession session,
  _ActivityLink module,
  dom.Document page,
) async {
  final dates = _programmingDates(page);
  final due = dates.discount ?? dates.close;
  if (due == null) return null;

  final notes =
      dates.discount != null &&
          dates.close != null &&
          dates.close != dates.discount
      ? '关闭时间：${dates.closeText}'
      : '';
  return AgendaEntry(
    id: module.id,
    title: module.title,
    kind: AgendaKind.deadline,
    startsAt: due,
    done: await _programmingCompleted(session, module.url),
    notes: notes,
    course: module.course,
    source: DeadlineSource.lexue,
    local: false,
    url: module.url,
  );
}

({DateTime? discount, DateTime? close, String? closeText}) _programmingDates(
  dom.Document page,
) {
  final table = page.querySelector('.time-table');
  if (table == null) return (discount: null, close: null, closeText: null);

  DateTime? discount;
  DateTime? close;
  String? closeText;
  for (final row in table.querySelectorAll('tr')) {
    final cells = row.querySelectorAll('th, td');
    for (var index = 0; index + 1 < cells.length; index += 2) {
      final label = _text(cells[index]);
      final value = _text(cells[index + 1]);
      if (label == null || value == null) continue;
      if (RegExp(
        r'折扣时间|\bdiscount\s*time\b',
        caseSensitive: false,
      ).hasMatch(label)) {
        discount ??= _moodleDate(value);
      } else if (RegExp(
        r'关闭时间|\b(?:time\s*close|close\s*time)\b',
        caseSensitive: false,
      ).hasMatch(label)) {
        final parsed = _moodleDate(value);
        if (parsed != null && close == null) {
          close = parsed;
          closeText = value;
        }
      }
    }
  }
  return (discount: discount, close: close, closeText: closeText);
}

Future<bool> _programmingCompleted(
  SchoolSession session,
  Uri activityUrl,
) async {
  try {
    final response = await session.request(
      activityUrl.replace(path: '/mod/programming/result.php'),
      stopAtLogin: true,
    );
    return _programmingResultPassed(html.parse(response.text));
  } on RequestCancelled {
    rethrow;
  } on SessionExpired {
    rethrow;
  } on Exception {
    return false;
  }
}

bool _programmingResultPassed(dom.Document page) {
  final detail = page.querySelector('#test-result-detail');
  if (detail == null) return false;

  final text = _text(detail) ?? '';
  final zhSummary = RegExp(
    r'共\s*(\d+)\s*个测试用例.*?通过了其中的\s*(\d+)\s*个.*?未能通过的有\s*(\d+)\s*个',
  ).firstMatch(text);
  if (zhSummary != null) {
    final total = int.parse(zhSummary[1]!);
    final passed = int.parse(zhSummary[2]!);
    final failed = int.parse(zhSummary[3]!);
    return total > 0 && passed == total && failed == 0;
  }

  final enSummary = RegExp(
    r'\b(\d+)\s+passed\b.*?\b(\d+)\s+failed\b',
    caseSensitive: false,
  ).firstMatch(text);
  if (enSummary != null) {
    final passed = int.parse(enSummary[1]!);
    final failed = int.parse(enSummary[2]!);
    return passed > 0 && failed == 0;
  }

  final rows = detail.querySelectorAll('table tbody tr');
  return rows.isNotEmpty && rows.every((row) => row.classes.contains('passed'));
}

DateTime? _parseActivityDueDate(_ActivityLink module, dom.Document page) {
  final dates = page.querySelector('[data-region="activity-dates"]');
  if (dates != null) {
    final due = _activityDueDate(dates);
    if (due != null) return due;
  }
  if (module.module == 'quiz') {
    final quizInfo = page.querySelector('.quizinfo');
    if (quizInfo != null) return _activityDueDate(quizInfo);
  }
  return null;
}

DateTime? _activityDueDate(dom.Element dates) {
  final lines = dates.children.isEmpty
      ? [dates.text]
      : [for (final line in dates.children) line.text];
  for (final text in lines) {
    final normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (!RegExp(
      r'\b(?:due|clos(?:es?|ed))\b|到期|截止|关闭',
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

Future<List<AgendaEntry>> _resolveCalendarEvents(
  SchoolSession session,
  String sesskey,
  List<AgendaEntry> entries,
) async {
  if (entries.isEmpty) return entries;

  // Moodle's ICS UID is the calendar event ID followed by the site's hostname.
  final requests = <({String entryId, _LexueAjaxCall call})>[
    for (final entry in entries)
      if (_calendarEventId(entry) case final eventId?)
        (
          entryId: entry.id,
          call: (
            method: 'core_calendar_get_calendar_event_by_id',
            args: {'eventid': eventId},
          ),
        ),
  ];
  final modulesByEvent = <String, int>{};
  final urlsByEvent = <String, Uri>{};
  if (requests.isNotEmpty) {
    final events = await _lexueAjaxBestEffort(session, sesskey, [
      for (final request in requests) request.call,
    ]);
    for (var index = 0; index < events.length; index++) {
      final raw = events[index];
      if (raw == null) continue;
      try {
        final event = jsonObjectField(jsonObject(raw, '日历事件响应'), 'event');
        final eventUrl = _calendarEventUrl(event);
        if (eventUrl != null) urlsByEvent[requests[index].entryId] = eventUrl;
        final moduleId = _moduleId(event) ?? _cmidFromUrl(eventUrl);
        if (moduleId != null) {
          modulesByEvent[requests[index].entryId] = moduleId;
        }
      } on Exception {
        continue;
      }
    }
  }

  final completedModules = <int>{};
  final moduleIds = modulesByEvent.values.toSet().toList();
  if (moduleIds.isNotEmpty) {
    final modules = await _lexueAjaxBestEffort(session, sesskey, [
      for (final id in moduleIds)
        (method: 'core_course_get_module', args: {'id': id}),
    ]);
    for (var index = 0; index < modules.length; index++) {
      final raw = modules[index];
      if (raw is! String) continue;
      if (_moduleCompleted(html.parseFragment(raw))) {
        completedModules.add(moduleIds[index]);
      }
    }
  }

  return [
    for (final entry in entries)
      _canonicalizeLexueEntry(
        entry,
        url: entry.url ?? urlsByEvent[entry.id],
        done: entry.done || completedModules.contains(modulesByEvent[entry.id]),
      ),
  ];
}

Future<Map<String, _CourseLink>> _enrolledCourses(
  SchoolSession session,
  String sesskey,
) async {
  final responses = await _lexueAjaxBestEffort(session, sesskey, [
    (
      method: 'core_course_get_enrolled_courses_by_timeline_classification',
      args: {
        'classification': 'inprogress',
        'limit': 0,
        'offset': 0,
        'sort': 'fullname',
      },
    ),
  ]);
  final data = responses.firstOrNull;
  if (data is! Map) return const {};
  final rawCourses = jsonObject(data, '乐学课程响应')['courses'];
  if (rawCourses is! List) return const {};

  final result = <String, _CourseLink>{};
  for (final item in rawCourses) {
    if (item is! Map) continue;
    final course = jsonObject(item, '乐学课程');
    final rawId = course['id'];
    if (rawId == null) continue;
    final id = jsonInt(rawId, 'course.id');
    if (id <= 1) continue;
    final courseId = '$id';
    final name = jsonStringOrNull(
      course['fullname'],
      'course.fullname',
    )?.trim();
    final viewUrl = _schoolUri(
      jsonStringOrNull(course['viewurl'], 'course.viewurl'),
      base: DeadlineSource.lexue.origin,
    );
    result[courseId] = (
      id: courseId,
      name: name == null || name.isEmpty ? '乐学课程' : name,
      url:
          (viewUrl ??
                  DeadlineSource.lexue.origin.replace(path: '/course/view.php'))
              .removeFragment()
              .replace(queryParameters: {'id': courseId}),
    );
  }
  return result;
}

bool _moduleCompleted(dom.DocumentFragment activity) {
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
  return manuallyCompleted || submitted || automaticallyCompleted;
}

int? _moduleId(Map<String, dynamic> event) {
  final moduleId = event['instance'];
  if (moduleId == null) return null;
  final id = jsonInt(moduleId, 'event.instance');
  return id > 0 ? id : null;
}

Uri? _calendarEventUrl(Map<String, dynamic> event) {
  final direct = _lexueEventUri(jsonStringOrNull(event['url'], 'event.url'));
  if (direct != null && direct.path.startsWith('/mod/')) return direct;

  Uri? actionUrl;
  final action = event['action'];
  if (action is Map) {
    final actionMap = jsonObject(action, 'event.action');
    actionUrl = _lexueEventUri(
      jsonStringOrNull(actionMap['url'], 'event.action.url'),
    );
    if (actionUrl != null && actionUrl.path.startsWith('/mod/')) {
      return actionUrl;
    }
  }

  final moduleUrl = _moduleUri(event);
  if (moduleUrl != null) return moduleUrl;

  if (direct != null && direct.path.startsWith('/course/')) return direct;
  if (actionUrl != null && actionUrl.path.startsWith('/course/')) {
    return actionUrl;
  }

  final courseUrl = _courseEventUri(event);
  if (courseUrl != null) return courseUrl;

  return direct ??
      actionUrl ??
      _lexueEventUri(jsonStringOrNull(event['viewurl'], 'event.viewurl'));
}

Uri? _moduleUri(Map<String, dynamic> event) {
  final moduleId = _moduleId(event);
  final moduleName = jsonStringOrNull(event['modulename'], 'event.modulename');
  if (moduleId == null ||
      moduleName == null ||
      !RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(moduleName)) {
    return null;
  }
  return DeadlineSource.lexue.origin.replace(
    path: '/mod/$moduleName/view.php',
    queryParameters: {'id': '$moduleId'},
  );
}

Uri? _courseEventUri(Map<String, dynamic> event) {
  final course = event['course'];
  if (course is! Map) return null;
  final courseMap = jsonObject(course, 'event.course');
  final viewUrl = _lexueEventUri(
    jsonStringOrNull(courseMap['viewurl'], 'event.course.viewurl'),
  );
  if (viewUrl != null && viewUrl.path.startsWith('/course/')) return viewUrl;
  final rawId = courseMap['id'];
  if (rawId == null) return null;
  final courseId = jsonInt(rawId, 'event.course.id');
  if (courseId <= 1) return null;
  return DeadlineSource.lexue.origin.replace(
    path: '/course/view.php',
    queryParameters: {'id': '$courseId'},
  );
}

Uri? _lexueEventUri(String? raw) {
  final uri = _schoolUri(raw, base: DeadlineSource.lexue.origin);
  if (uri == null) return null;
  if (!uri.path.startsWith('/mod/') &&
      !uri.path.startsWith('/course/') &&
      !uri.path.startsWith('/calendar/')) {
    return null;
  }
  return uri;
}

String? _canonicalLexueId(Uri? url) {
  if (url == null) return null;
  final id = url.queryParameters['id'];
  final path = url.pathSegments;
  if (id == null ||
      id.isEmpty ||
      path.length < 3 ||
      path.first != 'mod' ||
      path[2] != 'view.php') {
    return null;
  }
  return 'lexue-cmid-$id';
}

int? _cmidFromUrl(Uri? url) {
  final canonical = _canonicalLexueId(url);
  if (canonical == null) return null;
  final id = int.tryParse(canonical.substring('lexue-cmid-'.length));
  return id != null && id > 0 ? id : null;
}

AgendaEntry _canonicalizeLexueEntry(AgendaEntry entry, {Uri? url, bool? done}) {
  final resolvedUrl = url ?? entry.url;
  final canonicalId = _canonicalLexueId(resolvedUrl) ?? entry.id;
  final resolvedDone = done ?? entry.done;
  if (canonicalId == entry.id &&
      resolvedUrl == entry.url &&
      resolvedDone == entry.done) {
    return entry;
  }
  return AgendaEntry(
    id: canonicalId,
    title: entry.title,
    kind: entry.kind,
    startsAt: entry.startsAt,
    allDay: entry.allDay,
    notes: entry.notes,
    done: resolvedDone,
    deleted: entry.deleted,
    local: entry.local,
    source: entry.source,
    course: entry.course,
    url: resolvedUrl,
  );
}

int? _calendarEventId(AgendaEntry entry) {
  if (!entry.id.startsWith('lexue-')) return null;
  final value = entry.id.substring('lexue-'.length).split('@').first;
  final eventId = int.tryParse(value);
  return eventId != null && eventId > 0 ? eventId : null;
}

String? _sesskey(String htmlText) =>
    RegExp(r'''["']sesskey["']\s*:\s*["']([^"']+)["']''')
        .firstMatch(htmlText)?[1];

Future<List<dynamic>> _lexueAjaxBestEffort(
  SchoolSession session,
  String sesskey,
  List<_LexueAjaxCall> calls,
) async {
  if (calls.isEmpty) return const [];
  final results = List<dynamic>.filled(calls.length, null);

  final batch = await _attempt(() => _lexueAjaxRaw(session, sesskey, calls));
  var retryFrom = 0;
  if (batch.value case final responses?) {
    var failedAt = -1;
    for (
      var index = 0;
      index < responses.length && index < calls.length;
      index++
    ) {
      final result = responses[index];
      if (jsonBool(result['error'], 'error', fallback: false)) {
        _rethrowIfSessionExpired(result);
        failedAt = index;
        break;
      }
      results[index] = result['data'];
    }
    if (failedAt < 0 && responses.length >= calls.length) return results;
    // Moodle stops executing a batch at the first error; keep everything before
    // it and retry only the calls Moodle never reached.
    retryFrom = failedAt >= 0 ? failedAt + 1 : responses.length;
  }

  if (calls.length == 1 || retryFrom >= calls.length) return results;

  final remaining = await Future.wait([
    for (var index = retryFrom; index < calls.length; index++)
      _attempt(() async {
        final responses = await _lexueAjaxRaw(session, sesskey, [calls[index]]);
        if (responses.isEmpty) return null;
        final result = responses.first;
        if (jsonBool(result['error'], 'error', fallback: false)) {
          _rethrowIfSessionExpired(result);
          return null;
        }
        return result['data'];
      }),
  ], eagerError: true);

  for (var offset = 0; offset < remaining.length; offset++) {
    results[retryFrom + offset] = remaining[offset].value;
  }
  return results;
}

Future<List<Map<String, dynamic>>> _lexueAjaxRaw(
  SchoolSession session,
  String sesskey,
  List<_LexueAjaxCall> calls,
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
  return [
    for (final value in jsonList(jsonDecode(response.text), '乐学接口响应'))
      jsonObject(value, '乐学接口响应[]'),
  ];
}

void _rethrowIfSessionExpired(Map<String, dynamic> result) {
  final exception = result['exception'];
  if (exception is! Map) return;
  final code = jsonStringOrNull(exception['errorcode'], 'exception.errorcode');
  if (code == 'servicerequireslogin') {
    throw const SessionExpired();
  }
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

typedef _LexueAjaxCall = ({String method, Map<String, Object> args});
typedef _CourseLink = ({String id, String name, Uri url});
typedef _ActivityLink = ({
  String id,
  String module,
  String course,
  String title,
  Uri url,
});
typedef _ActivityScan = ({
  List<AgendaEntry> entries,
  Object? error,
  StackTrace? stack,
});
