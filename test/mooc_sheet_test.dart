import 'dart:convert';
import 'dart:io';

import 'package:bitree/mooc/credentials.dart';
import 'package:bitree/mooc/ui/mooc_sheet.dart';
import 'package:bitree/sync/controller.dart';
import 'package:bitree/sync/ui/sync_button.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_all/webview_all.dart';

import 'support/http.dart';
import 'support/mooc_browser.dart';
import 'support/mooc_login_server.dart';
import 'support/test_app.dart';

void main() {
  late TestMoocBrowser browser;
  setUp(() => WebViewPlatform.instance = browser = TestMoocBrowser());
  MemoryMoocStorage signedInStorage() => MemoryMoocStorage()
    ..account = MoocAccount(
      id: '8',
      name: '姓名很长的中国大学MOOC 测试账号',
      credentials: MoocCredentials(
        userAgent: 'test',
        cookies: [
          Cookie('NTESSTUDYSI', 'csrf'),
          Cookie('STUDY_SESS', 'session'),
        ],
      ),
    );

  Future<void> pump(
    WidgetTester tester,
    TestAppController model, {
    double scale = 1,
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await model.initialize();
    await tester.pumpWidget(
      MaterialApp(
        theme: bitreeTheme(brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(body: MoocAccountTile(controller: model.mooc)),
      ),
    );
    await tester.tap(find.text('中国大学MOOC'));
    await tester.pumpAndSettle();
  }

  Future<MoocLoginServer> startLoginServer(WidgetTester tester) async {
    final server = (await tester.runAsync(MoocLoginServer.start))!;
    final previous = HttpOverrides.current;
    HttpOverrides.global = LocalHttpOverrides(server.port);
    addTearDown(() async {
      HttpOverrides.global = previous;
      await server.close();
    });
    return server;
  }

  Future<void> waitFor(WidgetTester tester, bool Function() condition) async {
    final watch = Stopwatch()..start();
    while (!condition() && watch.elapsed < const Duration(seconds: 5)) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(condition(), isTrue);
  }

  void finishLogin() {
    browser.cookies.add(
      const WebViewCookie(
        name: 'NTESSTUDYSI',
        value: 'test',
        domain: '.icourse163.org',
      ),
    );
    browser.cookies.add(
      const WebViewCookie(
        name: 'STUDY_SESS',
        value: 'session',
        domain: '.icourse163.org',
      ),
    );
    browser.controller.snapshot = {
      'id': '8',
      'name': '测试账号',
      'userAgent': 'test',
    };
    browser.controller.finishLoading();
  }

  Future<void> selectMooc(WidgetTester tester) async {
    await tester.tap(find.byTooltip('同步'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('自定义同步'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清空'));
    await tester.pump();
    await tester.ensureVisible(find.text('中国大学MOOC DDL'));
    await tester.tap(find.text('中国大学MOOC DDL'));
    await tester.pump();
    await tester.tap(find.text('同步所选内容'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'Cookie fallback validates locally and fits a narrow $brightness screen',
      (tester) async {
        final model = TestAppController();
        await pump(tester, model, scale: 1.4, brightness: brightness);
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.text('网页登录'), findsOneWidget);
        await tester.tap(find.text('使用 Cookie'));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.text('网页登录'), findsOneWidget);
        await tester.tap(find.text('使用 Cookie'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.widgetWithText(FilledButton, '连接'));
        await tester.tap(find.widgetWithText(FilledButton, '连接'));
        await tester.pump();
        expect(find.text('请粘贴 Cookie'), findsOneWidget);
        await tester.enterText(find.byType(TextFormField), 'not-a-cookie');
        await tester.tap(find.widgetWithText(FilledButton, '连接'));
        await tester.pumpAndSettle();
        expect(find.text('没有读取到中国大学MOOC 会话，请先完成登录。'), findsOneWidget);
        expect(model.mooc.account, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Account and SMS forms keep native login inside one drawer', (
    tester,
  ) async {
    final server = await startLoginServer(tester);
    final model = TestAppController();
    await pump(tester, model, scale: 1.3);

    await tester.tap(find.text('账号密码'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'student@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await waitFor(tester, () => model.mooc.account?.id == '123');
    await tester.pumpAndSettle();

    expect(model.mooc.account!.name, '测试账号');
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(WebViewWidget), findsNothing);
    expect(
      server.requests,
      contains('POST /reg.icourse163.org/dl/zj/yd/pwd/l'),
    );
  });

  testWidgets('Failed password login preserves fields and the saved account', (
    tester,
  ) async {
    final server = await startLoginServer(tester);
    server.passwordResult = {'ret': 413};
    final model = TestAppController(moocStorage: signedInStorage());
    await pump(tester, model, scale: 1.4);

    await tester.tap(find.text('账号密码'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'student@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong');
    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await waitFor(tester, () => find.text('账号或密码错误').evaluate().isNotEmpty);

    expect(find.text('student@example.com'), findsOneWidget);
    expect(find.text('wrong'), findsOneWidget);
    expect(model.mooc.account!.id, '8');
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CAPTCHA refreshes after a load timeout and retries login', (
    tester,
  ) async {
    final server = await startLoginServer(tester);
    server.passwordResult = {'ret': 445};
    final model = TestAppController();
    await pump(tester, model);

    await tester.tap(find.text('账号密码'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'student@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await waitFor(tester, () => find.text('完成人机验证').evaluate().isNotEmpty);
    await waitFor(
      tester,
      () => find.byType(WebViewWidget).evaluate().isNotEmpty,
    );

    expect(find.text('登录需要完成人机验证'), findsOneWidget);
    expect(find.text('改用网页登录'), findsNothing);
    expect(find.text('登录中国大学MOOC'), findsNothing);
    expect(find.byKey(const ValueKey('mooc-captcha-dialog')), findsOneWidget);
    expect(find.byType(WebViewWidget), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(WebViewWidget),
        matching: find.byType(ClipRRect),
      ),
      findsNothing,
    );
    expect(
      find.ancestor(
        of: find.byType(WebViewWidget),
        matching: find.byType(PhysicalShape),
      ),
      findsNothing,
    );
    expect(browser.controller.html, contains('initNECaptcha'));
    expect(browser.controller.html, contains("element: '#captcha'"));
    expect(browser.controller.html, contains("width: '256px'"));
    expect(
      browser.controller.html,
      contains('a3b396bb2f589bbc1151f0fa61d14747'),
    );
    expect(browser.controller.html, isNot(contains('/member/login.htm')));
    expect(browser.controller.html, isNot(contains('登录中国大学MOOC')));
    expect(browser.controller.html, isNot(contains('课程')));
    expect(browser.controller.baseUrl, startsWith('https://'));
    expect(browser.controller.userAgent, contains('Chrome/140'));
    // A Mobile user agent makes the CAPTCHA ignore desktop mouse events.
    expect(browser.controller.userAgent, isNot(contains('Mobile')));
    expect(browser.cookies.any((cookie) => cookie.name == 'utid'), isTrue);
    server.passwordResult = {'ret': 201};
    browser.controller.finishLoading();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final timedOutBrowser = browser.controller;
    await tester.pump(const Duration(seconds: 20));
    expect(find.text('验证码加载失败'), findsOneWidget);
    expect(model.mooc.account, isNull);
    await tester.tap(find.widgetWithText(FilledButton, '刷新'));
    await waitFor(
      tester,
      () =>
          browser.controller != timedOutBrowser &&
          browser.controller.html != null,
    );
    expect(timedOutBrowser.closeCount, 1);
    browser.controller.snapshot = {'ready': true, 'solution': 'verified-token'};
    await tester.pump(const Duration(milliseconds: 200));
    await waitFor(tester, () => model.mooc.account?.id == '123');
    await tester.pumpAndSettle();

    expect(model.mooc.account!.name, '测试账号');
    expect(
      model.mooc.account!.credentials.userAgent,
      browser.controller.userAgent,
    );
    expect(browser.controller.closeCount, 1);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('同步中国大学MOOC DDL'), findsNothing);
    expect(model.agenda.entries, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cancelling CAPTCHA keeps the form and signed-in account', (
    tester,
  ) async {
    final server = await startLoginServer(tester);
    server.passwordResult = {'ret': 445};
    final model = TestAppController(moocStorage: signedInStorage());
    await pump(tester, model);

    await tester.tap(find.text('账号密码'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'student@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await waitFor(
      tester,
      () => find
          .byKey(const ValueKey('mooc-captcha-dialog'))
          .evaluate()
          .isNotEmpty,
    );

    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();

    expect(browser.controller.closeCount, 1);
    expect(find.byKey(const ValueKey('mooc-captcha-dialog')), findsNothing);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('student@example.com'), findsOneWidget);
    expect(find.text('password'), findsOneWidget);
    expect(find.text('登录需要完成人机验证'), findsOneWidget);
    expect(model.mooc.account!.id, '8');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sending an SMS code can verify and retry in place', (
    tester,
  ) async {
    browser.finishHtmlLoads = false;
    final server = await startLoginServer(tester);
    server.smsSendResult = {'ret': 445};
    final model = TestAppController();
    await pump(tester, model);

    await tester.tap(find.text('短信验证码'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '13800138000');
    await tester.tap(find.text('获取验证码'));
    await waitFor(tester, () => find.text('完成人机验证').evaluate().isNotEmpty);
    await waitFor(tester, () => browser.controller.html != null);

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(server.smsSendAttempts, 1);
    server.smsSendResult = {'ret': 201, 'cd': 2};
    browser.controller.snapshot = {'ready': true, 'solution': 'sms-send-token'};
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 400));
    expect(server.smsSendAttempts, 1);
    expect(find.byKey(const ValueKey('mooc-captcha-dialog')), findsOneWidget);
    browser.controller.finishLoading();
    await waitFor(
      tester,
      () => find.textContaining('秒后重发').evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();

    expect(server.smsSendAttempts, 2);
    expect(find.byKey(const ValueKey('mooc-captcha-dialog')), findsNothing);
    expect(find.text('13800138000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Logging in with an SMS code can verify and retry in place', (
    tester,
  ) async {
    final server = await startLoginServer(tester);
    server.smsLoginResult = {'ret': 445};
    final model = TestAppController();
    await pump(tester, model);

    await tester.tap(find.text('短信验证码'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '13800138000');
    await tester.tap(find.text('获取验证码'));
    await waitFor(
      tester,
      () => find.textContaining('秒后重发').evaluate().isNotEmpty,
    );
    await tester.enterText(find.byType(TextFormField).at(1), '123456');
    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await waitFor(tester, () => find.text('完成人机验证').evaluate().isNotEmpty);

    expect(server.smsLoginAttempts, 1);
    server.smsLoginResult = {'ret': 201};
    browser.controller.snapshot = {
      'ready': true,
      'solution': 'sms-login-token',
    };
    browser.controller.finishLoading();
    await waitFor(tester, () => model.mooc.account?.id == '123');
    await tester.pumpAndSettle();

    expect(server.smsLoginAttempts, 2);
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SMS send, countdown and login share one drawer session', (
    tester,
  ) async {
    final server = await startLoginServer(tester);
    final model = TestAppController();
    await pump(tester, model, scale: 1.3);

    await tester.tap(find.text('短信验证码'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '13800138000');
    await tester.tap(find.text('获取验证码'));
    await waitFor(
      tester,
      () => find.textContaining('秒后重发').evaluate().isNotEmpty,
    );
    await tester.enterText(find.byType(TextFormField).at(1), '123456');
    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await waitFor(tester, () => model.mooc.account?.id == '123');
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(
      server.requests.where(
        (request) => request == 'POST /reg.icourse163.org/dl/zj/yd/sms/sm',
      ),
      hasLength(1),
    );
    expect(
      server.requests.where(
        (request) => request == 'POST /reg.icourse163.org/dl/zj/yd/sms/vfsms',
      ),
      hasLength(1),
    );
  });

  testWidgets('Cookie login validates natively without opening a WebView', (
    tester,
  ) async {
    await startLoginServer(tester);
    final model = TestAppController();
    await pump(tester, model);

    await tester.tap(find.text('使用 Cookie'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField),
      'NTESSTUDYSI=csrf; STUDY_SESS=session',
    );
    await tester.tap(find.widgetWithText(FilledButton, '连接'));
    await waitFor(tester, () => model.mooc.account?.id == '123');
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(WebViewWidget), findsNothing);
    expect(model.mooc.account!.name, '测试账号');
  });

  testWidgets('Connected account actions fit without repeating its status', (
    tester,
  ) async {
    final model = TestAppController(moocStorage: signedInStorage());
    await pump(tester, model, scale: 1.4);
    expect(find.textContaining('已连接'), findsNothing);
    expect(find.text('同步 DDL'), findsNothing);
    for (final action in ['账号密码', '短信验证码', '网页登录', '使用 Cookie', '退出账号']) {
      await tester.ensureVisible(find.text(action));
      expect(find.text(action).hitTestable(), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(find.textContaining('已连接'), findsNothing);
    expect(find.text(model.mooc.account!.name), findsOneWidget);
  });

  testWidgets('Disconnect keeps imported data and removes the saved account', (
    tester,
  ) async {
    final storage = signedInStorage();
    final model = TestAppController(moocStorage: storage);
    await pump(tester, model, scale: 1.3);
    await tester.tap(find.text('退出账号'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '退出'));
    await tester.pumpAndSettle();
    expect(storage.account, isNull);
    expect(find.text('网页登录'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('The existing import menu opens MOOC without a school login', (
    tester,
  ) async {
    final model = TestAppController();
    await model.initialize();
    await tester.pumpWidget(
      MaterialApp(
        theme: bitreeTheme(Brightness.light),
        home: Scaffold(body: SyncButton(controller: model)),
      ),
    );
    await selectMooc(tester);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('同步进度'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '登录'));
    await tester.pumpAndSettle();
    expect(find.text('网页登录'), findsOneWidget);
    expect(find.text('学号'), findsNothing);
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(find.text('同步进度'), findsOneWidget);
    await tester.tap(find.text('收起'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('同步中国大学MOOC DDL'), findsNothing);
    expect(model.mooc.account, isNull);
    expect(model.agenda.entries, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final expired in [false, true]) {
    testWidgets('Import runs outside account management, expired=$expired', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var authenticated = !expired;
      final server = (await tester.runAsync(() async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((request) async {
          await request.drain<void>();
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'code': authenticated ? 0 : 1,
              if (!authenticated) 'message': 'not_auth',
              'result': null,
            }),
          );
          await request.response.close();
        });
        return server;
      }))!;
      final previous = HttpOverrides.current;
      final network = LocalHttpOverrides(server.port);
      HttpOverrides.global = network;
      addTearDown(() async {
        HttpOverrides.global = previous;
        await server.close(force: true);
      });
      final model = TestAppController(moocStorage: signedInStorage());
      await model.initialize();
      Future<void> waitForSync() async {
        // Let socket events run, then flush continuations on the widget clock.
        final elapsed = Stopwatch()..start();
        while (model.mooc.busy &&
            elapsed.elapsed < const Duration(seconds: 5)) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        expect(model.mooc.busy, isFalse);
        await tester.pumpAndSettle();
      }

      await tester.pumpWidget(
        MaterialApp(
          theme: bitreeTheme(Brightness.light),
          home: Scaffold(body: SyncButton(controller: model)),
        ),
      );
      await selectMooc(tester);
      expect(model.mooc.busy, isTrue);
      await waitForSync();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('使用 Cookie'), findsNothing);
      expect(find.text('退出账号'), findsNothing);
      if (expired) {
        await tester.tap(find.text('查看'));
        await tester.pumpAndSettle();
        expect(find.text('同步进度'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, '登录'));
        await tester.pumpAndSettle();
        expect(find.text('网页登录'), findsOneWidget);
        await tester.tap(find.byTooltip('关闭').last);
        await tester.pumpAndSettle();
        expect(find.text('重试未完成的内容'), findsNothing);
        await tester.tap(find.widgetWithText(TextButton, '登录'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('网页登录'));
        await tester.pumpAndSettle();
        authenticated = true;
        finishLogin();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await waitForSync();
        expect(find.text('已同步 0 条 DDL'), findsOneWidget);
        await tester.tap(find.text('收起'));
        await tester.pumpAndSettle();
      } else {
        expect(
          model.sync.results[SyncTarget.mooc]?.outcome,
          SyncOutcome.synced,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Dismissing the login choices returns to the same screen', (
    tester,
  ) async {
    final model = TestAppController();
    await pump(tester, model);
    await tester.tap(find.text('网页登录'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('登录中国大学MOOC'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('网页登录'), findsOneWidget);
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(MoocAccountTile), findsOneWidget);
    await tester.tap(find.text('中国大学MOOC'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(model.mooc.account, isNull);
    expect(model.agenda.entries, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
