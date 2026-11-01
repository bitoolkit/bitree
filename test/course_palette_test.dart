import 'dart:convert';

import 'package:bitree/app/ui/palette_settings.dart';
import 'package:bitree/ui/course_palette.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/course_palettes.dart';
import 'support/test_app.dart';

class _FailingPalettePreferences extends MemoryPreferences {
  _FailingPalettePreferences(this.shouldFail);

  final bool Function() shouldFail;

  @override
  Future<void> setString(String key, String value) async {
    if (shouldFail() && key == 'coursePalettes') {
      throw StateError('Storage unavailable');
    }
    await super.setString(key, value);
  }
}

void main() {
  final builtins = testPalettes();
  final mocha = builtins['mocha']!;

  test('Flat JSON round-trips every opaque colour and brightness', () {
    for (final palette in [...builtins.values, lightTestPalette()]) {
      final restored = CoursePalette.parse(jsonEncode(palette.toJson()));
      expect(restored.name, palette.name);
      expect(restored.brightness, palette.brightness);
      expect(restored.toJson(), palette.toJson());
      expect(restored.widgetColors, palette.widgetColors);
      expect(restored.agendaColors, palette.agendaColors);
    }
    expect(mocha.colorsFor(null).accent, 0xFFBAC2DE);
    expect(mocha.agendaColors.accent, 0xFFB4BEFE);
  });

  test(
    'Missing fields, invalid types, alpha and malformed JSON are rejected',
    () {
      for (final key in ['name', 'brightness', ...CoursePalette.colorKeys]) {
        final missing = {...mocha.toJson()}..remove(key);
        expect(
          () => CoursePalette.fromJson(missing),
          throwsFormatException,
          reason: 'missing $key',
        );
        expect(
          () => CoursePalette.fromJson({...mocha.toJson(), key: 42}),
          throwsFormatException,
          reason: 'non-string $key',
        );
      }
      for (final name in ['', '  ']) {
        expect(
          () => CoursePalette.fromJson({...mocha.toJson(), 'name': name}),
          throwsFormatException,
        );
      }
      for (final value in ['system', 'Dark', '', null]) {
        expect(
          () =>
              CoursePalette.fromJson({...mocha.toJson(), 'brightness': value}),
          throwsFormatException,
        );
      }
      for (final value in [
        '#AA112233',
        '#123',
        '112233',
        '#GG2233',
        '#123456\n',
      ]) {
        expect(
          () => CoursePalette.fromJson({...mocha.toJson(), 'agenda': value}),
          throwsFormatException,
        );
      }
      for (final source in ['{', '[]', 'null', '"palette"']) {
        expect(() => CoursePalette.parse(source), throwsFormatException);
      }
    },
  );

  testWidgets('Bundled Cat JSON loads through the production asset bundle', (
    tester,
  ) async {
    final loaded = await CoursePalette.loadBuiltins();
    expect(loaded.keys, builtins.keys);
    for (final id in loaded.keys) {
      expect(loaded[id]!.toJson(), builtins[id]!.toJson());
    }
  });

  test(
    'Imports persist their contents and select light and dark independently',
    () async {
      final preferences = MemoryPreferences();
      final first = TestAppController(preferences: preferences);
      await first.initialize();
      await first.setCoursePalette(Brightness.dark, 'mocha');
      await first.importCoursePalette(jsonEncode(lightTestPalette().toJson()));
      final lightId = first.paletteIdFor(Brightness.light)!;
      expect(first.paletteIdFor(Brightness.dark), 'mocha');
      expect(first.themeMode, ThemeMode.system);
      expect(first.palettesFor(Brightness.light).keys, [lightId]);
      expect(first.palettesFor(Brightness.dark).keys, builtins.keys);

      await first.importCoursePalette(
        jsonEncode({...mocha.toJson(), 'name': '自定义深色'}),
      );
      final darkId = first.paletteIdFor(Brightness.dark)!;
      final second = TestAppController(preferences: preferences);
      await second.initialize();
      expect(second.paletteIdFor(Brightness.light), lightId);
      expect(second.paletteIdFor(Brightness.dark), darkId);
      expect(
        second.paletteFor(Brightness.light)!.toJson(),
        lightTestPalette().toJson(),
      );
      expect(second.paletteFor(Brightness.dark)!.name, '自定义深色');
      expect(second.customPalettes, hasLength(2));
      expect(second.globalUseSystemPalette, isFalse);
      expect(second.widgetUseSystemPalette, isFalse);
    },
  );

  test(
    'Invalid imports and failed saves preserve the current selection and catalog',
    () async {
      var fail = false;
      final preferences = _FailingPalettePreferences(() => fail);
      final controller = TestAppController(preferences: preferences);
      await controller.setCoursePalette(Brightness.dark, 'mocha');
      final saved = await preferences.getString('coursePalettes');
      await expectLater(
        controller.importCoursePalette('{"name":"broken"}'),
        throwsFormatException,
      );
      fail = true;
      await expectLater(
        controller.importCoursePalette(jsonEncode(lightTestPalette().toJson())),
        throwsStateError,
      );
      expect(controller.paletteIdFor(Brightness.dark), 'mocha');
      expect(controller.paletteFor(Brightness.light), isNull);
      expect(controller.customPalettes, isEmpty);
      expect(await preferences.getString('coursePalettes'), saved);
      fail = false;
      // A failed import must not poison subsequent writes.
      await controller.importCoursePalette(
        jsonEncode(lightTestPalette().toJson()),
      );
      expect(controller.customPalettes, hasLength(1));
    },
  );

  test(
    'Deletion restores only the selected mode and persists removal',
    () async {
      final preferences = MemoryPreferences();
      final first = TestAppController(preferences: preferences);
      await Future.wait([
        first.importCoursePalette(jsonEncode(lightTestPalette().toJson())),
        first.importCoursePalette(jsonEncode(mocha.toJson())),
      ]);
      final lightId = first.paletteIdFor(Brightness.light)!;
      final darkId = first.paletteIdFor(Brightness.dark)!;
      await first.deleteCoursePalette(lightId);
      expect(first.paletteFor(Brightness.light), isNull);
      expect(first.paletteIdFor(Brightness.dark), darkId);
      await first.setCoursePalette(Brightness.dark, 'frappe');
      await first.deleteCoursePalette(darkId);
      expect(first.paletteIdFor(Brightness.dark), 'frappe');
      await first.deleteCoursePalette('frappe');
      expect(first.palettesFor(Brightness.dark).keys, builtins.keys);

      final second = TestAppController(preferences: preferences);
      await second.initialize();
      expect(second.customPalettes, isEmpty);
      expect(second.paletteFor(Brightness.light), isNull);
      expect(second.paletteIdFor(Brightness.dark), 'frappe');
    },
  );

  test(
    'Legacy Cat selections migrate and brightness mismatches are rejected',
    () async {
      for (final id in CoursePalette.builtinIds) {
        final preferences = MemoryPreferences();
        await preferences.setString('darkCoursePalette', id);
        final controller = TestAppController(preferences: preferences);
        await controller.initialize();
        expect(controller.paletteIdFor(Brightness.dark), id);
        expect(controller.paletteFor(Brightness.light), isNull);
        await expectLater(
          controller.setCoursePalette(Brightness.light, id),
          throwsFormatException,
        );
        expect(controller.paletteIdFor(Brightness.dark), id);
        await controller.setCoursePalette(Brightness.dark, null);
        final restarted = TestAppController(preferences: preferences);
        await restarted.initialize();
        expect(restarted.paletteFor(Brightness.dark), isNull);
      }
    },
  );

  testWidgets(
    'Only imported palettes have delete buttons and deletion updates the menu',
    (tester) async {
      final controller = TestAppController();
      await controller.importCoursePalette(
        jsonEncode(lightTestPalette().toJson()),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: bitreeTheme(Brightness.light),
          home: Scaffold(
            body: ListenableBuilder(
              listenable: controller,
              builder: (context, _) =>
                  ListView(children: [PaletteSettings(controller: controller)]),
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
      expect(find.byTooltip('删除 Mocha'), findsNothing);
      await tester.tap(find.byTooltip('删除 自定义浅色'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
      expect(controller.paletteFor(Brightness.light), isNull);
      expect(find.text('默认'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );
}
