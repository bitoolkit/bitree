import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bitree/agenda/deadline_source.dart';
import 'package:bitree/agenda/model.dart';
import 'package:bitree/core/async/cancelable_request.dart';
import 'package:bitree/school/controller.dart';
import 'package:bitree/school/service.dart';
import 'package:bitree/school/storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/http.dart';
import 'support/test_app.dart';

class _DelayedSchoolStorage extends MemorySchoolStorage {
  _DelayedSchoolStorage({super.credentials});

  final readStarted = Completer<void>();
  final releaseRead = Completer<void>();

  @override
  Future<SchoolCredentials?> readCredentials() async {
    final saved = credentials;
    readStarted.complete();
    await releaseRead.future;
    return saved;
  }
}

class _DelayedClearSchoolStorage extends MemorySchoolStorage {
  _DelayedClearSchoolStorage({super.credentials});

  final clearStarted = Completer<void>();
  final releaseClear = Completer<void>();

  @override
  Future<void> clear() async {
    clearStarted.complete();
    await releaseClear.future;
    await super.clear();
  }
}

void main() {
  test('Disposing a school session cancels pending reads without notifying a dead view', () async {
    final app = TestAppController();
    await app.initialize();
    final school = SchoolController(
      service: SchoolService(),
      storage: MemorySchoolStorage(),
      timetable: app.timetable,
      agenda: app.agenda,
      academics: app.academics,
    );
    final response = Completer<int>();
    final read = school.read(
      '查询',
      (_) => response.future,
      verify: (_) async => null,
    );
    school.dispose();
    response.complete(1);
    expect(await read, isNull);
  });

  test('Cancelling a school read releases busy state without publishing its result', () async {
    final app = TestAppController();
    await app.initialize();
    final response = Completer<int>();
    final cancellation = CancellationToken();
    final read = app.school.read(
      '查询',
      (_) => response.future,
      verify: (_) async => null,
      cancellation: cancellation,
    );
    expect(app.school.busy, isTrue);
    cancellation.cancel();
    response.complete(1);
    expect(await read, isNull);
    expect(app.school.busy, isFalse);
  });

  test('Sign out cancels the active read before removing credentials and academic state', () async {
    final storage = MemorySchoolStorage(
      credentials: const SchoolCredentials(
        username: 'student',
        password: 'test',
      ),
    );
    final app = TestAppController(schoolStorage: storage);
    await app.initialize();
    final response = Completer<int>();
    final read = app.school.read(
      '查询',
      (_) => response.future,
      verify: (_) async => null,
    );
    final signOut = app.school.signOut();
    response.complete(1);
    expect(await read, isNull);
    expect(await signOut, isTrue);
    expect(app.school.busy, isFalse);
    expect(app.school.accountStatus, AccountStatus.signedOut);
    expect(app.school.username, isNull);
    expect(await storage.readCredentials(), isNull);
    expect(app.academics.record.grades, isEmpty);
  });

  test(
    'A delayed account read cannot restore credentials after sign out',
    () async {
      final storage = _DelayedSchoolStorage(
        credentials: const SchoolCredentials(
          username: 'stale-student',
          password: 'test',
        ),
      );
      final app = TestAppController(schoolStorage: storage);
      final loading = app.school.loadAccount();
      await storage.readStarted.future;

      expect(await app.school.signOut(), isTrue);
      storage.releaseRead.complete();
      await loading;

      expect(app.school.username, isNull);
      expect(app.school.accountStatus, AccountStatus.signedOut);
      expect(storage.credentials, isNull);
    },
  );

  test(
    'An account read started during sign out waits for the final storage state',
    () async {
      final storage = _DelayedClearSchoolStorage(
        credentials: const SchoolCredentials(
          username: 'stale-student',
          password: 'test',
        ),
      );
      final app = TestAppController(schoolStorage: storage);

      final signingOut = app.school.signOut();
      await storage.clearStarted.future;
      final loading = app.school.loadAccount();
      await Future<void>.delayed(Duration.zero);

      storage.releaseClear.complete();
      expect(await signingOut, isTrue);
      await loading;

      expect(app.school.username, isNull);
      expect(app.school.accountStatus, AccountStatus.signedOut);
    },
  );

  for (final source in [DeadlineSource.lexue, DeadlineSource.eclass]) {
    test('A source-specific DDL update only fetches ${source.label}', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final hosts = <String>{};
      server.listen((request) async {
        final path = request.uri.path;
        hosts.add(request.uri.pathSegments.first);
        switch (path) {
          case '/lexue.bit.edu.cn/login/index.php':
            request.response.write('<script>M.cfg={"sesskey":"test"}</script>');
          case '/lexue.bit.edu.cn/calendar/export.php':
            request.response.write(
              '<div class="calendarurl">https://lexue.bit.edu.cn/calendar/export_execute.php</div>',
            );
          case '/lexue.bit.edu.cn/calendar/export_execute.php':
            request.response.write('BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n');
          case '/lexue.bit.edu.cn/my/':
            request.response.write('<html><body></body></html>');
          case '/zy-eclass.bit.edu.cn/user/courses':
            request.response.headers.contentType = ContentType.json;
            request.response.write('{}');
          case '/zy-eclass.bit.edu.cn/api/my-courses':
            request.response.headers.contentType = ContentType.json;
            request.response.write(jsonEncode({'courses': [], 'pages': 1}));
          default:
            throw StateError('Unexpected request: $path');
        }
        await request.response.close();
      });
      final app = TestAppController();
      await app.initialize();
      final success = await HttpOverrides.runWithHttpOverrides(
        () => app.school.importDeadlines(
          source: source,
          verify: (_) async => null,
        ),
        LocalHttpOverrides(server.port),
      );
      expect(success, isTrue);
      expect(hosts, {source.origin.host});
      expect(app.school.busy, isFalse);
    });
  }

  test('New eclass quizzes with deadlines are imported as DDLs', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final detailRequests = <String>[];
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      switch (request.uri.path) {
        case '/zy-eclass.bit.edu.cn/user/courses':
          request.response.write('{}');
        case '/zy-eclass.bit.edu.cn/api/my-courses':
          request.response.write(
            jsonEncode({
              'courses': [
                {'id': 7, 'name': '概率论与数理统计'},
              ],
              'pages': 1,
            }),
          );
        case '/zy-eclass.bit.edu.cn/api/courses/7/activities':
          request.response.write(
            jsonEncode({
              'activities': [
                {
                  'id': 41,
                  'title': '第一周测验',
                  'type': 'QUIZ',
                  'end_time': '2026-12-01 23:59',
                },
                {
                  'id': 42,
                  'title': '第二周测验',
                  'type': 'courseware_quiz',
                  'visible_end_at': '2026-12-02 23:59',
                },
                {
                  'id': 43,
                  'title': '课程资料',
                  'type': 'material',
                  'submit_times': 1,
                  'end_time': '2026-12-03 23:59',
                },
              ],
            }),
          );
        case final path
            when path.startsWith('/zy-eclass.bit.edu.cn/api/activities/'):
          final id = request.uri.pathSegments.last;
          detailRequests.add(id);
          request.response.write(
            jsonEncode({'user_submit_count': id == '42' ? 1 : 0}),
          );
        default:
          throw StateError('Unexpected request: ${request.uri.path}');
      }
      await request.response.close();
    });
    final app = TestAppController();
    await app.initialize();

    final success = await HttpOverrides.runWithHttpOverrides(
      () => app.school.importDeadlines(
        source: DeadlineSource.eclass,
        verify: (_) async => null,
      ),
      LocalHttpOverrides(server.port),
    );

    expect(success, isTrue);
    expect(detailRequests, ['41', '42']);
    expect(app.agenda.entries, hasLength(2));
    final first = app.agenda.entries.singleWhere(
      (entry) => entry.id == 'eclass-41',
    );
    expect(first.title, '第一周测验');
    expect(first.course, '概率论与数理统计');
    expect(first.kind, AgendaKind.deadline);
    expect(first.source, DeadlineSource.eclass);
    expect(first.startsAt, DateTime.utc(2026, 12, 1, 23, 59));
    expect(first.done, isFalse);
    final second = app.agenda.entries.singleWhere(
      (entry) => entry.id == 'eclass-42',
    );
    expect(second.startsAt, DateTime.utc(2026, 12, 2, 23, 59));
    expect(second.done, isTrue);
  });

  test('Cancelling a DDL update releases the school controller', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final first = Completer<void>();
    final hosts = <String>[];
    server.listen((request) {
      hosts.add(request.uri.pathSegments.first);
      if (!first.isCompleted) first.complete();
    });
    final app = TestAppController();
    await app.initialize();
    await HttpOverrides.runWithHttpOverrides(() async {
      final updating = app.school.importDeadlines(
        source: DeadlineSource.lexue,
        verify: (_) async => null,
      );
      await first.future;
      app.school.cancel();
      expect(await updating, isFalse);
    }, LocalHttpOverrides(server.port));
    expect(hosts, ['lexue.bit.edu.cn']);
    expect(app.agenda.entries, isEmpty);
    expect(app.school.busy, isFalse);
  });
}
