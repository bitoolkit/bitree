import 'package:bitree/app/ui/appearance_screen.dart';
import 'package:bitree/app/ui/settings_screen.dart';
import 'package:bitree/main.dart';
import 'package:bitree/ui/app_menu_anchor.dart';
import 'package:bitree/ui/course_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  testWidgets(
    'Appearance subpage exposes all appearance choices without developer mode',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = TestAppController();
      await controller.loadCoursePalettes();
      await tester.pumpWidget(BitreeApp(controller: controller));
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('设置'),
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.developerMode, isFalse);
      expect(find.byType(SegmentedButton<ThemeMode>), findsNothing);
      expect(find.text('深色模式调色板'), findsNothing);
      await tester.tap(find.text('外观'));
      await tester.pumpAndSettle();
      expect(find.byType(AppearanceScreen), findsOneWidget);
      expect(find.text('浅色模式调色板'), findsOneWidget);
      expect(find.text('深色模式调色板'), findsOneWidget);
      expect(find.text('导入调色板'), findsOneWidget);
      expect(find.text('默认'), findsNWidgets(2));

      for (final (label, mode) in [
        ('浅色', ThemeMode.light),
        ('跟随系统', ThemeMode.system),
        ('深色', ThemeMode.dark),
      ]) {
        await tester.tap(
          find.descendant(
            of: find.byType(SegmentedButton<ThemeMode>),
            matching: find.text(label),
          ),
        );
        await tester.pumpAndSettle();
        expect(controller.themeMode, mode);
        expect(
          tester
              .widget<SegmentedButton<ThemeMode>>(
                find.byType(SegmentedButton<ThemeMode>),
              )
              .selected,
          {mode},
        );
      }

      final systemPaletteSwitch = find.widgetWithText(
        SwitchListTile,
        '小组件使用系统调色板',
      );
      await tester.ensureVisible(systemPaletteSwitch);
      expect(tester.widget<SwitchListTile>(systemPaletteSwitch).value, isFalse);
      await tester.tap(systemPaletteSwitch);
      await tester.pumpAndSettle();
      expect(controller.widgetUseSystemPalette, isTrue);
      expect(tester.widget<SwitchListTile>(systemPaletteSwitch).value, isTrue);
      final globalPaletteSwitch = find.widgetWithText(
        SwitchListTile,
        '全局系统调色板（实验性）',
      );
      await tester.ensureVisible(globalPaletteSwitch);
      expect(tester.widget<SwitchListTile>(globalPaletteSwitch).value, isFalse);
      await tester.tap(globalPaletteSwitch);
      await tester.pumpAndSettle();
      expect(controller.globalUseSystemPalette, isTrue);
      expect(controller.widgetUseSystemPalette, isTrue);
      expect(tester.widget<SwitchListTile>(globalPaletteSwitch).value, isTrue);
      // Missing platform colours keep the existing app appearance.
      expect(controller.systemPalette, isNull);
      await tester.ensureVisible(find.text('深色模式调色板'));
      await tester.tap(find.text('深色模式调色板'));
      await tester.pumpAndSettle();
      for (final label in ['默认', 'Mocha', 'Macchiato', 'Frappé']) {
        expect(find.widgetWithText(AppMenuItemButton, label), findsOneWidget);
      }
      await tester.tap(find.widgetWithText(AppMenuItemButton, 'Mocha'));
      await tester.pumpAndSettle();
      expect(find.text('Mocha'), findsOneWidget);
      expect(controller.paletteIdFor(Brightness.dark), 'mocha');
      expect(controller.widgetUseSystemPalette, isTrue);
      final theme = Theme.of(tester.element(find.byType(AppearanceScreen)));
      expect(
        theme.extension<CoursePaletteTheme>()!.palette,
        same(controller.paletteFor(Brightness.dark)),
      );
      expect(theme.colorScheme.surface, const Color(0xFF171717));
      expect(theme.colorScheme.surfaceContainer, const Color(0xFF282828));

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.byType(AppearanceScreen), findsNothing);
      expect(find.text('深色模式调色板'), findsNothing);
      expect(find.widgetWithText(ListTile, '深色'), findsOneWidget);
      await tester.tap(find.text('外观'));
      await tester.pumpAndSettle();
      expect(find.text('Mocha'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(systemPaletteSwitch).value, isTrue);
      expect(tester.widget<SwitchListTile>(globalPaletteSwitch).value, isTrue);
      expect(controller.developerMode, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
