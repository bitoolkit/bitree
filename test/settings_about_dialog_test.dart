import 'package:bitree/app/ui/settings_screen.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  testWidgets('About keeps the fixed project description in a dialog', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('dev.fluttercommunity.plus/package_info');
    const urlLauncherChannel = MethodChannel('plugins.flutter.io/url_launcher');
    final launchedUrls = <String>[];
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {
        'appName': 'BITree',
        'packageName': 'cn.edu.bit.bitree',
        'version': '0.3.0',
        'buildNumber': '1',
        'buildSignature': '',
      },
    );
    messenger.setMockMethodCallHandler(urlLauncherChannel, (call) async {
      if (call.method == 'launch') {
        launchedUrls.add((call.arguments as Map)['url'] as String);
      }
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    addTearDown(
      () => messenger.setMockMethodCallHandler(urlLauncherChannel, null),
    );

    final controller = TestAppController();
    await controller.initialize();
    await tester.pumpWidget(
      MaterialApp(
        theme: bitreeTheme(Brightness.light),
        home: Scaffold(
          body: SettingsScreen(
            controller: controller,
            checkingForUpdates: false,
            onCheckForUpdates: () {},
          ),
        ),
      ),
    );

    final about = find.text('关于 BITree');
    await tester.ensureVisible(about);
    await tester.tap(about);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('面向冰红茶的妙妙小工具'), findsOneWidget);
    expect(find.text('关闭'), findsNothing);

    for (final width in [390.0, 320.0]) {
      tester.view.physicalSize = Size(width, 844);
      await tester.pumpAndSettle();
      final licensesY = tester.getCenter(find.text('查看许可')).dy;
      expect(tester.getCenter(find.text('GitHub')).dy, licensesY);
      expect(tester.getCenter(find.text('交流群')).dy, licensesY);
      expect(tester.takeException(), isNull);
    }

    await tester.tap(find.text('交流群'));
    await tester.pumpAndSettle();
    expect(launchedUrls, ['https://qm.qq.com/q/84t3ZHKMpO']);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
