import 'dart:convert';
import 'dart:io';

import 'package:bitree/agenda/model.dart';
import 'package:bitree/agenda/ui/calendar_block.dart';
import 'package:bitree/app/ui/add_menu.dart';
import 'package:bitree/schedule/model.dart';
import 'package:bitree/schedule/section_times.dart';
import 'package:bitree/schedule/timetable_axis.dart';
import 'package:bitree/schedule/ui/current_time_indicator.dart';
import 'package:bitree/schedule/ui/home_screen.dart';
import 'package:bitree/schedule/ui/timetable.dart';
import 'package:bitree/schedule/ui/timetable_grid.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

final _monday = DateTime.utc(2026, 10, 26);
final _schedule = SemesterSchedule(
  term: '2026-2027-1',
  firstMonday: _monday,
  courses: [
    Course(
      id: 'morning',
      name: '高等数学',
      room: '综教A201',
      weekday: 1,
      startSection: 1,
      endSection: 2,
      weeks: [1],
    ),
    Course(
      id: 'evening',
      name: '工程训练',
      room: '工程训练中心',
      weekday: 2,
      startSection: 11,
      endSection: 13,
      weeks: [1],
    ),
  ],
);

AgendaEntry _event(String id, int start, int end) => AgendaEntry(
  id: id,
  title: id,
  kind: AgendaKind.event,
  startsAt: _monday.add(Duration(minutes: start)),
  endsAt: _monday.add(Duration(minutes: end)),
);

ScrollPosition _position(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(Timetable),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

Future<TestAppController> _showHome(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double scale = 1,
  List<AgendaEntry> entries = const [],
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final controller = TestAppController(
    schedule: _schedule,
    initialWeek: 1,
    entries: entries,
  );
  await controller.initialize();
  final theme = bitreeTheme(Brightness.light);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: HomeScreen(controller: controller, now: _monday, active: false),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  setUpAll(() async {
    final config = jsonDecode(
      await File('.dart_tool/package_config.json').readAsString(),
    ) as Map;
    final flutter = (config['packages'] as List).cast<Map>().firstWhere(
      (package) => package['name'] == 'flutter',
    );
    final root = File('.dart_tool/package_config.json').absolute.uri
        .resolve('${flutter['rootUri']}/');
    final font = File.fromUri(
      root.resolve(
        '../../bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
      ),
    );
    await (FontLoader(
      'Roboto',
    )..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
  });

  for (final (size, scale) in [
    (const Size(320, 640), 1.0),
    (const Size(390, 844), 1.0),
    (const Size(390, 640), 1.8),
    (const Size(1200, 800), 1.0),
  ]) {
    testWidgets('The eye button expands a non-scrolling day at $size, $scale', (
      tester,
    ) async {
      await _showHome(tester, size: size, scale: scale);
      expect(find.text('口'), findsOneWidget);
      expect(find.text('目'), findsNothing);
      expect(
        tester.getCenter(find.text('口')).dx,
        lessThan(tester.getCenter(find.byTooltip('添加')).dx),
      );
      await tester.tap(find.byTooltip('展开早晚时段'));
      await tester.pumpAndSettle();
      expect(find.text('目'), findsOneWidget);
      expect(find.text('口'), findsNothing);
      final grid = tester.widget<TimetableGrid>(
        find.byType(TimetableGrid).first,
      );
      expect(grid.axis.expanded, isTrue);
      expect(_position(tester).pixels, 0);
      expect(_position(tester).maxScrollExtent, closeTo(0, 1e-7));
      expect(
        grid.rowHeight * grid.axis.length,
        closeTo(_position(tester).viewportDimension, 1e-7),
      );
      for (final hour in [
        for (var hour = 0; hour <= 9; hour++) hour,
        21,
        22,
        23,
        24,
      ]) {
        expect(
          find.text('${hour.toString().padLeft(2, '0')}:00'),
          findsOneWidget,
        );
      }
      final gridRect = tester.getRect(find.byType(TimetableGrid).first);
      for (final (text, minute) in [
        for (var hour = 1; hour <= 9; hour++)
          ('${hour.toString().padLeft(2, '0')}:00', hour * 60.0),
        for (final period in sectionTimes)
          (period.$1, TimetableAxis.clockMinute(period.$1).toDouble()),
        for (var hour = 21; hour < 24; hour++) ('$hour:00', hour * 60.0),
      ]) {
        expect(
          tester.getCenter(find.text(text)).dy - gridRect.top,
          closeTo(grid.axis.offsetForMinute(minute) * grid.rowHeight, 0.001),
          reason: '$text stays on its actual time coordinate',
        );
      }
      expect(
        tester.getRect(find.text('00:00')).top,
        greaterThanOrEqualTo(gridRect.top),
      );
      expect(
        tester.getRect(find.text('24:00')).bottom,
        lessThanOrEqualTo(gridRect.bottom),
      );
      expect(
        tester.getRect(find.text('09:00')).bottom,
        lessThanOrEqualTo(tester.getRect(find.text('2')).top + 0.001),
        reason: 'The new 09:00 tick does not collide with the second period',
      );
      final labels = [
        for (var hour = 0; hour <= 9; hour++)
          tester.getRect(find.text('${hour.toString().padLeft(2, '0')}:00')),
      ];
      for (var index = 1; index < labels.length; index++) {
        expect(
          labels[index].top,
          greaterThanOrEqualTo(labels[index - 1].bottom - 0.001),
        );
      }
      await tester.drag(
        find.byType(TimetableGrid).first,
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      expect(_position(tester).pixels, 0);
      await tester.tap(find.byTooltip('收起早晚时段'));
      await tester.pumpAndSettle();
      expect(find.text('口'), findsOneWidget);
      expect(find.text('目'), findsNothing);
      expect(
        tester
            .widget<TimetableGrid>(find.byType(TimetableGrid).first)
            .axis
            .expanded,
        isFalse,
      );
      expect(find.text('00:00'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Collapsing restores the previous scroll position', (
    tester,
  ) async {
    await _showHome(tester, size: const Size(390, 360));
    _position(tester).jumpTo(140);
    await tester.pumpAndSettle();
    await tester.tap(find.text('口'));
    await tester.pumpAndSettle();
    expect(_position(tester).pixels, 0);
    expect(_position(tester).maxScrollExtent, closeTo(0, 1e-7));
    await tester.tap(find.text('目'));
    await tester.pumpAndSettle();
    expect(_position(tester).pixels, 140);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Early, lunch and late entries remain accessible, including midnight clusters',
    (tester) async {
      final entries = [
        _event('凌晨一', 30, 35),
        _event('凌晨二', 36, 40),
        _event('晨跑', 420, 450),
        _event('午餐', 750, 780),
        _event('夜跑', 1335, 1380),
      ];
      await _showHome(tester, entries: entries);
      await tester.tap(find.text('口'));
      await tester.pumpAndSettle();
      final cards = tester.widgetList<CalendarBlockTile>(
        find.byType(CalendarBlockTile),
      );
      final displayed = cards
          .expand((card) => card.items)
          .map((item) => item.entry?.id)
          .toSet();
      expect(displayed, containsAll(entries.map((entry) => entry.id)));
      final cluster = find.byWidgetPredicate(
        (widget) =>
            widget is CalendarBlockTile &&
            widget.items.any((item) => item.entry?.id == '凌晨一'),
      );
      await tester.tap(cluster);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('凌晨一'), findsWidgets);
      expect(find.text('凌晨二'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (minute, expectedStart) in [
    (3 * 60 + 20, 3 * 60),
    (7 * 60 + 20, 7 * 60),
    (21 * 60 + 20, 21 * 60),
    (21 * 60 + 40, 21 * 60),
  ]) {
    testWidgets(
      'Early/late selection at minute $minute saves a clock-aligned hour',
      (tester) async {
        final controller = await _showHome(tester);
        await tester.tap(find.text('口'));
        await tester.pumpAndSettle();
        final finder = find.byType(TimetableGrid).first;
        final grid = tester.widget<TimetableGrid>(finder);
        final rect = tester.getRect(finder);
        final column = (rect.width - grid.gutterWidth) / 7;
        final point =
            rect.topLeft +
            Offset(
              grid.gutterWidth + column * 3.5,
              grid.axis.offsetForMinute(minute.toDouble()) * grid.rowHeight,
            );
        await tester.tapAt(point);
        await tester.pumpAndSettle();
        expect(find.widgetWithText(MenuItemButton, '添加课程'), findsNothing);
        final menu = tester.widget<AddMenu>(
          find.byWidgetPredicate(
            (widget) => widget is AddMenu && widget.timeRange != null,
          ),
        );
        expect(
          menu.timeRange!.start,
          _monday.add(Duration(days: 3, minutes: expectedStart)),
        );
        expect(
          menu.timeRange!.end,
          _monday.add(Duration(days: 3, minutes: expectedStart + 60)),
        );
        await tester.tap(find.widgetWithText(MenuItemButton, '添加日程'));
        await tester.pumpAndSettle();
        final name = find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.labelText == '名称',
        );
        await tester.enterText(name, '晚间活动');
        await tester.tap(find.widgetWithText(FilledButton, '保存'));
        await tester.pumpAndSettle();
        final saved = controller.agenda.entries.single;
        expect(saved.startsAt, menu.timeRange!.start);
        expect(saved.endsAt, menu.timeRange!.end);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('The clock stays on its calendar day before and after 03:00', (
    tester,
  ) async {
    await _showHome(tester);
    await tester.tap(find.text('口'));
    await tester.pumpAndSettle();
    final grid = tester.widget<TimetableGrid>(find.byType(TimetableGrid).first);
    for (final minute in [60, 180, 1320]) {
      (grid.currentTime as ValueNotifier<DateTime>).value = _monday.add(
        Duration(minutes: minute),
      );
      await tester.pump();
      final indicator = tester.widget<CurrentTimeIndicator>(
        find.byType(CurrentTimeIndicator).first,
      );
      expect(indicator.axis.expanded, isTrue);
      final paint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(CurrentTimeIndicator).first,
          matching: find.byType(CustomPaint),
        ),
      );
      final dynamic painter = paint.painter;
      expect(painter.day, 0);
      expect(
        painter.center as double,
        closeTo(
          CurrentTimeIndicator.centerAt(
            grid.axis.offsetForMinute(minute.toDouble()),
            grid.rowHeight,
            axis: grid.axis,
          ),
          1e-6,
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });

  test('The expansion choice survives restart', () async {
    final preferences = MemoryPreferences();
    final first = TestAppController(preferences: preferences);
    await first.initialize();
    expect(first.settings.timetableExpanded.value, isFalse);
    await first.settings.setTimetableExpanded(true);
    final restarted = TestAppController(preferences: preferences);
    await restarted.initialize();
    expect(restarted.settings.timetableExpanded.value, isTrue);
  });
}
