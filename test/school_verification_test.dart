import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bitree/academics/model.dart';
import 'package:bitree/agenda/deadline_source.dart';
import 'package:bitree/agenda/model.dart';
import 'package:bitree/app/ui/settings_screen.dart';
import 'package:bitree/core/diagnostics.dart';
import 'package:bitree/schedule/model.dart';
import 'package:bitree/school/controller.dart';
import 'package:bitree/school/network.dart';
import 'package:bitree/school/storage.dart';
import 'package:bitree/school/verification.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/http.dart';
import 'support/test_app.dart';

/// Serves login pages through the real HTTP and authentication implementation.
class _LoginServer {
  _LoginServer(this.server, this.kind) {
    server.listen(_respond);
  }

  final HttpServer server;
  final SchoolVerificationKind kind;
  final paths = <String>[];
  final unexpected = <String>[];
  bool authenticated = false;
  bool serviceSessionValid = false;
  bool failAuthentication = false;

  static Future<_LoginServer> start(SchoolVerificationKind kind) async =>
      _LoginServer(
        await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
        kind,
      );

  LocalHttpOverrides get network => LocalHttpOverrides(server.port);

  void _redirect(HttpResponse response, Uri location) {
    response.statusCode = 302;
    response.headers.set(HttpHeaders.locationHeader, '$location');
  }

  Future<void> _respond(HttpRequest request) async {
    final path = request.uri.path;
    paths.add(path);
    final response = request.response;
    final sso = Uri.https('sso.bit.edu.cn', '/cas/login', {
      'service': '${SchoolNetwork.campus.accountPage}',
    });
    if (path.startsWith('/webvpn.bit.edu.cn/')) {
      response.statusCode = 503;
    } else if (path.startsWith('/jxzxehallapp.bit.edu.cn/')) {
      if (!authenticated && !serviceSessionValid) _redirect(response, sso);
    } else if (path == '/jxzxehall.bit.edu.cn/auth-protocol-core/login' ||
        path.startsWith('/jwms.bit.edu.cn/') ||
        path.startsWith('/lexue.bit.edu.cn/') ||
        path.startsWith('/zy-eclass.bit.edu.cn/')) {
      _redirect(response, sso);
    } else if (path == '/sso.bit.edu.cn/cas/login') {
      if (failAuthentication) {
        response.statusCode = 503;
        await response.close();
        return;
      }
      if (request.method == 'POST') {
        final form = Uri.splitQueryString(
          await utf8.decoder.bind(request).join(),
        );
        expect(form['captcha_code'], '1234');
        authenticated = true;
      }
      if (authenticated) {
        _redirect(response, SchoolNetwork.campus.accountPage);
      } else if (kind == SchoolVerificationKind.sms) {
        response.write('''
          <p id="login-page-flowkey">sms-flow</p>
          <p id="user-object-id">test-user</p>
          <form id="secondSmsLoginForm" method="post"></form>
        ''');
      } else {
        response.write('''
          <p id="login-page-flowkey">password-flow</p>
          <p id="login-croypto">AAECAwQFBgcICQoLDA0ODw==</p>
          <form method="post"></form>
        ''');
      }
    } else if (path.endsWith('/findCaptchaCount/202526100123')) {
      response.write(
        jsonEncode({
          'data': {'captchaInvisible': true, 'captchaUrl': '/cas/captcha.png'},
        }),
      );
    } else if (path == '/sso.bit.edu.cn/cas/captcha.png') {
      response.add(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
        ),
      );
    } else {
      unexpected.add(path);
      response.statusCode = 400;
    }
    await response.close();
  }
}

Future<TestAppController> _app() async {
  final app = TestAppController(
    schedule: SemesterSchedule(
      term: '2026-2027-1',
      firstMonday: DateTime.utc(2026, 9, 21),
      courses: [
        Course(
          id: 'local',
          name: '手动课程',
          weekday: 1,
          startSection: 1,
          endSection: 2,
          weeks: [1],
          local: true,
        ),
      ],
    ),
    entries: [
      AgendaEntry(
        id: 'deadline',
        title: '保留的 DDL',
        kind: AgendaKind.deadline,
        startsAt: DateTime.utc(2026, 11, 1),
        done: true,
      ),
    ],
    schoolStorage: MemorySchoolStorage(
      credentials: const SchoolCredentials(
        username: '202526100123',
        password: 'test',
      ),
    ),
  );
  await app.initialize();
  await app.academics.save(const AcademicRecord(targetCredits: 160));
  return app;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory directory;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp(
      'bitree-verification-logs-',
    );
  });
  setUp(() {
    messenger.setMockMethodCallHandler(channel, (_) async => directory.path);
  });
  tearDownAll(() async {
    await AppDiagnostics.instance.recentLines();
    messenger.setMockMethodCallHandler(channel, null);
    await directory.delete(recursive: true);
  });

  test(
    'A device without saved credentials cannot report successful verification',
    () async {
      final app = TestAppController();
      await app.initialize();
      expect(await app.school.restoreAccount(), isFalse);
      expect(app.school.accountStatus, AccountStatus.signedOut);
    },
  );

  for (final kind in SchoolVerificationKind.values) {
    test(
      'Startup defers $kind before loading a code or asking for input',
      () async {
        final server = await _LoginServer.start(kind);
        addTearDown(() => server.server.close(force: true));
        final app = await _app();
        final schedule = app.timetable.schedule;
        final deadline = app.agenda.entries.single;
        final academics = app.academics.record;
        final status = kind == SchoolVerificationKind.sms
            ? AccountStatus.smsRequired
            : AccountStatus.imageRequired;
        final notice = expectLater(
          AppDiagnostics.instance.messages,
          emits('学校登录验证未完成，请在设置中完成验证。'),
        );
        final success = await HttpOverrides.runWithHttpOverrides(
          app.school.restoreAccount,
          server.network,
        );
        await notice;
        expect(success, isFalse);
        expect(app.school.accountStatus, status);
        expect(app.school.busy, isFalse);
        expect(
          server.paths,
          isNot(contains('/sso.bit.edu.cn/cas/captcha.png')),
        );
        expect(
          server.unexpected,
          isEmpty,
        ); // Also excludes phone lookup and SMS sending.
        expect(app.timetable.schedule, same(schedule));
        expect(app.agenda.entries.single, same(deadline));
        expect(app.academics.record, same(academics));
      },
    );
  }

  test('Manual verification reaches SSO despite a valid service session, and cancellation is retryable', () async {
    final server = await _LoginServer.start(SchoolVerificationKind.image);
    addTearDown(() => server.server.close(force: true));
    final app = await _app();
    final schedule = app.timetable.schedule;
    final deadline = app.agenda.entries.single;
    final academics = app.academics.record;
    await HttpOverrides.runWithHttpOverrides(() async {
      await app.school.restoreAccount();
      server.serviceSessionValid = true;
      expect(
        await app.school.restoreAccount(verify: (_) async => null),
        isFalse,
      );
      expect(app.school.accountStatus, AccountStatus.imageRequired);
      server.failAuthentication = true;
      expect(
        await app.school.restoreAccount(
          verify: (_) async =>
              fail('A connection failure must not open verification'),
        ),
        isFalse,
      );
      expect(app.school.accountStatus, AccountStatus.imageRequired);
      server.failAuthentication = false;
      expect(
        await app.school.restoreAccount(
          verify: (request) async {
            expect(request, isA<SchoolImageVerification>());
            return '1234';
          },
        ),
        isTrue,
      );
    }, server.network);
    expect(app.school.accountStatus, AccountStatus.signedIn);
    expect(app.school.verificationRequired, isFalse);
    expect(server.unexpected, isEmpty);
    expect(app.timetable.schedule, same(schedule));
    expect(app.agenda.entries.single, same(deadline));
    expect(app.academics.record, same(academics));
  });

  for (final operation in ['课表', '考试', '成绩', '学分', '乐学', '新延河', '空教室']) {
    test(
      'Cancelling verification during $operation keeps the pending account state',
      () async {
        final server = await _LoginServer.start(SchoolVerificationKind.image);
        addTearDown(() => server.server.close(force: true));
        final app = await _app();
        final schedule = app.timetable.schedule;
        final deadline = app.agenda.entries.single;
        final academics = app.academics.record;
        var prompted = false;
        Future<String?> verify(SchoolVerification request) async {
          prompted = true;
          return null;
        }

        await HttpOverrides.runWithHttpOverrides(() async {
          switch (operation) {
            case '课表':
              await app.school.synchronize(verify: verify);
            case '考试':
              await app.school.importExams(verify: verify);
            case '成绩':
              await app.school.importGrades(verify: verify);
            case '学分':
              await app.school.importStudyPlan(verify: verify);
            case '乐学':
              await app.school.importDeadlines(
                source: DeadlineSource.lexue,
                verify: verify,
              );
            case '新延河':
              await app.school.importDeadlines(
                source: DeadlineSource.eclass,
                verify: verify,
              );
            case '空教室':
              await app.school.read(
                '空教室查询',
                (session) => session.checkLogin(),
                verify: verify,
              );
          }
        }, server.network);
        expect(prompted, isTrue);
        expect(app.school.accountStatus, AccountStatus.imageRequired);
        expect(app.school.busy, isFalse);
        expect(server.unexpected, isEmpty);
        expect(app.timetable.schedule, same(schedule));
        expect(app.agenda.entries.single, same(deadline));
        expect(app.academics.record, same(academics));
      },
    );
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'Settings shows and resolves pending SMS verification in $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final server = (await tester.runAsync(
          () => _LoginServer.start(SchoolVerificationKind.sms),
        ))!;
        addTearDown(() => server.server.close(force: true));
        final app = await _app();
        await tester.runAsync(
          () => HttpOverrides.runWithHttpOverrides(
            app.school.restoreAccount,
            server.network,
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: bitreeTheme(brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(1.3)),
              child: child!,
            ),
            home: Scaffold(
              body: SettingsScreen(
                controller: app,
                checkingForUpdates: false,
                onCheckForUpdates: () {},
              ),
            ),
          ),
        );
        expect(find.text('需要短信验证'), findsOneWidget);
        expect(find.text('验证').hitTestable(), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);

        // The session may have been verified elsewhere since the pending notice.
        server.authenticated = true;
        await tester.runAsync(
          () => HttpOverrides.runWithHttpOverrides(() async {
            final verified = Completer<void>();
            void changed() {
              if (app.school.accountStatus == AccountStatus.signedIn &&
                  !verified.isCompleted) {
                verified.complete();
              }
            }

            app.school.addListener(changed);
            try {
              await tester.tap(find.text('验证'));
              await verified.future;
            } finally {
              app.school.removeListener(changed);
            }
          }, server.network),
        );
        await tester.pumpAndSettle();
        expect(find.text('已登录'), findsOneWidget);
        expect(find.text('验证'), findsNothing);
        expect(server.unexpected, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
