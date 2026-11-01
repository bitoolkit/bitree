import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:bitree/schedule/building_palette.dart';
import 'package:bitree/schedule/model.dart';
import 'package:bitree/ui/course_palette.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/course_palettes.dart';

void main() {
  test('Building aliases, wing codes, room numbers and full-width text', () {
    const rooms = {
      '文萃楼F704': '文萃楼F',
      '良乡校区 文 萃 楼 ｆ－７０４': '文萃楼F',
      '文\u3000萃\u00A0楼\u3000Ｆ７０４': '文萃楼F',
      '文萃F楼704': '文萃楼F',
      '文萃F栋7层704教室': '文萃楼F',
      '文萃楼F704、文萃F705': '文萃楼F',
      '文萃楼J909/J916': '文萃楼J',
      '文萃楼': '文萃楼',
      '综教A204': '综合教学楼A',
      '综合教学大楼A座204': '综合教学楼A',
      '综教2A-106': '综合教学楼A',
      '综教 B-203': '综合教学楼B',
      '综合教学楼报告厅': '综合教学楼',
      '理教楼105': '理科教学楼',
      '理科教学大楼1-202': '理科教学楼',
      '理学楼A315': '理学楼',
      '物理实验309-310': '物理实验中心',
      '化学实验楼102': '化学实验中心',
      '信创A楼八层': '信创楼A',
    };
    for (final entry in rooms.entries) {
      expect(
        matchCampusBuilding(entry.key)?.name,
        entry.value,
        reason: entry.key,
      );
    }
  });

  test(
    'Unknown, ambiguous and other-campus locations do not imply a building',
    () {
      for (final room in [
        '',
        '线上',
        '待定',
        '中心教学楼101',
        '实验室203',
        '文萃楼F704/文萃楼G701',
      ]) {
        expect(matchCampusBuilding(room), isNull, reason: room);
      }
      expect(matchCampusBuilding('文萃楼FA704')?.name, '文萃楼');
      expect(matchCampusBuilding('中关村理教105'), isNull);
      expect(matchCampusBuilding('理教105', campus: '中关村校区'), isNull);
      expect(matchCampusBuilding('理教105', campus: '良乡校区')?.name, '理科教学楼');
    },
  );

  final table =
      jsonDecode(
            File(
              'android/app/src/main/assets/building_palette.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final buildings = (table['buildings'] as List).cast<Map<String, dynamic>>();

  test('Android and Flutter share every alias and both theme palettes', () {
    for (final row in buildings) {
      for (final alias in (row['aliases'] as List).cast<String>()) {
        final palette = matchCampusBuilding('$alias 101')!;
        expect(palette.name, row['name'], reason: alias);
        expect(palette.area?.name, row['area']);
        expect([
          palette.light.fill,
          palette.light.text,
          palette.light.accent,
        ], row['light']);
        expect([
          palette.dark.fill,
          palette.dark.text,
          palette.dark.accent,
        ], row['dark']);
      }
    }
    expect([
      unknownBuildingPalette.light.fill,
      unknownBuildingPalette.light.text,
      unknownBuildingPalette.light.accent,
    ], (table['neutral'] as Map)['light']);
    expect([
      unknownBuildingPalette.dark.fill,
      unknownBuildingPalette.dark.text,
      unknownBuildingPalette.dark.accent,
    ], (table['neutral'] as Map)['dark']);
  });

  test(
    'Neighbouring buildings are closer in colour than distant teaching areas',
    () {
      for (final dark in [false, true]) {
        int fill(String room) {
          final palette = matchCampusBuilding(room)!;
          return (dark ? palette.dark : palette.light).fill;
        }

        final f = fill('文萃F704');
        final physics = fill('物理实验楼309');
        final northWest = fill('综教A204');
        expect(_distance(f, fill('文萃G701')), lessThan(_distance(f, northWest)));
        expect(
          _distance(physics, fill('理教105')),
          lessThan(_distance(physics, f)),
        );
        final wenCui = buildings.where(
          (row) => (row['name'] as String).startsWith('文萃'),
        );
        for (final row in wenCui) {
          expect(
            _distance(f, fill(row['name'] as String)),
            lessThan(_distance(f, physics)),
          );
        }
      }
    },
  );

  test('Course titles and secondary room labels retain readable contrast', () {
    for (final row in [
      ...buildings,
      table['neutral'] as Map<String, dynamic>,
    ]) {
      for (final mode in ['light', 'dark']) {
        final values = (row[mode] as List).cast<int>();
        final background = Color(values[0]);
        final foreground = Color(values[1]);
        final secondary = Color.alphaBlend(
          foreground.withValues(alpha: 0.8),
          background,
        );
        for (final text in [foreground, secondary]) {
          final a = text.computeLuminance();
          final b = background.computeLuminance();
          expect(
            (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05),
            greaterThanOrEqualTo(4.5),
            reason: '${row['name']} $mode',
          );
        }
      }
    }
  });

  test('Teaching areas have recognizable colour families', () {
    final north = matchCampusBuilding('综教B103')!;
    final east = matchCampusBuilding('文萃F704')!;
    final south = matchCampusBuilding('理教楼105')!;
    expect(north.area, CampusArea.northTeaching);
    expect(east.area, CampusArea.wencui);
    expect(south.area, CampusArea.southScience);
    expect(matchCampusBuilding('文萃J501')!.area, east.area);
    expect(matchCampusBuilding('物理实验306')!.area, south.area);
    for (final (a, b) in [(north, east), (east, south), (south, north)]) {
      expect(_distance(a.light.fill, b.light.fill), greaterThan(0.075));
      expect(_distance(a.dark.fill, b.dark.fill), greaterThan(0.05));
    }
  });

  testWidgets(
    'Optional palettes preserve surfaces and export matching opaque widget course colours',
    (tester) async {
      for (final palette in <CoursePalette?>[
        null,
        ...testPalettes().values,
        lightTestPalette(),
      ]) {
        final paletteName = palette?.name;
        final widgetColors = palette?.widgetColors ?? <String, List<int>>{};
        if (palette == null) {
          expect(widgetColors, isEmpty);
        } else {
          expect(
            widgetColors.keys,
            unorderedEquals([
              ...CampusArea.values.map((area) => area.name),
              'neutral',
              'surface',
            ]),
          );
          expect(widgetColors['surface']!.first, switch (palette.name) {
            'Mocha' => 0xFF1E1E2E,
            'Macchiato' => 0xFF24273A,
            'Frappé' => 0xFF303446,
            _ => 0xFFF8F8F8,
          });
        }
        for (final brightness in Brightness.values) {
          final originalTheme = bitreeTheme(brightness);
          final theme = bitreeTheme(brightness, coursePalette: palette);
          expect(theme.colorScheme, originalTheme.colorScheme);
          expect(
            theme.scaffoldBackgroundColor,
            originalTheme.scaffoldBackgroundColor,
          );
          await tester.pumpWidget(
            MaterialApp(
              key: ValueKey((palette, brightness)),
              theme: theme,
              home: Builder(
                builder: (context) {
                  for (final building in [
                    ...buildings.map(
                      (row) => buildingPaletteNamed(row['name'] as String)!,
                    ),
                    unknownBuildingPalette,
                  ]) {
                    final course = Course(
                      id: 'course',
                      name: '测试课程',
                      weekday: 1,
                      startSection: 1,
                      endSection: 2,
                      weeks: [1],
                      room: building.name,
                    );
                    final colors = courseColors(context, course);
                    if (brightness == palette?.brightness) {
                      expect(
                        widgetColors[building.area?.name ?? 'neutral'],
                        [colors.fill.toARGB32(), colors.text.toARGB32()],
                        reason: '${building.name} uses the same widget colours',
                      );
                    }
                    if (brightness == Brightness.light &&
                        palette?.brightness != brightness) {
                      expect(colors.fill, Color(building.light.fill));
                      expect(colors.text, Color(building.light.text));
                      expect(colors.accent, Color(building.light.accent));
                    } else if (palette?.brightness != brightness) {
                      expect(
                        colors.fill,
                        Color.lerp(
                          Color(building.dark.fill),
                          Color(building.dark.accent),
                          0.24,
                        ),
                      );
                      expect(colors.text, Color(building.dark.text));
                      expect(colors.accent, Color(building.dark.accent));
                    } else {
                      expect(
                        colors.text,
                        Color(switch (paletteName) {
                          'Mocha' => 0xFFCDD6F4,
                          'Macchiato' => 0xFFCAD3F5,
                          'Frappé' => 0xFFC6D0F5,
                          _ => 0xFF242424,
                        }),
                      );
                      if (building.area == CampusArea.wencui) {
                        expect(
                          colors.accent,
                          Color(switch (paletteName) {
                            'Mocha' => 0xFFA6E3A1,
                            'Macchiato' => 0xFFA6DA95,
                            'Frappé' => 0xFFA6D189,
                            _ => 0xFF336633,
                          }),
                        );
                      }
                    }
                    for (final (foreground, background) in [
                      (colors.text, colors.fill),
                      (colors.secondaryText, colors.fill),
                      (colors.text, colors.elapsedFill),
                    ]) {
                      expect(foreground.a, 1);
                      expect(background.a, 1);
                    }
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          );
        }
      }
    },
  );

  testWidgets(
    'Course colours stay opaque and readable before and during class',
    (tester) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(brightness),
            theme: bitreeTheme(brightness),
            home: Builder(
              builder: (context) {
                for (final row in [
                  ...buildings,
                  {'name': '地点待定'},
                ]) {
                  final course = Course(
                    id: 'course',
                    name: '测试课程',
                    weekday: 1,
                    startSection: 1,
                    endSection: 2,
                    weeks: [1],
                    room: row['name'] as String,
                  );
                  final colors = courseColors(context, course);
                  for (final (foreground, background) in [
                    (colors.text, colors.fill),
                    (colors.secondaryText, colors.fill),
                    (colors.text, colors.elapsedFill),
                  ]) {
                    expect(foreground.a, 1);
                    expect(background.a, 1);
                    final a = foreground.computeLuminance();
                    final b = background.computeLuminance();
                    expect(
                      (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05),
                      greaterThanOrEqualTo(4.5),
                      reason: '${row['name']} $brightness',
                    );
                  }
                  if (brightness == Brightness.dark) {
                    final column = Theme.of(
                      context,
                    ).colorScheme.surfaceContainer;
                    expect(
                      (colors.fill.computeLuminance() + 0.05) /
                          (column.computeLuminance() + 0.05),
                      greaterThanOrEqualTo(1.5),
                      reason: '${row['name']} separates from today’s column',
                    );
                  }
                  expect(
                    colors.elapsedFill.computeLuminance(),
                    brightness == Brightness.light
                        ? lessThan(colors.fill.computeLuminance())
                        : greaterThan(colors.fill.computeLuminance()),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      }
    },
  );
}

double _distance(int first, int second) {
  final a = _oklab(first);
  final b = _oklab(second);
  return math.sqrt(
    List.generate(3, (i) => math.pow(a[i] - b[i], 2)).reduce((a, b) => a + b),
  );
}

List<double> _oklab(int value) {
  double linear(int channel) {
    final c = channel / 255;
    return c <= 0.04045
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = linear((value >> 16) & 255);
  final g = linear((value >> 8) & 255);
  final b = linear(value & 255);
  final l = math.pow(
    0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b,
    1 / 3,
  );
  final m = math.pow(
    0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b,
    1 / 3,
  );
  final s = math.pow(
    0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b,
    1 / 3,
  );
  return [
    0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
    1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
    0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
  ];
}
