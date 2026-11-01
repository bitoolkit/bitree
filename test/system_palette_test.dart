import 'dart:async';
import 'dart:convert';

import 'package:bitree/agenda/deadline_source.dart';
import 'package:bitree/agenda/model.dart';
import 'package:bitree/agenda/ui/timeline_colors.dart';
import 'package:bitree/app/ui/settings_screen.dart';
import 'package:bitree/main.dart';
import 'package:bitree/schedule/building_palette.dart';
import 'package:bitree/schedule/model.dart';
import 'package:bitree/ui/course_palette.dart';
import 'package:bitree/ui/system_palette.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/course_palettes.dart';
import 'support/system_palette.dart';
import 'support/test_app.dart';

void main() {
  test(
    'Platform palettes accept signed Android colours and reject incomplete data',
    () {
      final values = systemPaletteValues();
      final palette = SystemPalette.fromPlatform(values)!;
      expect(
        palette.colorScheme(Brightness.light).primary,
        Color(values['accent1']![8]),
      );
      expect(
        palette.colorScheme(Brightness.dark).primary,
        Color(values['accent1']![4]),
      );
      expect(SystemPalette.fromPlatform(null), isNull);
      expect(
        SystemPalette.fromPlatform({...values}..remove('neutral2')),
        isNull,
      );
      expect(
        SystemPalette.fromPlatform({
          ...values,
          'accent1': [1, 2],
        }),
        isNull,
      );
      expect(
        SystemPalette.fromPlatform({
          ...values,
          'accent1': List.filled(13, 'invalid'),
        }),
        isNull,
      );
    },
  );

  test(
    'Global palette defaults off and persists independently of other appearance choices',
    () async {
      final preferences = MemoryPreferences();
      final source = MemorySystemPaletteSource(palette: testSystemPalette());
      final first = TestAppController(
        preferences: preferences,
        systemPaletteSource: source,
      );
      await first.initialize();
      expect(first.globalUseSystemPalette, isFalse);
      expect(first.systemPalette, isNull);
      expect(source.reads, 0);
      await first.setCoursePalette(Brightness.dark, 'mocha');
      await Future.wait([
        first.setGlobalUseSystemPalette(true),
        first.setGlobalUseSystemPalette(false),
        first.setGlobalUseSystemPalette(true),
      ]);
      expect(first.systemPalette, same(source.palette));
      expect(first.widgetUseSystemPalette, isFalse);

      final second = TestAppController(
        preferences: preferences,
        systemPaletteSource: MemorySystemPaletteSource(palette: source.palette),
      );
      await second.initialize();
      expect(second.globalUseSystemPalette, isTrue);
      expect(second.systemPalette, same(source.palette));
      expect(second.paletteIdFor(Brightness.dark), 'mocha');
      expect(second.developerMode, isFalse);
      expect(second.widgetUseSystemPalette, isFalse);
      await second.setGlobalUseSystemPalette(false);
      expect(second.systemPalette, isNull);
      expect(second.paletteIdFor(Brightness.dark), 'mocha');

      final third = TestAppController(preferences: preferences);
      await third.initialize();
      expect(third.globalUseSystemPalette, isFalse);
    },
  );

  test(
    'Late platform reads cannot replace a newer palette or reactivate a disabled palette',
    () async {
      final requests = <Completer<SystemPalette?>>[];
      final source = MemorySystemPaletteSource(
        loader: () {
          final request = Completer<SystemPalette?>();
          requests.add(request);
          return request.future;
        },
      );
      final controller = TestAppController(systemPaletteSource: source);
      await controller.initialize();
      final first = controller.setGlobalUseSystemPalette(true);
      await controller.setGlobalUseSystemPalette(false);
      final second = controller.setGlobalUseSystemPalette(true);
      final latest = testSystemPalette(hue: 250);
      requests[1].complete(latest);
      await second;
      requests[0].complete(testSystemPalette());
      await first;
      expect(controller.systemPalette, same(latest));
      final pending = controller.setGlobalUseSystemPalette(true);
      await controller.setGlobalUseSystemPalette(false);
      requests.last.complete(testSystemPalette());
      await pending;
      expect(controller.systemPalette, isNull);
    },
  );

  test(
    'System changes refresh colours only while enabled; unsupported systems use the app theme',
    () async {
      final source = MemorySystemPaletteSource();
      final controller = TestAppController(systemPaletteSource: source);
      await controller.initialize();
      await controller.setGlobalUseSystemPalette(true);
      expect(controller.globalUseSystemPalette, isTrue);
      expect(controller.systemPalette, isNull);
      final changed = Completer<void>();
      controller.addListener(() {
        if (controller.systemPalette != null && !changed.isCompleted) {
          changed.complete();
        }
      });
      source.palette = testSystemPalette();
      source.onChanged!();
      await changed.future;
      expect(controller.systemPalette, same(source.palette));
      await controller.setGlobalUseSystemPalette(false);
      final reads = source.reads;
      source.onChanged!();
      expect(source.reads, reads);
    },
  );

  test('A failed palette refresh keeps the last working theme', () async {
    final source = MemorySystemPaletteSource(palette: testSystemPalette());
    final controller = TestAppController(systemPaletteSource: source);
    await controller.initialize();
    await controller.setGlobalUseSystemPalette(true);
    final last = controller.systemPalette;
    source.loader = () async => throw StateError('Platform unavailable');
    await controller.setGlobalUseSystemPalette(true);
    expect(controller.systemPalette, same(last));
    await controller.setGlobalUseSystemPalette(false);
    expect(controller.systemPalette, isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'Global palette updates the app and courses, preserves agenda source colours and restores $brightness colours',
      (tester) async {
        final palette = testSystemPalette();
        final controller = TestAppController(
          systemPaletteSource: MemorySystemPaletteSource(palette: palette),
        );
        await controller.setTheme(
          brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
        );
        await controller.setCoursePalette(Brightness.dark, 'mocha');
        await controller.importCoursePalette(
          jsonEncode(lightTestPalette().toJson()),
        );
        await tester.pumpWidget(BitreeApp(controller: controller));
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('设置'),
          ),
        );
        await tester.pumpAndSettle();
        BuildContext context() => tester.element(find.byType(SettingsScreen));
        final course = Course(
          id: 'course',
          name: '测试课程',
          weekday: 1,
          startSection: 1,
          endSection: 2,
          weeks: const [1],
          room: '文萃F704',
        );
        final now = DateTime.utc(2026, 11, 17, 12);
        final entries = [
          AgendaEntry(
            id: 'exam',
            title: '考试',
            kind: AgendaKind.exam,
            startsAt: now.add(const Duration(hours: 1)),
            endsAt: now.add(const Duration(hours: 2)),
          ),
          AgendaEntry(
            id: 'ddl',
            title: '作业',
            kind: AgendaKind.deadline,
            startsAt: now.add(const Duration(days: 1)),
            source: DeadlineSource.lexue,
          ),
          AgendaEntry(
            id: 'eclass',
            title: 'eClass 作业',
            kind: AgendaKind.deadline,
            startsAt: now.add(const Duration(days: 1)),
            source: DeadlineSource.eclass,
          ),
        ];
        final originalTheme = Theme.of(context());
        final originalCourse = courseColors(context(), course);
        final originalAgenda = [
          for (final entry in entries)
            agendaTimelineColors(context(), entry, now),
        ];
        await controller.setGlobalUseSystemPalette(true);
        await tester.pumpAndSettle();
        final theme = Theme.of(context());
        expect(theme.colorScheme, palette.colorScheme(brightness));
        expect(theme.scaffoldBackgroundColor, theme.colorScheme.surface);
        expect(
          theme.scaffoldBackgroundColor,
          isNot(originalTheme.scaffoldBackgroundColor),
        );
        expect(
          theme.extension<CoursePaletteTheme>()!.palette,
          controller.paletteFor(brightness),
        );
        final colors = courseColors(context(), course);
        expect(
          colors.fill,
          palette.courseColors(CampusArea.wencui, brightness).fill,
        );
        expect(colors.fill, isNot(originalCourse.fill));
        for (var i = 0; i < entries.length; i++) {
          expect(
            agendaTimelineColors(context(), entries[i], now),
            originalAgenda[i],
          );
        }
        final overdue = entries.last.copyWith();
        expect(
          agendaTimelineColors(
            context(),
            overdue,
            now.add(const Duration(days: 2)),
          ),
          originalAgenda.last,
        );
        expect(
          agendaTimelineColors(
            context(),
            overdue.copyWith(done: true),
            now,
          ).fill.a,
          0.5,
        );
        expect(controller.widgetUseSystemPalette, isFalse);
        await controller.setGlobalUseSystemPalette(false);
        await tester.pumpAndSettle();
        expect(Theme.of(context()).colorScheme, originalTheme.colorScheme);
        expect(courseColors(context(), course), originalCourse);
        for (var i = 0; i < entries.length; i++) {
          expect(
            agendaTimelineColors(context(), entries[i], now),
            originalAgenda[i],
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }
}
