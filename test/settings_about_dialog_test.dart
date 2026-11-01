import 'package:bitree/app/ui/settings_screen.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  testWidgets(
    'About keeps the fixed project description in a dialog',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel('dev.fluttercommunity.plus/package_info');
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
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

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
      expect(find.text('面向北京理工大学的妙妙小工具'), findsOneWidget);

      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
