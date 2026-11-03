import 'dart:io';

import 'package:bitree/mooc/credentials.dart';
import 'package:bitree/mooc/ui/login.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_all/webview_all.dart';

import 'support/mooc_browser.dart';
import 'support/test_app.dart';

void main() {
  late TestMoocBrowser browser;
  setUp(() => WebViewPlatform.instance = browser = TestMoocBrowser());

  Future<void> open(
    WidgetTester tester,
    TestAppController model, {
    List<Cookie>? initialCookies,
    ValueChanged<bool>? completed,
  }) async {
    await model.initialize();
    await tester.pumpWidget(
      MaterialApp(
        theme: bitreeTheme(Brightness.light),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final result = await loginToMooc(
                  context,
                  model.mooc,
                  initialCookies: initialCookies,
                );
                completed?.call(result);
              },
              child: const Text('登录'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('登录'));
    await tester.pumpAndSettle();
  }

  void signIn({bool finishLoading = true}) {
    browser.cookies.addAll([
      for (final name in ['NTESSTUDYSI', 'STUDY_SESS'])
        WebViewCookie(
          name: name,
          value: 'test-session',
          domain: '.icourse163.org',
        ),
    ]);
    browser.cookies.add(
      const WebViewCookie(
        name: 'browser_preference',
        value: 'id,time',
        domain: '.icourse163.org',
      ),
    );
    browser.controller.snapshot = {
      'id': '8',
      'name': '昵称有 " 引号和 }; 符号',
      'userAgent': 'Actual embedded browser',
    };
    if (finishLoading) browser.controller.finishLoading();
  }

  testWidgets(
    'Login is embedded and cookies alone do not mark a guest signed in',
    (tester) async {
      final storage = MemoryMoocStorage();
      final model = TestAppController(moocStorage: storage);
      await open(tester, model);
      expect(find.byType(WebViewWidget), findsOneWidget);
      expect(browser.controller.url!.path, '/member/login.htm');
      browser.cookies.add(
        const WebViewCookie(
          name: 'NTESSTUDYSI',
          value: 'guest',
          domain: '.icourse163.org',
        ),
      );
      await tester.tap(find.text('完成登录'));
      await tester.pumpAndSettle();
      expect(find.text('请先在页面中完成登录。'), findsOneWidget);
      expect(storage.account, isNull);
      expect(model.mooc.busy, isFalse);
      await tester.pageBack();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'The page account and exported session return to the calling screen',
    (tester) async {
      final storage = MemoryMoocStorage();
      final model = TestAppController(moocStorage: storage);
      bool? result;
      await open(tester, model, completed: (value) => result = value);
      signIn();
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(find.byType(WebViewWidget), findsNothing);
      expect(storage.account!.id, '8');
      expect(storage.account!.name, '昵称有 " 引号和 }; 符号');
      expect(storage.account!.credentials.userAgent, 'Actual embedded browser');
      final restored = MoocAccount.fromJson(storage.account!.toJson());
      expect(
        restored.credentials.cookies.join(';'),
        contains('browser_preference=id,time'),
      );
      expect(
        storage.account!.credentials.cookies.join(';'),
        contains('STUDY_SESS=test-session'),
      );
      expect(model.agenda.entries, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final action in ['完成登录', '刷新登录页']) {
    testWidgets(
      '$action captures an already signed-in browser with comma cookies',
      (tester) async {
        final model = TestAppController();
        bool? result;
        await open(tester, model, completed: (value) => result = value);
        signIn(finishLoading: false);
        await tester.tap(
          action == '完成登录' ? find.text(action) : find.byTooltip(action),
        );
        await tester.pumpAndSettle();
        expect(result, isTrue);
        expect(model.mooc.account!.id, '8');
        expect(find.byType(WebViewWidget), findsNothing);
      },
    );
  }

  testWidgets('Cookie fallback uses the same embedded account capture', (
    tester,
  ) async {
    final model = TestAppController();
    final cookies = MoocCredentials.cookiesFromHeader(
      'NTESSTUDYSI=csrf; STUDY_SESS=seed',
    );
    await open(tester, model, initialCookies: cookies);
    expect(find.byType(WebViewWidget), findsOneWidget);
    expect(browser.controller.url!.path, '/home.htm');
    expect(
      browser.cookies.singleWhere((c) => c.name == 'STUDY_SESS').value,
      'seed',
    );
    browser.cookies.clear();
    signIn();
    await tester.pumpAndSettle();
    expect(model.mooc.account!.id, '8');
    expect(find.byType(WebViewWidget), findsNothing);
  });
}
