import 'package:bitree/app/ui/settings_screen.dart';
import 'package:bitree/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'support/test_app.dart';

void main() {
  test(
    'Palette persists while developer mode resets for each app session',
    () async {
      final preferences = MemoryPreferences();
      final first = TestAppController(preferences: preferences);
      await first.initialize();
      expect(first.developerMode, isFalse);
      expect(first.paletteIdFor(Brightness.dark), isNull);
      first.unlockDeveloperMode();
      expect(first.developerMode, isTrue);
      final writes = [
        first.setCoursePalette(Brightness.dark, 'mocha'),
        first.setCoursePalette(Brightness.dark, 'macchiato'),
        first.setCoursePalette(Brightness.dark, 'frappe'),
      ];
      await Future.wait(writes);

      final second = TestAppController(preferences: preferences);
      await second.initialize();
      expect(second.developerMode, isFalse);
      expect(second.paletteIdFor(Brightness.dark), 'frappe');
      await second.setCoursePalette(Brightness.dark, null);

      final third = TestAppController(preferences: preferences);
      await third.initialize();
      expect(third.paletteFor(Brightness.dark), isNull);
    },
  );

  test(
    'Widget system course palette defaults off and persists independently of developer mode',
    () async {
      final preferences = MemoryPreferences();
      final first = TestAppController(preferences: preferences);
      await first.initialize();
      expect(first.widgetUseSystemPalette, isFalse);
      await Future.wait([
        first.setWidgetUseSystemPalette(true),
        first.setWidgetUseSystemPalette(false),
        first.setWidgetUseSystemPalette(true),
        first.setCoursePalette(Brightness.dark, 'mocha'),
      ]);

      final second = TestAppController(preferences: preferences);
      await second.initialize();
      expect(second.widgetUseSystemPalette, isTrue);
      expect(second.paletteIdFor(Brightness.dark), 'mocha');
      expect(second.developerMode, isFalse);
      await second.setCoursePalette(Brightness.dark, null);
      expect(second.widgetUseSystemPalette, isTrue);
      await second.setWidgetUseSystemPalette(false);

      final third = TestAppController(preferences: preferences);
      await third.initialize();
      expect(third.widgetUseSystemPalette, isFalse);
      expect(third.paletteFor(Brightness.dark), isNull);
    },
  );

  test('Unknown saved palette falls back to the current app colours', () async {
    final preferences = MemoryPreferences();
    await preferences.setString('darkCoursePalette', 'retired-palette');
    final controller = TestAppController(preferences: preferences);
    await controller.initialize();
    expect(controller.paletteFor(Brightness.dark), isNull);
    expect(controller.developerMode, isFalse);
  });

  testWidgets(
    'Five consecutive About icon taps keep developer mode without revealing options',
    (tester) async {
      final semantics = tester.ensureSemantics();
      addTearDown(semantics.dispose);
      PackageInfo.setMockInitialValues(
        appName: 'BITree',
        packageName: 'app.bitree',
        version: '0.3.0',
        buildNumber: '1',
        buildSignature: '',
      );
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = TestAppController();
      await controller.loadCoursePalettes();
      await controller.setTheme(ThemeMode.dark);
      await tester.pumpWidget(BitreeApp(controller: controller));
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('设置'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('更多设置'), findsNothing);
      expect(find.text('小组件使用系统调色板'), findsNothing);
      expect(find.text('全局系统调色板（实验性）'), findsNothing);
      final scrollable = find
          .descendant(
            of: find.byType(SettingsScreen),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('关于 BITree'),
        200,
        scrollable: scrollable,
      );
      await tester.tap(find.text('关于 BITree'));
      await tester.pumpAndSettle();
      final icon = find.bySemanticsLabel('BITree 图标');
      for (var i = 0; i < 4; i++) {
        await tester.tap(icon);
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(controller.developerMode, isFalse);
      // A pause starts a fresh sequence.
      await tester.pump(const Duration(seconds: 3));
      for (var i = 0; i < 4; i++) {
        await tester.tap(icon);
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(controller.developerMode, isFalse);
      await tester.tap(icon);
      await tester.pumpAndSettle();
      expect(controller.developerMode, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('更多设置'), findsNothing);
      expect(find.text('深色模式调色板'), findsNothing);
      expect(find.text('小组件使用系统调色板'), findsNothing);
      expect(find.text('全局系统调色板（实验性）'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('外观'),
        -200,
        scrollable: scrollable,
      );
      expect(find.text('外观'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
