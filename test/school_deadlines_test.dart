import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bitree/agenda/controller.dart';
import 'package:bitree/agenda/deadline_source.dart';
import 'package:bitree/agenda/model.dart';
import 'package:bitree/school/learning/eclass_deadlines.dart';
import 'package:bitree/school/learning/lexue_deadlines.dart';
import 'package:bitree/school/network.dart';
import 'package:bitree/school/session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/http.dart';
import 'support/test_app.dart';

void main() {
  test('Eclass course scanning keeps later courses when one course fails', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final paths = <String>[];
    server.listen((request) async {
      paths.add(request.uri.path);
      switch (request.uri.path) {
        case '/zy-eclass.bit.edu.cn/api/my-courses':
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'courses': [
                {'id': 1, 'name': '暂时不可用的课程'},
                {'id': 20759, 'name': '大学物理AⅡ'},
              ],
            }),
          );
        case '/zy-eclass.bit.edu.cn/api/courses/1/activities':
          request.response.statusCode = HttpStatus.serviceUnavailable;
          request.response.write('temporarily unavailable');
        case '/zy-eclass.bit.edu.cn/api/courses/20759/activities':
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'activities': [
                {
                  'id': 9058,
                  'type': 'homework',
                  'title': '第4次作业：卷三第二章习题 18、21、23、24、27、29、31、35',
                  'end_time': '2026-11-02T15:59:00Z',
                  'visible_end_at': null,
                },
                {
                  'id': 9060,
                  'type': 'quiz',
                  'title': '第三章单元测验',
                  'end_time': '2026-11-03T15:59:00Z',
                  'visible_end_at': null,
                },
              ],
            }),
          );
        case '/zy-eclass.bit.edu.cn/api/course/20759/homework/submission-status':
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'course_id': 20759,
              'homework_activities': [
                {'id': 9058, 'status_code': 'absent'},
              ],
            }),
          );
        case '/zy-eclass.bit.edu.cn/api/activities/9060':
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({'user_submit_count': 1}));
        default:
          request.response.statusCode = HttpStatus.notFound;
          request.response.write('unexpected request');
      }
      await request.response.close();
    });

    SchoolSession? session;
    addTearDown(() => session?.close());
    final entries = await HttpOverrides.runWithHttpOverrides(() {
      session = SchoolSession(
        network: SchoolNetwork.campus,
        storage: MemorySchoolStorage(),
      );
      return fetchEclassDeadlines(session!);
    }, LocalHttpOverrides(server.port));

    expect(entries, hasLength(2));
    final homework = entries.singleWhere((entry) => entry.id == 'eclass-9058');
    expect(homework.course, '大学物理AⅡ');
    expect(homework.startsAt, DateTime.utc(2026, 11, 2, 23, 59));
    expect(homework.done, isFalse);
    final quiz = entries.singleWhere((entry) => entry.id == 'eclass-9060');
    expect(quiz.startsAt, DateTime.utc(2026, 11, 3, 23, 59));
    expect(quiz.done, isTrue);
    expect(paths, isNot(contains('/zy-eclass.bit.edu.cn/api/todos')));
    expect(
      paths,
      contains(
        '/zy-eclass.bit.edu.cn/api/course/20759/homework/submission-status',
      ),
    );
    expect(paths, isNot(contains('/zy-eclass.bit.edu.cn/api/activities/9058')));
    expect(paths, contains('/zy-eclass.bit.edu.cn/api/activities/9060'));
  });

  test('Eclass courses scan concurrently within the request limit', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final activityCourses = <String>[];
    final statusCourses = <String>[];
    var active = 0;
    var maxActive = 0;
    var detailRequests = 0;

    Future<void> sendJson(
      HttpRequest request,
      Object body, {
      bool delay = true,
    }) async {
      active++;
      if (active > maxActive) maxActive = active;
      try {
        if (delay) await Future<void>.delayed(const Duration(milliseconds: 30));
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(body));
        await request.response.close();
      } finally {
        active--;
      }
    }

    server.listen((request) async {
      final path = request.uri.path;
      if (path == '/zy-eclass.bit.edu.cn/api/my-courses') {
        await sendJson(request, {
          'courses': [
            {'id': 100, 'name': '多作业课程'},
            for (var index = 0; index < 5; index++)
              {'id': 200 + index, 'name': '课程${index + 1}'},
          ],
        });
        return;
      }

      final activity = RegExp(
        r'^/zy-eclass\.bit\.edu\.cn/api/courses/(\d+)/activities$',
      ).firstMatch(path);
      if (activity != null) {
        final courseId = activity[1]!;
        activityCourses.add(courseId);
        final ids = courseId == '100' ? [101, 102] : [int.parse(courseId) * 10];
        await sendJson(request, {
          'activities': [
            for (final id in ids)
              {
                'id': id,
                'type': 'homework',
                'title': '作业$id',
                'end_time': '2026-11-02T15:59:00Z',
                'visible_end_at': null,
              },
          ],
        });
        return;
      }

      final status = RegExp(
        r'^/zy-eclass\.bit\.edu\.cn/api/course/(\d+)/homework/submission-status$',
      ).firstMatch(path);
      if (status != null) {
        final courseId = status[1]!;
        statusCourses.add(courseId);
        final ids = courseId == '100' ? [101, 102] : [int.parse(courseId) * 10];
        await sendJson(request, {
          'course_id': int.parse(courseId),
          'homework_activities': [
            for (final id in ids)
              {'id': id, 'status_code': id == 101 ? 'submitted' : 'absent'},
          ],
        }, delay: false);
        return;
      }

      if (path.startsWith('/zy-eclass.bit.edu.cn/api/activities/')) {
        detailRequests++;
      }
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('unexpected request');
      await request.response.close();
    });

    SchoolSession? session;
    addTearDown(() => session?.close());
    final entries = await HttpOverrides.runWithHttpOverrides(() {
      session = SchoolSession(
        network: SchoolNetwork.campus,
        storage: MemorySchoolStorage(),
      );
      return fetchEclassDeadlines(session!);
    }, LocalHttpOverrides(server.port));

    expect(entries, hasLength(7));
    expect(
      entries.singleWhere((entry) => entry.id == 'eclass-101').done,
      isTrue,
    );
    expect(
      activityCourses,
      unorderedEquals(['100', '200', '201', '202', '203', '204']),
    );
    expect(
      statusCourses,
      unorderedEquals(['100', '200', '201', '202', '203', '204']),
    );
    expect(detailRequests, 0);
    expect(maxActive, inInclusiveRange(2, 4));
  });

  test(
    'Lexue activity pages supply deadlines missing from calendar export',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final activityIds = <String>[];
      server.listen((request) async {
        final path = request.uri.path;
        switch (path) {
          case '/lexue.bit.edu.cn/calendar/export.php':
            request.response.headers.contentType = ContentType(
              'text',
              'html',
              charset: 'utf-8',
            );
            request.response.write(
              '<div class="calendarurl">'
              'https://lexue.bit.edu.cn/calendar/export_execute.php'
              '</div>',
            );
          case '/lexue.bit.edu.cn/calendar/export_execute.php':
            request.response.write('BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n');
          case '/lexue.bit.edu.cn/my/':
            request.response.headers.contentType = ContentType(
              'text',
              'html',
              charset: 'utf-8',
            );
            request.response.write(
              '<a href="/course/view.php?id=1">不可访问课程</a>'
              '<a href="https://lexue.bit.edu.cn/course/view.php?id=18553">'
              '概率论与数理统计</a>',
            );
          case '/lexue.bit.edu.cn/course/view.php':
            if (request.uri.queryParameters['id'] == '1') {
              request.response.statusCode = HttpStatus.serviceUnavailable;
              break;
            }
            request.response.headers.contentType = ContentType(
              'text',
              'html',
              charset: 'utf-8',
            );
            if (request.uri.queryParameters['section'] == '5') {
              request.response.write(
                '<div id="region-main">'
                '<div class="activityinstance">'
                '<a href="https://lexue.bit.edu.cn/mod/assign/view.php?id=541355">'
                '<span class="instancename">第五周作业</span></a></div>'
                '<div class="activityinstance">'
                '<a href="https://lexue.bit.edu.cn/mod/assign/view.php?id=541356">'
                '<span class="instancename">第四周作业</span></a></div>'
                '<a href="https://lexue.bit.edu.cn/mod/assign/view.php?id=156254">'
                '正文中的旧作业链接</a></div>',
              );
            } else {
              request.response.write(
                '<div id="page-header"><h1>概率论与数理统计</h1></div>'
                '<a href="https://lexue.bit.edu.cn/course/view.php?id=18553&section=5">'
                '10月19日 - 10月25日</a>'
                '<div id="region-main"></div>',
              );
            }
          case '/lexue.bit.edu.cn/mod/assign/view.php':
            activityIds.add(request.uri.queryParameters['id']!);
            request.response.headers.contentType = ContentType(
              'text',
              'html',
              charset: 'utf-8',
            );
            if (request.uri.queryParameters['id'] == '541356') {
              request.response.write(
                '<div data-region="activity-dates">'
                '<div><strong>到期日：</strong> 2026年10月25日 星期日 23:30</div>'
                '</div>'
                '<div class="submissionstatustable">'
                '<div class="submissionstatussubmitted">已提交</div></div>',
              );
              break;
            }
            request.response.write(
              '<div data-region="activity-dates">'
              '<div><strong>打开：</strong> 2026年10月19日 星期一 12:00</div>'
              '<div><strong>到期日：</strong> 2026年11月7日 星期六 03:30</div>'
              '</div>'
              '<div data-region="completion-info">'
              '<button data-toggletype="manual:mark-done">标记完成</button>'
              '</div>',
            );
          default:
            request.response.statusCode = HttpStatus.notFound;
            request.response.write('unexpected request');
        }
        await request.response.close();
      });

      SchoolSession? session;
      addTearDown(() => session?.close());
      final page = SchoolResponse(
        url: DeadlineSource.lexue.loginPage,
        status: HttpStatus.ok,
        location: null,
        bytes: Uint8List.fromList(
          utf8.encode('<script>M.cfg = {"sesskey":"test"};</script>'),
        ),
      );
      final entries = await HttpOverrides.runWithHttpOverrides(() {
        session = SchoolSession(
          network: SchoolNetwork.campus,
          storage: MemorySchoolStorage(),
        );
        return fetchLexueDeadlines(session!, page);
      }, LocalHttpOverrides(server.port));

      expect(entries, hasLength(2));
      final pending = entries.singleWhere(
        (entry) => entry.id == 'lexue-cmid-541355',
      );
      expect(pending.title, '第五周作业');
      expect(pending.course, '概率论与数理统计');
      expect(pending.startsAt, DateTime.utc(2026, 11, 7, 3, 30));
      expect(pending.done, isFalse);
      final submitted = entries.singleWhere(
        (entry) => entry.id == 'lexue-cmid-541356',
      );
      expect(submitted.startsAt, DateTime.utc(2026, 10, 25, 23, 30));
      expect(submitted.done, isTrue);
      expect(activityIds, unorderedEquals(['541355', '541356']));
    },
  );

  test('A refreshed remote identifier replaces the same synced URL', () async {
    final oldUrl = Uri.https('lexue.bit.edu.cn', '/mod/assign/view.php', {
      'id': '541355',
    });
    final store = MemoryAgendaStore([
      AgendaEntry(
        id: 'lexue-event-42',
        title: '旧标题',
        kind: AgendaKind.deadline,
        startsAt: DateTime.utc(2026, 11, 6),
        done: true,
        course: '概率论与数理统计',
        source: DeadlineSource.lexue,
        local: false,
        url: oldUrl,
      ),
      AgendaEntry(
        id: 'lexue-cmid-541355',
        title: '旧的活动页标题',
        kind: AgendaKind.deadline,
        startsAt: DateTime.utc(2026, 11, 6),
        course: '概率论与数理统计',
        source: DeadlineSource.lexue,
        local: false,
        url: oldUrl,
      ),
    ]);
    final agenda = AgendaController(store);
    addTearDown(agenda.dispose);
    await agenda.load();

    expect(
      await agenda.mergeDeadlines([
        AgendaEntry(
          id: 'lexue-cmid-541355',
          title: '第五周作业',
          kind: AgendaKind.deadline,
          startsAt: DateTime.utc(2026, 11, 7, 3, 30),
          done: true,
          course: '概率论与数理统计',
          source: DeadlineSource.lexue,
          local: false,
          url: oldUrl,
        ),
      ]),
      isTrue,
    );

    expect(agenda.entries, hasLength(1));
    expect(agenda.entries.single.id, 'lexue-cmid-541355');
    expect(agenda.entries.single.title, '第五周作业');
    expect(agenda.entries.single.done, isTrue);
  });

  test('An unfinished remote deadline clears stale completion', () async {
    final url = Uri.https('zy-eclass.bit.edu.cn', '/activity', {'id': '4381'});
    final store = MemoryAgendaStore([
      AgendaEntry(
        id: 'eclass-4381',
        title: '第五章作业',
        kind: AgendaKind.deadline,
        startsAt: DateTime.utc(2026, 11, 1, 23, 59),
        done: true,
        course: '离散数学',
        source: DeadlineSource.eclass,
        local: false,
        url: url,
      ),
    ]);
    final agenda = AgendaController(store);
    addTearDown(agenda.dispose);
    await agenda.load();

    expect(
      await agenda.mergeDeadlines([
        AgendaEntry(
          id: 'eclass-4381',
          title: '第五章作业',
          kind: AgendaKind.deadline,
          startsAt: DateTime.utc(2026, 11, 1, 23, 59),
          done: false,
          course: '离散数学',
          source: DeadlineSource.eclass,
          local: false,
          url: url,
        ),
      ]),
      isTrue,
    );

    expect(agenda.entries.single.done, isFalse);
  });

  test('Eclass activities in one course do not share completion', () async {
    AgendaEntry eclassActivity(
      String id,
      DateTime startsAt, {
      bool done = false,
    }) => AgendaEntry(
      id: 'eclass-$id',
      title: '作业$id',
      kind: AgendaKind.deadline,
      startsAt: startsAt,
      done: done,
      course: '离散数学',
      source: DeadlineSource.eclass,
      local: false,
      url: Uri.https(
        'zy-eclass.bit.edu.cn',
        '/course/20336/learning-activity/full-screen',
      ).replace(fragment: '/$id'),
    );

    final store = MemoryAgendaStore([
      eclassActivity('4381', DateTime.utc(2026, 11, 1, 23, 59), done: true),
    ]);
    final agenda = AgendaController(store);
    addTearDown(agenda.dispose);
    await agenda.load();

    expect(
      await agenda.mergeDeadlines([
        eclassActivity('4383', DateTime.utc(2026, 11, 8, 23, 59)),
      ]),
      isTrue,
    );

    expect(
      agenda.entries.singleWhere((entry) => entry.id == 'eclass-4383').done,
      isFalse,
    );
  });

  test('A shared course URL does not identify different activities', () async {
    final url = Uri.https(DeadlineSource.mooc.host, '/learn/1', {'tid': '101'});
    AgendaEntry activity(String id, String title, {bool deleted = false}) =>
        AgendaEntry(
          id: id,
          title: title,
          kind: AgendaKind.deadline,
          startsAt: DateTime.utc(2026, 11, 1),
          deleted: deleted,
          course: '课程 1',
          source: DeadlineSource.mooc,
          local: false,
          url: url,
        );

    final store = MemoryAgendaStore([
      activity('review', '互评：第 32 周作业'),
      activity('assignment', '第 32 周作业', deleted: true),
    ]);
    final agenda = AgendaController(store);
    addTearDown(agenda.dispose);
    await agenda.load();

    expect(
      await agenda.mergeDeadlines([
        activity('assignment', '第 32 周作业'),
        activity('review', '互评：第 32 周作业'),
      ]),
      isTrue,
    );

    expect(agenda.entries.single.id, 'review');
    expect(agenda.deletedDeadlines.single.id, 'assignment');
  });
}
