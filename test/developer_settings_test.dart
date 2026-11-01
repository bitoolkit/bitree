import 'package:bitree/app/settings_controller.dart';
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
      expect(first.settings.developerMode, isFalse);
      expect(first.settings.paletteIdFor(Brightness.dark), isNull);
      first.settings.unlockDeveloperMode();
      expect(first.settings.developerMode, isTrue);
      final writes = [
        first.settings.setCoursePalette(Brightness.dark, 'mocha'),
        first.settings.setCoursePalette(Brightness.dark, 'macchiato'),
        first.settings.setCoursePalette(Brightness.dark, 'frappe'),
      ];
      await Future.wait(writes);

      final second = TestAppController(preferences: preferences);
      await second.initialize();
      expect(second.settings.developerMode, isFalse);
      expect(second.settings.paletteIdFor(Brightness.dark), 'frappe');
      await second.settings.setCoursePalette(Brightness.dark, null);

      final third = TestAppController(preferences: preferences);
      await third.initialize();
      expect(third.settings.paletteFor(Brightness.dark), isNull);
    },
  );

  test('Widget system course palette defaults off and persists independently of developer mode', () async {
    final preferences = MemoryPreferences();
    final first = TestAppController(preferences: preferences);
    await first.initialize();
    expect(first.settings.widgetUseSystemPalette, isFalse);
    await Future.wait([
      first.settings.setWidgetUseSystemPalette(true),
      first.settings.setWidgetUseSystemPalette(false),
      first.settings.setWidgetUseSystemPalette(true),
      first.settings.setCoursePalette(Brightness.dark, 'mocha'),
    ]);

    final second = TestAppController(preferences: preferences);
    await second.initialize();
    expect(second.settings.widgetUseSystemPalette, isTrue);
    expect(second.settings.paletteIdFor(Brightness.dark), 'mocha');
    expect(second.settings.developerMode, isFalse);
    await second.settings.setCoursePalette(Brightness.dark, null);
    expect(second.settings.widgetUseSystemPalette, isTrue);
    await second.settings.setWidgetUseSystemPalette(false);

    final third = TestAppController(preferences: preferences);
    await third.initialize();
    expect(third.settings.widgetUseSystemPalette, isFalse);
    expect(third.settings.paletteFor(Brightness.dark), isNull);
  });

  test('Unknown saved palette falls back to the current app colours', () async {
    final preferences = MemoryPreferences();
    await preferences.setString('darkCoursePalette', 'retired-palette');
    final controller = TestAppController(preferences: preferences);
    await controller.initialize();
    expect(controller.settings.paletteFor(Brightness.dark), isNull);
    expect(controller.settings.developerMode, isFalse);
  });

  testWidgets(
    'Five consecutive About icon taps keep developer mode without revealing options',
    (tester) async {
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
      await controller.initialize();
      await controller.settings.setLanguage(AppLanguage.chinese);
      await controller.settings.setTheme(ThemeMode.dark);
      await tester.pumpWidget(
        BitreeApp(
          controller: controller,
          updateChecker: (context, {silent = false}) async {},
        ),
      );
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
      await tester.ensureVisible(find.text('关于 BITree'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('关于 BITree'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      final icon = find.byKey(const ValueKey('about-icon'));
      for (var i = 0; i < 4; i++) {
        await tester.tap(icon);
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(controller.settings.developerMode, isFalse);
      // A pause starts a fresh sequence.
      await tester.pump(const Duration(seconds: 3));
      for (var i = 0; i < 4; i++) {
        await tester.tap(icon);
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(controller.settings.developerMode, isFalse);
      await tester.tap(icon);
      await tester.pumpAndSettle();
      expect(controller.settings.developerMode, isTrue);
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
