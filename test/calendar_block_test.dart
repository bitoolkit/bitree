import 'dart:math' as math;

import 'package:bitree/agenda/calendar.dart';
import 'package:bitree/agenda/deadline_source.dart';
import 'package:bitree/agenda/model.dart';
import 'package:bitree/agenda/ui/calendar_block.dart';
import 'package:bitree/agenda/ui/timeline_colors.dart';
import 'package:bitree/schedule/building_palette.dart';
import 'package:bitree/ui/course_palette.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/course_palettes.dart';
import 'support/system_palette.dart';
import 'support/test_app.dart';

double _contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  final lighter = math.max(first, second);
  final darker = math.min(first, second);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  final palettes = testPalettes();
  test('Agenda colours mix Base with Lavender and share Text', () {
    for (final (id, base, text, accent) in [
      ('mocha', 0xFF1E1E2E, 0xFFCDD6F4, 0xFFB4BEFE),
      ('macchiato', 0xFF24273A, 0xFFCAD3F5, 0xFFB7BDF8),
      ('frappe', 0xFF303446, 0xFFC6D0F5, 0xFFBABBF1),
    ]) {
      expect(palettes[id]!.agendaColors, (
        fill: Color.lerp(Color(base), Color(accent), 0.24)!.toARGB32(),
        text: text,
        accent: accent,
      ));
    }
  });

  for (final brightness in Brightness.values) {
    for (final system in [false, true]) {
      for (final palette in <CoursePalette?>[
        null,
        ...palettes.values,
        lightTestPalette(),
      ]) {
        testWidgets(
          'Home and timeline event blocks stay visible with ${palette?.name ?? 'default'}, system=$system, $brightness',
          (tester) async {
            final systemPalette = system ? testSystemPalette() : null;
            final theme = bitreeTheme(
              brightness,
              coursePalette: palette,
              systemPalette: systemPalette,
            );
            final original = bitreeTheme(
              brightness,
              systemPalette: systemPalette,
            );
            expect(theme.colorScheme, original.colorScheme);
            expect(
              theme.scaffoldBackgroundColor,
              original.scaffoldBackgroundColor,
            );
            expect(theme.textTheme, original.textTheme);
            final paletteColors = palette?.agendaColors;
            final cat = brightness == palette?.brightness && !system
                ? paletteColors
                : null;
            final scheme = theme.colorScheme;
            final controller = TestAppController();
            final startsAt = DateTime.utc(2026, 11, 17, 10);
            final event = AgendaEntry(
              id: 'manual',
              title: '手动日程',
              kind: AgendaKind.event,
              startsAt: startsAt,
              endsAt: startsAt.add(const Duration(hours: 1)),
            );
            final exam = AgendaEntry(
              id: 'exam',
              title: '期末考试',
              kind: AgendaKind.exam,
              startsAt: startsAt.add(const Duration(hours: 2)),
              endsAt: startsAt.add(const Duration(hours: 3)),
            );

            Future<void> show(AgendaEntry entry) async {
              await tester.pumpWidget(
                MaterialApp(
                  theme: theme,
                  home: Scaffold(
                    body: Center(
                      child: SizedBox(
                        width: 120,
                        height: 120,
                        child: CalendarBlockTile(
                          items: [CalendarItem.agenda(entry)],
                          controller: controller,
                          isToday: false,
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
            }

            Material block() => tester.widget<Material>(
              find
                  .descendant(
                    of: find.byType(CalendarBlockTile),
                    matching: find.byType(Material),
                  )
                  .first,
            );
            BorderSide side() =>
                (block().shape! as RoundedRectangleBorder).side;

            await show(event);
            final material = block();
            final title = tester.widget<Text>(find.text(event.title));
            final fill = cat == null
                ? scheme.primaryContainer
                : Color(cat.fill);
            final text = cat == null
                ? scheme.onPrimaryContainer
                : Color(cat.text);
            final accent = cat == null ? scheme.primary : Color(cat.accent);
            expect(material.color, fill);
            expect(title.style!.color, text);
            expect(side().color, accent);
            final context = tester.element(find.byType(CalendarBlockTile));
            final timeline = agendaTimelineColors(context, event, startsAt);
            expect(timeline, (fill: fill, text: text, accent: accent));
            if (cat != null) {
              final finished = agendaTimelineColors(
                context,
                event,
                startsAt.add(const Duration(hours: 2)),
              );
              expect(finished.fill, fill.withValues(alpha: 0.55));
              final deadline = AgendaEntry(
                id: 'manual-ddl',
                title: '自建 DDL',
                kind: AgendaKind.deadline,
                startsAt: startsAt,
              );
              expect(
                agendaTimelineColors(context, deadline, startsAt),
                timeline,
              );
              expect(
                agendaTimelineColors(
                  context,
                  deadline.copyWith(done: true),
                  startsAt,
                ),
                (
                  fill: fill.withValues(alpha: 0.5),
                  text: text.withValues(alpha: 0.5),
                  accent: accent.withValues(alpha: 0.5),
                ),
              );
            }
            for (final (source, building) in [
              (DeadlineSource.lexue, '工程训练中心'),
              (DeadlineSource.eclass, '文化体育中心'),
            ]) {
              final sourcePalette = buildingPaletteNamed(building)!;
              final values = brightness == Brightness.dark
                  ? sourcePalette.dark
                  : sourcePalette.light;
              final deadline = AgendaEntry(
                id: source.name,
                title: '平台作业',
                kind: AgendaKind.deadline,
                startsAt: startsAt,
                source: source,
              );
              expect(agendaTimelineColors(context, deadline, startsAt), (
                fill: Color(values.fill),
                text: Color(values.text),
                accent: Color(values.accent),
              ));
            }
            expect(side().width, 1);
            // The fill is deliberately subtle in light mode; the outline and text
            // must carry visibility under both the app and system palettes.
            expect(_contrast(side().color, material.color!), greaterThan(3));
            expect(_contrast(side().color, scheme.surface), greaterThan(3));
            expect(
              _contrast(title.style!.color!, material.color!),
              greaterThan(4.5),
            );

            await show(exam);
            final examMaterial = block();
            final examTitle = tester.widget<Text>(find.text(exam.title));
            expect(examMaterial.color, scheme.errorContainer);
            expect(examTitle.style!.color, scheme.onErrorContainer);
            expect(side().color, scheme.error);
            expect(
              _contrast(side().color, examMaterial.color!),
              greaterThan(3),
            );
            expect(
              _contrast(examTitle.style!.color!, examMaterial.color!),
              greaterThan(4.5),
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
