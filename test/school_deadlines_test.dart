import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bitree/agenda/controller.dart';
import 'package:bitree/agenda/deadline_source.dart';
import 'package:bitree/agenda/model.dart';
import 'package:bitree/core/async/cancelable_request.dart';
import 'package:bitree/school/errors.dart';
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
        case '/zy-eclass.bit.edu.cn/api/courses/1/exam-list':
        case '/zy-eclass.bit.edu.cn/api/courses/20759/exam-list':
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'exams': <Map<String, Object?>>[],
              'page': 1,
              'page_size': 100,
              'pages': 1,
              'total': 0,
            }),
          );
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
    expect(
      paths.where((path) => path.endsWith('/exam-list')),
      unorderedEquals([
        '/zy-eclass.bit.edu.cn/api/courses/1/exam-list',
        '/zy-eclass.bit.edu.cn/api/courses/20759/exam-list',
      ]),
    );
  });

  test('Eclass courses scan concurrently within the request limit', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final activityCourses = <String>[];
    final examCourses = <String>[];
    final examQueries = <Map<String, String>>[];
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

      final exams = RegExp(
        r'^/zy-eclass\.bit\.edu\.cn/api/courses/(\d+)/exam-list$',
      ).firstMatch(path);
      if (exams != null) {
        final courseId = exams[1]!;
        examCourses.add(courseId);
        examQueries.add(request.uri.queryParameters);
        await sendJson(request, {
          'exams': <Map<String, Object?>>[],
          'page': 1,
          'page_size': 100,
          'pages': 1,
          'total': 0,
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
    expect(
      examCourses,
      unorderedEquals(['100', '200', '201', '202', '203', '204']),
    );
    expect(examQueries, hasLength(6));
    for (final query in examQueries) {
      expect(query['page_size'], '100');
      expect(query['page'], '1');
    }
    expect(detailRequests, 0);
    expect(maxActive, inInclusiveRange(2, 4));
  });

  test('Eclass exams become deadlines under their own id namespace', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final scan = await scanEclass(
      server,
      eclassFixture(
        exams: (_, _) => [
          eclassExam(id: 1212, title: '第三章测试', submissions: 1),
          eclassExam(id: 1211, title: '第四章测试'),
        ],
      ),
    );

    expect(scan.error, isNull);
    expect(scan.unexpected, isEmpty);
    expect(scan.entries.map((entry) => entry.id).toList(), [
      'eclass-exam-1212',
      'eclass-exam-1211',
    ]);
    final exam = scan.entryFor('eclass-exam-1212');
    expect(exam.title, '第三章测试');
    expect(exam.course, '数字电子技术基础');
    expect(exam.kind, AgendaKind.deadline);
    expect(exam.source, DeadlineSource.eclass);
    // 2026-11-08T14:30:00Z is 22:30 in Beijing wall clock.
    expect(exam.startsAt, DateTime.utc(2026, 11, 8, 22, 30));
    expect(exam.startOnly, isFalse);
    expect(exam.done, isTrue);
    expect(scan.entryFor('eclass-exam-1211').done, isFalse);
    expect(exam.url?.host, 'zy-eclass.bit.edu.cn');
    expect(exam.url?.path, '/course/7/exam');
    expect(exam.url?.fragment ?? '', isEmpty);
    expect(
      scan.examRequests.map((uri) => uri.queryParameters['page_size']),
      everyElement('100'),
    );
  });

  test('Exam ids stay separate from activity ids and their completion',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final scan = await scanEclass(
      server,
      eclassFixture(
        activities: (_) => [
          {
            'id': 1211,
            'type': 'homework',
            'title': '第五次作业',
            'end_time': '2026-11-05T15:59:00Z',
            'visible_end_at': null,
          },
        ],
        exams: (_, _) => [
          eclassExam(
            id: 1211,
            title: '第五章测试',
            submissions: 1,
          ),
        ],
      ),
    );

    expect(scan.error, isNull);
    expect(scan.unexpected, isEmpty);
    expect(scan.entries, hasLength(2));
    // The homework id is untouched, so stored deadlines keep their identity.
    final homework = scan.entryFor('eclass-1211');
    expect(homework.title, '第五次作业');
    expect(homework.done, isFalse);
    final exam = scan.entryFor('eclass-exam-1211');
    expect(exam.title, '第五章测试');
    expect(exam.done, isTrue);
  });

  test('Exam completion follows submission_count alone', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final scan = await scanEclass(
      server,
      eclassFixture(
        exams: (_, _) => [
          eclassExam(
            id: 1,
            title: '已交但未结束',
            submissions: 1,
            submitTimes: 0,
            closed: false,
          ),
          eclassExam(
            id: 2,
            title: '未交但已关闭',
            submissions: 0,
            submitTimes: 1,
            closed: true,
          ),
          eclassExam(
            id: 3,
            title: '只有补交记录',
            submissions: 0,
            makeupSubmissions: 3,
          ),
        ],
      ),
    );

    expect(scan.error, isNull);
    expect(scan.entryFor('eclass-exam-1').done, isTrue);
    expect(scan.entryFor('eclass-exam-2').done, isFalse);
    expect(scan.entryFor('eclass-exam-3').done, isFalse);
  });

  test('Exams without an end time keep their start as a start-only entry',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final scan = await scanEclass(
      server,
      eclassFixture(
        exams: (_, _) => [
          eclassExam(
            id: 4,
            title: '开放式测试',
            endTime: null,
            startTime: '2026-11-20T16:00:00Z',
          ),
          eclassExam(
            id: 5,
            title: '空截止时间的测试',
            endTime: '',
            startTime: '2026-11-21T00:00:00Z',
          ),
        ],
      ),
    );

    expect(scan.error, isNull);
    expect(scan.unexpected, isEmpty);
    expect(scan.entries.map((entry) => entry.id).toList(), [
      'eclass-exam-4',
      'eclass-exam-5',
    ]);
    final open = scan.entryFor('eclass-exam-4');
    // 2026-11-20T16:00:00Z is 2026-11-21 00:00 in Beijing wall clock.
    expect(open.startsAt, DateTime.utc(2026, 11, 21, 0, 0));
    expect(open.startOnly, isTrue);
    // A start-only entry never counts as overdue, however late the clock runs.
    expect(open.overdue(DateTime.utc(2027, 1, 1)), isFalse);
    expect(scan.entryFor('eclass-exam-5').startOnly, isTrue);
  });

  test('Exams with neither an end nor a start time are skipped', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final scan = await scanEclass(
      server,
      eclassFixture(
        exams: (_, _) => [
          eclassExam(
            id: 6,
            title: '未开放的测试',
            endTime: null,
            startTime: null,
          ),
          eclassExam(id: 7, title: '空时间的测试', endTime: '', startTime: ''),
          eclassExam(id: 8, title: '有截止时间的测试'),
        ],
      ),
    );

    expect(scan.error, isNull);
    expect(scan.entries.map((entry) => entry.id).toList(), ['eclass-exam-8']);
    expect(scan.entryFor('eclass-exam-8').startOnly, isFalse);
  });

  test('An empty exam list leaves activity deadlines untouched', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final scan = await scanEclass(
      server,
      eclassFixture(
        activities: (_) => [
          {
            'id': 31,
            'type': 'homework',
            'title': '第一次作业',
            'end_time': '2026-11-04T15:59:00Z',
            'visible_end_at': null,
          },
        ],
      ),
    );

    expect(scan.error, isNull);
    expect(scan.unexpected, isEmpty);
    expect(scan.entries, hasLength(1));
    expect(scan.entries.single.id, 'eclass-31');
  });

  test('Exam pages are followed until the reported page count', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final scan = await scanEclass(
      server,
      eclassFixture(
        examPageCount: 3,
        exams: (_, page) => [
          eclassExam(id: 9000 + page, title: '测试第$page 页'),
        ],
      ),
    );

    expect(scan.error, isNull);
    expect(
      scan.examRequests.map((uri) => uri.queryParameters['page']).toList(),
      ['1', '2', '3'],
    );
    expect(scan.entries, hasLength(3));
    expect(scan.entryFor('eclass-exam-9003').title, '测试第3 页');
  });

  test('Exam paging falls back to the row count without a page count',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final scan = await scanEclass(
      server,
      eclassFixture(
        reportPageCount: false,
        exams: (_, page) => page == 1
            ? [
                for (var index = 0; index < 100; index++)
                  eclassExam(id: 1000 + index, title: '测试${1000 + index}'),
              ]
            : [
                for (var index = 0; index < 3; index++)
                  eclassExam(id: 2000 + index, title: '测试${2000 + index}'),
              ],
      ),
    );

    expect(scan.error, isNull);
    expect(
      scan.examRequests.map((uri) => uri.queryParameters['page']).toList(),
      ['1', '2'],
    );
    expect(scan.entries, hasLength(103));
  });

  test('A failing exam list does not remove the activity deadlines', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final scan = await scanEclass(
      server,
      eclassFixture(
        activities: (_) => [
          {
            'id': 31,
            'type': 'homework',
            'title': '第一次作业',
            'end_time': '2026-11-04T15:59:00Z',
            'visible_end_at': null,
          },
        ],
        examStatus: (_, _) => HttpStatus.internalServerError,
      ),
    );

    expect(scan.error, isNull);
    expect(scan.entries.map((entry) => entry.id).toList(), ['eclass-31']);
  });

  test('A failing activity list does not remove the exam deadlines', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final scan = await scanEclass(
      server,
      eclassFixture(
        activities: (_) => [
          {
            'id': 31,
            'type': 'homework',
            'title': '第一次作业',
            'end_time': '2026-11-04T15:59:00Z',
            'visible_end_at': null,
          },
        ],
        exams: (_, _) => [eclassExam(id: 41, title: '第一次测试')],
        activityStatus: (_) => HttpStatus.serviceUnavailable,
      ),
    );

    expect(scan.error, isNull);
    expect(scan.entries.map((entry) => entry.id).toList(), ['eclass-exam-41']);
  });

  test('An expired session on the exam list aborts the whole scan', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final scan = await scanEclass(
      server,
      eclassFixture(
        courses: const [
          {'id': 7, 'name': '数字电子技术基础'},
          {'id': 8, 'name': '电路分析基础'},
        ],
        activities: (_) => [
          {
            'id': 31,
            'type': 'homework',
            'title': '第一次作业',
            'end_time': '2026-11-04T15:59:00Z',
            'visible_end_at': null,
          },
        ],
        examStatus: (courseId, _) => courseId == 7 ? 401 : HttpStatus.ok,
      ),
    );

    expect(scan.error, isA<SessionExpired>());
    expect(scan.entries, isEmpty);
  });

  test('A closed session reports cancellation instead of an empty scan',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    });

    await HttpOverrides.runWithHttpOverrides(() async {
      final session = SchoolSession(
        network: SchoolNetwork.campus,
        storage: MemorySchoolStorage(),
      )..close();
      await expectLater(
        fetchEclassDeadlines(session),
        throwsA(isA<RequestCancelled>()),
      );
    }, LocalHttpOverrides(server.port));
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

  test(
    'Lexue programming activities use discount time, close-time notes, and AC status',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final resultIds = <String>[];
      server.listen((request) async {
        final path = request.uri.path;
        final id = request.uri.queryParameters['id'];
        request.response.headers.contentType = ContentType(
          'text',
          'html',
          charset: 'utf-8',
        );
        switch (path) {
          case '/lexue.bit.edu.cn/calendar/export.php':
            request.response.write(
              '<div class="calendarurl">'
              'https://lexue.bit.edu.cn/calendar/export_execute.php'
              '</div>',
            );
          case '/lexue.bit.edu.cn/calendar/export_execute.php':
            request.response.write('BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n');
          case '/lexue.bit.edu.cn/my/':
            request.response.write(
              '<a href="https://lexue.bit.edu.cn/course/view.php?id=18675">'
              '数据结构（2026秋）</a>',
            );
          case '/lexue.bit.edu.cn/course/view.php':
            if (request.uri.queryParameters['section'] == '8') {
              request.response.write(
                '<div id="region-main">'
                '<div class="activityinstance">'
                '<a href="https://lexue.bit.edu.cn/mod/programming/view.php?id=543983">'
                '<span class="instancename">1. 二叉哥的二叉树</span></a></div>'
                '<div class="activityinstance">'
                '<a href="https://lexue.bit.edu.cn/mod/programming/view.php?id=543992">'
                '<span class="instancename">2. 广义表</span></a></div>'
                '<div class="activityinstance">'
                '<a href="https://lexue.bit.edu.cn/mod/programming/view.php?id=543994">'
                '<span class="instancename">1. 折半查找</span></a></div>'
                '<div class="activityinstance">'
                '<a href="https://lexue.bit.edu.cn/mod/programming/view.php?id=543995">'
                '<span class="instancename">无折扣题</span></a></div>'
                '<div class="activityinstance">'
                '<a href="https://lexue.bit.edu.cn/mod/programming/view.php?id=543996">'
                '<span class="instancename">评测页暂不可用</span></a></div>'
                '<div class="activityinstance">'
                '<a href="https://lexue.bit.edu.cn/mod/quiz/view.php?id=543959">'
                '<span class="instancename">第1章-绪论-练习</span></a></div>'
                '</div>',
              );
            } else {
              request.response.write(
                '<div id="page-header"><h1>数据结构（2026秋）</h1></div>'
                '<a href="https://lexue.bit.edu.cn/course/view.php?id=18675&section=8">'
                '11月16日 - 11月22日</a>'
                '<div id="region-main"></div>',
              );
            }
          case '/lexue.bit.edu.cn/mod/programming/view.php':
            switch (id) {
              case '543983':
                request.response.write(
                  '<div class="box py-3 time-table"><table class="generaltable"><tbody>'
                  '<tr><td>成绩</td><td>10</td><td>开启时间</td><td>2026年11月5日 星期四 12:00</td></tr>'
                  '<tr><td>折扣</td><td>0.8</td><td>折扣时间</td><td>2026年11月12日 星期四 23:55</td></tr>'
                  '<tr><td>允许迟交</td><td>否</td><td>关闭时间</td><td>2026年11月16日 星期一 23:55</td></tr>'
                  '</tbody></table></div>',
                );
              case '543992':
              case '543994':
              case '543996':
                request.response.write(
                  '<div class="box py-3 time-table"><table class="generaltable"><tbody>'
                  '<tr><td>成绩</td><td>10</td><td>开启时间</td><td>2026年11月16日 星期一 00:00</td></tr>'
                  '<tr><td>折扣</td><td>0.8</td><td>折扣时间</td><td>2026年11月27日 星期五 23:55</td></tr>'
                  '<tr><td>允许迟交</td><td>否</td><td>关闭时间</td><td>2026年11月30日 星期一 23:55</td></tr>'
                  '</tbody></table></div>',
                );
              case '543995':
                request.response.write(
                  '<div class="box py-3 time-table"><table class="generaltable"><tbody>'
                  '<tr><td>允许迟交</td><td>否</td><td>关闭时间</td><td>2026年12月1日 星期二 23:55</td></tr>'
                  '</tbody></table></div>',
                );
            }
          case '/lexue.bit.edu.cn/mod/programming/result.php':
            resultIds.add(id!);
            switch (id) {
              case '543983':
                request.response.write(
                  '<div id="test-result-detail">'
                  '<p>测试结果：共 2 个测试用例，您的程序通过了其中的 2 个，未能通过的有 0 个。</p>'
                  '<table><tbody>'
                  '<tr class="passed"><td>AC: 完全正确</td></tr>'
                  '<tr class="passed lastrow"><td>AC: 完全正确</td></tr>'
                  '</tbody></table></div>',
                );
              case '543992':
                request.response.write(
                  '<div id="test-result-detail">'
                  '<p>测试结果：共 2 个测试用例，您的程序通过了其中的 1 个，未能通过的有 1 个。</p>'
                  '<table><tbody>'
                  '<tr class="passed"><td>AC</td></tr>'
                  '<tr class="notpassed lastrow"><td>WA</td></tr>'
                  '</tbody></table></div>',
                );
              case '543994':
              case '543995':
                request.response.write('<p>找不到您的程序</p>');
              case '543996':
                request.response.statusCode = HttpStatus.serviceUnavailable;
                request.response.write('temporarily unavailable');
            }
          case '/lexue.bit.edu.cn/mod/quiz/view.php':
            request.response.write(
              '<div data-region="activity-dates">'
              '<div><strong>已开放：</strong> 2026年09月21日 星期一 15:16</div>'
              '<div><strong>已关闭:</strong> 2026年09月28日 星期一 23:55</div>'
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

      expect(entries, hasLength(6));
      final ac = entries.singleWhere((e) => e.id == 'lexue-cmid-543983');
      expect(ac.course, '数据结构（2026秋）');
      expect(ac.title, '1. 二叉哥的二叉树');
      expect(ac.startsAt, DateTime.utc(2026, 11, 12, 23, 55));
      expect(ac.notes, '关闭时间：2026年11月16日 星期一 23:55');
      expect(ac.done, isTrue);

      final partial = entries.singleWhere((e) => e.id == 'lexue-cmid-543992');
      expect(partial.startsAt, DateTime.utc(2026, 11, 27, 23, 55));
      expect(partial.notes, '关闭时间：2026年11月30日 星期一 23:55');
      expect(partial.done, isFalse);

      final unsubmitted = entries.singleWhere(
        (e) => e.id == 'lexue-cmid-543994',
      );
      expect(unsubmitted.done, isFalse);

      final closeOnly = entries.singleWhere(
        (e) => e.id == 'lexue-cmid-543995',
      );
      expect(closeOnly.startsAt, DateTime.utc(2026, 12, 1, 23, 55));
      expect(closeOnly.notes, isEmpty);
      expect(closeOnly.done, isFalse);

      final resultFailed = entries.singleWhere(
        (e) => e.id == 'lexue-cmid-543996',
      );
      expect(resultFailed.startsAt, DateTime.utc(2026, 11, 27, 23, 55));
      expect(resultFailed.done, isFalse);

      final quiz = entries.singleWhere((e) => e.id == 'lexue-cmid-543959');
      expect(quiz.title, '第1章-绪论-练习');
      expect(quiz.startsAt, DateTime.utc(2026, 9, 28, 23, 55));

      expect(
        resultIds,
        unorderedEquals(['543983', '543992', '543994', '543995', '543996']),
      );
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
        '/course/20336/learning-activity#',
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

  test(
    'Toggling completion marks a synced deadline local, skips overwrite on sync, and can be overwritten on demand',
    () async {
      final url = Uri.https('lexue.bit.edu.cn', '/mod/programming/view.php', {
        'id': '543994',
      });
      final initial = AgendaEntry(
        id: 'lexue-cmid-543994',
        title: '1. 折半查找',
        kind: AgendaKind.deadline,
        startsAt: DateTime.utc(2026, 11, 27, 23, 55),
        done: false,
        course: '数据结构（2026秋）',
        source: DeadlineSource.lexue,
        local: false,
        url: url,
      );
      final store = MemoryAgendaStore([initial]);
      final agenda = AgendaController(store);
      addTearDown(agenda.dispose);
      await agenda.load();

      // Toggling completion turns the synced entry into a local modification.
      expect(await agenda.save(agenda.entries.single.toggleDone()), isTrue);
      expect(agenda.entries.single.done, isTrue);
      expect(agenda.entries.single.local, isTrue);

      // Sync keeps the local entry intact and reports the skipped remote diff.
      var skipped = const <SkippedAgendaUpdate>[];
      final incoming = AgendaEntry(
        id: 'lexue-cmid-543994',
        title: '1. 折半查找（延长）',
        kind: AgendaKind.deadline,
        startsAt: DateTime.utc(2026, 11, 28, 23, 55),
        done: false,
        course: '数据结构（2026秋）',
        source: DeadlineSource.lexue,
        local: false,
        url: url,
      );
      expect(
        await agenda.mergeDeadlines(
          [incoming],
          onSkipped: (items) => skipped = items,
        ),
        isTrue,
      );
      expect(agenda.entries.single.done, isTrue);
      expect(agenda.entries.single.title, '1. 折半查找');
      expect(agenda.entries.single.startsAt, DateTime.utc(2026, 11, 27, 23, 55));
      expect(skipped, hasLength(1));
      expect(skipped.single.doneChanged, isTrue);
      expect(skipped.single.titleChanged, isTrue);
      expect(skipped.single.timeChanged, isTrue);

      // Explicitly overwriting restores remote fields and clears local=true.
      expect(await agenda.overwriteEntries(skipped), isTrue);
      expect(agenda.entries.single.done, isFalse);
      expect(agenda.entries.single.local, isFalse);
      expect(agenda.entries.single.title, '1. 折半查找（延长）');
      expect(agenda.entries.single.startsAt, DateTime.utc(2026, 11, 28, 23, 55));
    },
  );

  test(
    'Lexue calendar and activity scans converge on one stable cmid identifier',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        final path = request.uri.path;
        switch (path) {
          case '/lexue.bit.edu.cn/calendar/export.php':
            request.response.headers.contentType = ContentType.html;
            request.response.write(
              '<div class="calendarurl">'
              'https://lexue.bit.edu.cn/calendar/export_execute.php'
              '</div>',
            );
          case '/lexue.bit.edu.cn/calendar/export_execute.php':
            request.response.write(
              'BEGIN:VCALENDAR\r\n'
              'BEGIN:VEVENT\r\n'
              'UID:98765@lexue.bit.edu.cn\r\n'
              'SUMMARY:第五周作业 已到期\r\n'
              'DTSTART:20261106T193000Z\r\n'
              'CATEGORIES:PROB2026\r\n'
              'END:VEVENT\r\n'
              'END:VCALENDAR\r\n',
            );
          case '/lexue.bit.edu.cn/lib/ajax/service.php':
            final body = jsonDecode(
              await utf8.decoder.bind(request).join(),
            ) as List<dynamic>;
            final method =
                (body.first as Map<String, dynamic>)['methodname'] as String;
            request.response.headers.contentType = ContentType.json;
            if (method == 'core_calendar_get_calendar_event_by_id') {
              request.response.write(
                jsonEncode([
                  {
                    'error': false,
                    'data': {
                      'event': {
                        'instance': 541355,
                        'url':
                            'https://lexue.bit.edu.cn/mod/assign/view.php?id=541355',
                      },
                    },
                  },
                ]),
              );
            } else {
              request.response.write(
                jsonEncode([
                  {'error': false, 'data': '<div></div>'},
                ]),
              );
            }
          case '/lexue.bit.edu.cn/my/':
            request.response.headers.contentType = ContentType.html;
            request.response.write(
              '<a href="https://lexue.bit.edu.cn/course/view.php?id=18553">'
              '概率论与数理统计</a>',
            );
          case '/lexue.bit.edu.cn/course/view.php':
            request.response.headers.contentType = ContentType.html;
            request.response.write(
              '<div id="page-header"><h1>概率论与数理统计</h1></div>'
              '<div id="region-main">'
              '<div class="activityinstance">'
              '<a href="https://lexue.bit.edu.cn/mod/assign/view.php?id=541355">'
              '<span class="instancename">第五周作业</span></a></div></div>',
            );
          case '/lexue.bit.edu.cn/mod/assign/view.php':
            request.response.headers.contentType = ContentType.html;
            request.response.write(
              '<div data-region="activity-dates">'
              '<div><strong>到期日：</strong> 2026年11月7日 星期六 03:30</div>'
              '</div>',
            );
          default:
            request.response.statusCode = HttpStatus.notFound;
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

      expect(entries, hasLength(1));
      expect(entries.single.id, 'lexue-cmid-541355');
      expect(entries.single.title, '第五周作业');
      expect(entries.single.course, '概率论与数理统计');
      expect(
        entries.single.url,
        Uri.https('lexue.bit.edu.cn', '/mod/assign/view.php', {'id': '541355'}),
      );
    },
  );

  test(
    'Lexue calendar URLs survive partial AJAX errors, zero instances, and module lookup failures',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final moduleCalls = <int>[];
      server.listen((request) async {
        switch (request.uri.path) {
          case '/lexue.bit.edu.cn/calendar/export.php':
            request.response.headers.contentType = ContentType.html;
            request.response.write(
              '<div class="calendarurl">'
              'https://lexue.bit.edu.cn/calendar/export_execute.php'
              '</div>',
            );
          case '/lexue.bit.edu.cn/calendar/export_execute.php':
            request.response.write(
              'BEGIN:VCALENDAR\r\n'
              'BEGIN:VEVENT\r\n'
              'UID:10001@lexue.bit.edu.cn\r\n'
              'SUMMARY:第4章 数组-练习 关闭\r\n'
              'DTSTART:20261120T031500Z\r\n'
              'CATEGORIES:2026-2027-I 数据结构中文班\r\n'
              'END:VEVENT\r\n'
              'BEGIN:VEVENT\r\n'
              'UID:10002@lexue.bit.edu.cn\r\n'
              'SUMMARY:无权限事件\r\n'
              'DTSTART:20261121T031500Z\r\n'
              'CATEGORIES:2026-2027-I 数据结构中文班\r\n'
              'END:VEVENT\r\n'
              'BEGIN:VEVENT\r\n'
              'UID:10003@lexue.bit.edu.cn\r\n'
              'SUMMARY:课程通知\r\n'
              'DTSTART:20261122T031500Z\r\n'
              'CATEGORIES:2026-2027-I 数据结构中文班\r\n'
              'END:VEVENT\r\n'
              'END:VCALENDAR\r\n',
            );
          case '/lexue.bit.edu.cn/lib/ajax/service.php':
            final body =
                jsonDecode(await utf8.decoder.bind(request).join())
                    as List<dynamic>;
            request.response.headers.contentType = ContentType.json;
            final responses = <Map<String, Object?>>[];
            for (final rawCall in body) {
              final call = rawCall as Map<String, dynamic>;
              final method = call['methodname'] as String;
              final args = call['args'] as Map<String, dynamic>;
              if (method == 'core_calendar_get_calendar_event_by_id') {
                final eventId = args['eventid'] as int;
                if (eventId == 10001) {
                  responses.add({
                    'error': false,
                    'data': {
                      'event': {
                        'modulename': 'quiz',
                        'instance': 543999,
                        'url':
                            'https://lexue.bit.edu.cn/calendar/view.php?view=day#event_10001',
                      },
                    },
                  });
                } else if (eventId == 10002) {
                  responses.add({
                    'error': true,
                    'exception': {
                      'errorcode': 'nopermissiontoviewcalendar',
                      'message': 'No permission',
                    },
                  });
                  // Moodle stops executing remaining calls in a batch.
                  break;
                } else if (eventId == 10003) {
                  responses.add({
                    'error': false,
                    'data': {
                      'event': {
                        'instance': 0,
                        'course': {
                          'id': 18675,
                          'viewurl':
                              'https://lexue.bit.edu.cn/course/view.php?id=18675',
                        },
                      },
                    },
                  });
                }
              } else if (method == 'core_course_get_module') {
                moduleCalls.add(args['id'] as int);
                responses.add({
                  'error': true,
                  'exception': {'message': 'module unavailable'},
                });
                break;
              } else {
                responses.add({
                  'error': false,
                  'data': {'courses': <Object?>[]},
                });
              }
            }
            request.response.write(jsonEncode(responses));
          case '/lexue.bit.edu.cn/my/':
            request.response.headers.contentType = ContentType.html;
            request.response.write('<html><body></body></html>');
          default:
            request.response.statusCode = HttpStatus.notFound;
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

      expect(entries, hasLength(3));
      final quiz = entries.singleWhere((e) => e.id == 'lexue-cmid-543999');
      expect(
        quiz.url,
        Uri.https('lexue.bit.edu.cn', '/mod/quiz/view.php', {'id': '543999'}),
      );
      final courseEvent = entries.singleWhere(
        (e) => e.id == 'lexue-10003@lexue.bit.edu.cn',
      );
      expect(
        courseEvent.url,
        Uri.https('lexue.bit.edu.cn', '/course/view.php', {'id': '18675'}),
      );
      expect(moduleCalls, [543999]);
    },
  );

  test(
    'Lexue discovers enrolled courses via AJAX and parses quizinfo close times',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        switch (request.uri.path) {
          case '/lexue.bit.edu.cn/calendar/export.php':
            request.response.headers.contentType = ContentType.html;
            request.response.write(
              '<div class="calendarurl">'
              'https://lexue.bit.edu.cn/calendar/export_execute.php'
              '</div>',
            );
          case '/lexue.bit.edu.cn/calendar/export_execute.php':
            request.response.write('BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n');
          case '/lexue.bit.edu.cn/my/':
            request.response.headers.contentType = ContentType.html;
            request.response.write('<html><body></body></html>');
          case '/lexue.bit.edu.cn/lib/ajax/service.php':
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode([
                {
                  'error': false,
                  'data': {
                    'courses': [
                      {
                        'id': 18675,
                        'fullname': '2026-2027-I 数据结构中文班',
                        'viewurl':
                            'https://lexue.bit.edu.cn/course/view.php?id=18675',
                      },
                    ],
                  },
                },
              ]),
            );
          case '/lexue.bit.edu.cn/course/view.php':
            request.response.headers.contentType = ContentType(
              'text',
              'html',
              charset: 'utf-8',
            );
            request.response.write(
              '<div id="page-header"><h1>2026-2027-I 数据结构中文班</h1></div>'
              '<div id="region-main">'
              '<div class="activityname">'
              '<a href="https://lexue.bit.edu.cn/mod/quiz/view.php?id=544001">'
              '第4章 数组-练习</a></div></div>',
            );
          case '/lexue.bit.edu.cn/mod/quiz/view.php':
            request.response.headers.contentType = ContentType(
              'text',
              'html',
              charset: 'utf-8',
            );
            request.response.write(
              '<div class="box py-3 quizinfo">'
              '<p>此测验将关闭于2026年11月20日 星期五 11:15。</p>'
              '</div>',
            );
          default:
            request.response.statusCode = HttpStatus.notFound;
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

      expect(entries, hasLength(1));
      final quiz = entries.single;
      expect(quiz.id, 'lexue-cmid-544001');
      expect(quiz.title, '第4章 数组-练习');
      expect(quiz.course, '2026-2027-I 数据结构中文班');
      expect(quiz.startsAt, DateTime.utc(2026, 11, 20, 11, 15));
      expect(
        quiz.url,
        Uri.https('lexue.bit.edu.cn', '/mod/quiz/view.php', {'id': '544001'}),
      );
    },
  );

  test(
    'Sync backfills a missing link on a local deadline without collapsing shared Lexue course URLs',
    () async {
      final courseUrl = Uri.https('lexue.bit.edu.cn', '/course/view.php', {
        'id': '18675',
      });
      final quizUrl = Uri.https('lexue.bit.edu.cn', '/mod/quiz/view.php', {
        'id': '543999',
      });
      final store = MemoryAgendaStore([
        AgendaEntry(
          id: 'lexue-10001@lexue.bit.edu.cn',
          title: '第4章 数组-练习 关闭',
          kind: AgendaKind.deadline,
          startsAt: DateTime.utc(2026, 11, 20, 11, 15),
          done: true,
          course: '2026-2027-I 数据结构中文班',
          source: DeadlineSource.lexue,
          local: true,
        ),
        AgendaEntry(
          id: 'lexue-10003@lexue.bit.edu.cn',
          title: '期中答疑',
          kind: AgendaKind.deadline,
          startsAt: DateTime.utc(2026, 11, 22, 11, 15),
          course: '2026-2027-I 数据结构中文班',
          source: DeadlineSource.lexue,
          local: false,
          url: courseUrl,
        ),
      ]);
      final agenda = AgendaController(store);
      addTearDown(agenda.dispose);
      await agenda.load();

      expect(
        await agenda.mergeDeadlines([
          AgendaEntry(
            id: 'lexue-cmid-543999',
            title: '第4章 数组-练习 关闭',
            kind: AgendaKind.deadline,
            startsAt: DateTime.utc(2026, 11, 20, 11, 15),
            done: false,
            course: '2026-2027-I 数据结构中文班',
            source: DeadlineSource.lexue,
            local: false,
            url: quizUrl,
          ),
          AgendaEntry(
            id: 'lexue-10004@lexue.bit.edu.cn',
            title: '期末答疑',
            kind: AgendaKind.deadline,
            startsAt: DateTime.utc(2026, 11, 25, 11, 15),
            course: '2026-2027-I 数据结构中文班',
            source: DeadlineSource.lexue,
            local: false,
            url: courseUrl,
          ),
        ]),
        isTrue,
      );

      expect(agenda.entries, hasLength(3));
      final localQuiz = agenda.entries.singleWhere(
        (e) => e.title == '第4章 数组-练习 关闭',
      );
      expect(localQuiz.done, isTrue);
      expect(localQuiz.local, isTrue);
      expect(localQuiz.url, quizUrl);
    },
  );
}

/// One eclass scan plus the traffic it produced.
class EclassScan {
  EclassScan({
    required this.entries,
    required this.error,
    required this.examRequests,
    required this.unexpected,
  });

  final List<AgendaEntry> entries;
  final Object? error;
  final List<Uri> examRequests;
  final List<String> unexpected;

  AgendaEntry entryFor(String id) => entries.singleWhere(
    (entry) => entry.id == id,
  );
}

/// Runs [fetchEclassDeadlines] against [server]. [handle] answers a request
/// and reports whether it recognised it; unknown requests are recorded.
Future<EclassScan> scanEclass(
  HttpServer server,
  bool Function(HttpRequest request) handle,
) async {
  final examRequests = <Uri>[];
  final unexpected = <String>[];
  server.listen((request) async {
    try {
      if (request.uri.path.endsWith('/exam-list')) {
        examRequests.add(request.uri);
      }
      if (!handle(request)) {
        unexpected.add('${request.uri.path}?${request.uri.query}');
        request.response.statusCode = HttpStatus.notFound;
      }
    } finally {
      await request.response.close();
    }
  });

  SchoolSession? session;
  var entries = const <AgendaEntry>[];
  Object? error;
  try {
    entries = await HttpOverrides.runWithHttpOverrides(() {
      final fresh = SchoolSession(
        network: SchoolNetwork.campus,
        storage: MemorySchoolStorage(),
      );
      session = fresh;
      return fetchEclassDeadlines(fresh);
    }, LocalHttpOverrides(server.port));
  } catch (failure) {
    error = failure;
  }
  session?.close();
  return EclassScan(
    entries: entries,
    error: error,
    examRequests: examRequests,
    unexpected: unexpected,
  );
}

List<Map<String, Object?>> _noActivities(int courseId) => const [];

List<Map<String, Object?>> _noExams(int courseId, int page) => const [];

int _requestOk(int courseId, int page) => HttpStatus.ok;

int _activityRequestOk(int courseId) => HttpStatus.ok;

/// Answers the endpoints one eclass scan touches, so each test only states the
/// payloads that matter to it.
bool Function(HttpRequest request) eclassFixture({
  List<Map<String, Object?>> courses = const [
    {'id': 7, 'name': '数字电子技术基础'},
  ],
  List<Map<String, Object?>> Function(int courseId) activities = _noActivities,
  List<Map<String, Object?>> Function(int courseId, int page) exams = _noExams,
  int examPageCount = 1,
  bool reportPageCount = true,
  int Function(int courseId, int page) examStatus = _requestOk,
  int Function(int courseId) activityStatus = _activityRequestOk,
  Set<int> submittedActivities = const {},
}) {
  final activityPath = RegExp(
    r'^/zy-eclass\.bit\.edu\.cn/api/courses/(\d+)/activities$',
  );
  final examPath = RegExp(
    r'^/zy-eclass\.bit\.edu\.cn/api/courses/(\d+)/exam-list$',
  );
  final statusPath = RegExp(
    r'^/zy-eclass\.bit\.edu\.cn/api/course/(\d+)/homework/submission-status$',
  );
  return (request) {
    final path = request.uri.path;
    if (path == '/zy-eclass.bit.edu.cn/api/my-courses') {
      respondJson(request, {'courses': courses, 'pages': 1});
      return true;
    }
    final activity = activityPath.firstMatch(path);
    if (activity != null) {
      final courseId = int.parse(activity[1]!);
      final status = activityStatus(courseId);
      if (status != HttpStatus.ok) {
        request.response.statusCode = status;
        request.response.write('activities unavailable');
        return true;
      }
      respondJson(request, {'activities': activities(courseId)});
      return true;
    }
    final exam = examPath.firstMatch(path);
    if (exam != null) {
      final courseId = int.parse(exam[1]!);
      final page = int.parse(request.uri.queryParameters['page'] ?? '1');
      final status = examStatus(courseId, page);
      if (status != HttpStatus.ok) {
        request.response.statusCode = status;
        request.response.write('exam list unavailable');
        return true;
      }
      final rows = exams(courseId, page);
      respondJson(request, {
        'exams': rows,
        'page': page,
        'page_size': 100,
        'start': 0,
        'end': rows.length,
        if (reportPageCount) 'pages': examPageCount,
        'total': rows.length,
      });
      return true;
    }
    final homework = statusPath.firstMatch(path);
    if (homework != null) {
      final courseId = int.parse(homework[1]!);
      respondJson(request, {
        'course_id': courseId,
        'homework_activities': [
          for (final task in activities(courseId))
            if (task['type'] == 'homework')
              {
                'id': task['id'],
                'status_code': submittedActivities.contains(task['id'])
                    ? 'submitted'
                    : 'absent',
              },
        ],
      });
      return true;
    }
    return false;
  };
}

void respondJson(HttpRequest request, Object body) {
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(body));
}

/// One row of `exam-list`, shaped like the live response.
Map<String, Object?> eclassExam({
  required int id,
  required String title,
  Object? endTime = '2026-11-08T14:30:00Z',
  Object? startTime = '2026-11-01T00:00:00Z',
  int submissions = 0,
  int makeupSubmissions = 0,
  int submitTimes = 0,
  bool closed = false,
}) => {
  'id': id,
  'title': title,
  'type': 'exam',
  'start_time': startTime,
  'end_time': endTime,
  'is_closed': closed,
  'is_in_progress': !closed,
  'is_started': true,
  'published': true,
  'submission_count': submissions,
  'makeup_exam_submission_count': makeupSubmissions,
  'submit_times': submitTimes,
  'referrer_type': 'module',
};
