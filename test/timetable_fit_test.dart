import 'dart:convert';
import 'dart:io';

import 'package:bitree/agenda/model.dart';
import 'package:bitree/schedule/height_mode.dart';
import 'package:bitree/schedule/model.dart';
import 'package:bitree/schedule/section_times.dart';
import 'package:bitree/schedule/ui/timetable.dart';
import 'package:bitree/schedule/ui/timetable_grid.dart';
import 'package:bitree/schedule/ui/week_pager.dart';
import 'package:bitree/ui/swipe_pager.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final config = File('.dart_tool/package_config.json');
    final packages =
        (jsonDecode(await config.readAsString()) as Map)['packages'] as List;
    final flutter = packages.cast<Map>().firstWhere(
      (item) => item['name'] == 'flutter',
    );
    final root = config.absolute.uri.resolve('${flutter['rootUri']}/');
    final font = File.fromUri(
      root.resolve(
        '../../bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
      ),
    );
    await (FontLoader(
      'Roboto',
    )..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
  });

  testWidgets('A near-fitting timetable compresses instead of scrolling', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 660);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final controller = TestAppController(
      schedule: SemesterSchedule(
        term: '2026-2027-1',
        firstMonday: DateTime.utc(2026, 10, 26),
        courses: const [],
      ),
      initialWeek: 1,
    );
    await controller.initialize();

    await tester.pumpWidget(
      MaterialApp(
        theme: bitreeTheme(Brightness.light).copyWith(
          textTheme: bitreeTheme(Brightness.light).textTheme
              .apply(fontFamily: 'Roboto'),
        ),
        home: Scaffold(
          body: Timetable(
            controller: controller,
            week: 1,
            initialScrollOffset: 0,
            onScroll: (_) {},
            active: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(Timetable),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.maxScrollExtent, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Fit shows all rows with large fonts and follows window resize', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 360);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = TestAppController(
      entries: [
        AgendaEntry(
          id: 'compact-agenda',
          title: 'A long agenda title',
          kind: AgendaKind.exam,
          startsAt: DateTime.utc(2026, 10, 26, 8),
          endsAt: DateTime.utc(2026, 10, 26, 8, 45),
          location: 'A long agenda location',
        ),
      ],
      schedule: SemesterSchedule(
        term: '2026-2027-1',
        firstMonday: DateTime.utc(2026, 10, 26),
        courses: [
          for (var day = 1; day <= 7; day++)
            Course(
              id: 'compact-$day',
              name: 'A long course title that should not overflow',
              weekday: day,
              startSection: 13,
              endSection: 13,
              weeks: [1],
              room: 'A very long room name',
            ),
          Course(
            id: 'overlap',
            name: 'Overlapping course',
            weekday: 1,
            startSection: 13,
            endSection: 13,
            weeks: [1],
          ),
        ],
      ),
      initialWeek: 1,
    );
    await controller.initialize();
    await controller.settings.setTimetableHeightMode(TimetableHeightMode.fit);
    await tester.pumpWidget(_fitTestApp(controller, scale: 2.5));
    await tester.pumpAndSettle();

    void checkFit() {
      final position = _timetablePosition(tester);
      final grid = tester.widget<TimetableGrid>(find.byType(TimetableGrid));
      expect(position.pixels, 0);
      expect(position.maxScrollExtent, closeTo(0, 0.001));
      expect(grid.rowHeight * sectionTimes.length,
          closeTo(position.viewportDimension, 0.001));
      expect(tester.takeException(), isNull);
    }

    checkFit();
    final firstHeight = tester.widget<TimetableGrid>(find.byType(TimetableGrid))
        .rowHeight;
    tester.view.physicalSize = const Size(390, 280);
    await tester.pumpAndSettle();
    checkFit();
    expect(tester.widget<TimetableGrid>(find.byType(TimetableGrid)).rowHeight,
        lessThan(firstHeight));
    tester.view.physicalSize = const Size(390, 120);
    await tester.pumpAndSettle();
    checkFit();
  });

  testWidgets('Direct notifier changes restore the normal offset after fit', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 360);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = TestAppController(
      schedule: SemesterSchedule(
        term: '2026-2027-1',
        firstMonday: DateTime.utc(2026, 10, 26),
        courses: const [],
      ),
      initialWeek: 1,
    );
    await controller.initialize();
    var remembered = 0.0;
    await tester.pumpWidget(_fitTestApp(
      controller,
      onScroll: (offset) => remembered = offset,
    ));
    await tester.pumpAndSettle();
    _timetablePosition(tester).jumpTo(150);
    await tester.pumpAndSettle();
    expect(remembered, 150);

    controller.settings.timetableHeightMode.value = TimetableHeightMode.fit;
    await tester.pumpAndSettle();
    expect(_timetablePosition(tester).pixels, 0);
    expect(_timetablePosition(tester).maxScrollExtent, closeTo(0, 0.001));
    expect(remembered, 150);

    controller.settings.timetableHeightMode.value = TimetableHeightMode.normal;
    await tester.pumpAndSettle();
    expect(_timetablePosition(tester).pixels, 150);
    expect(remembered, 150);
    expect(tester.takeException(), isNull);

    controller.settings.timetableHeightMode.value = TimetableHeightMode.fit;
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(390, 800);
    await tester.pumpAndSettle();
    controller.settings.timetableHeightMode.value = TimetableHeightMode.normal;
    await tester.pumpAndSettle();
    expect(_timetablePosition(tester).pixels, 0);
    expect(remembered, 0);
    expect(tester.takeException(), isNull);

    // Unmounting must remove the listener even for direct widget consumers.
    await tester.pumpWidget(const SizedBox());
    controller.settings.timetableHeightMode.value = TimetableHeightMode.fit;
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Only the selected week updates the shared normal offset', (
    tester,
  ) async {
    final controller = TestAppController(
      schedule: SemesterSchedule(
        term: '2026-2027-1',
        firstMonday: DateTime.utc(2026, 10, 26),
        firstWeek: 1,
        lastWeek: 3,
        courses: const [],
      ),
      initialWeek: 2,
    );
    await controller.initialize();
    await tester.pumpWidget(MaterialApp(
      theme: bitreeTheme(Brightness.light),
      home: Scaffold(body: WeekPager(controller: controller, active: false)),
    ));
    await tester.pumpAndSettle();
    final pager = tester.widget<SwipePager>(find.byType(SwipePager));
    final context = tester.element(find.byType(WeekPager));
    final selected = pager.itemBuilder(context, 1) as Timetable;
    final neighbor = pager.itemBuilder(context, 0) as Timetable;
    selected.onScroll(150);
    neighbor.onScroll(0);
    final futurePage = pager.itemBuilder(context, 2) as Timetable;
    expect(futurePage.initialScrollOffset, 150);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('An initially fitting page retains the passed normal offset', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 360);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = TestAppController(
      schedule: SemesterSchedule(
        term: '2026-2027-1',
        firstMonday: DateTime.utc(2026, 10, 26),
        courses: const [],
      ),
      initialWeek: 1,
    );
    await controller.initialize();
    controller.settings.timetableHeightMode.value = TimetableHeightMode.fit;
    await tester.pumpWidget(_fitTestApp(controller, initialScrollOffset: 125));
    await tester.pumpAndSettle();
    expect(_timetablePosition(tester).pixels, 0);
    controller.settings.timetableHeightMode.value = TimetableHeightMode.normal;
    await tester.pumpAndSettle();
    expect(_timetablePosition(tester).pixels, 125);
    expect(tester.takeException(), isNull);
  });
}

ScrollPosition _timetablePosition(WidgetTester tester) =>
    tester.state<ScrollableState>(find.descendant(
      of: find.byType(Timetable),
      matching: find.byType(Scrollable),
    )).position;

Widget _fitTestApp(
  TestAppController controller, {
  double scale = 1,
  double initialScrollOffset = 0,
  ValueChanged<double>? onScroll,
}) => MaterialApp(
  theme: bitreeTheme(Brightness.light).copyWith(
    textTheme: bitreeTheme(Brightness.light).textTheme.apply(fontFamily: 'Roboto'),
  ),
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Scaffold(
      body: Timetable(
        controller: controller,
        week: 1,
        initialScrollOffset: initialScrollOffset,
        onScroll: onScroll ?? (_) {},
        active: false,
      ),
    ),
  ),
);
