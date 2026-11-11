import 'package:bitree/agenda/calendar.dart';
import 'package:bitree/agenda/model.dart';
import 'package:bitree/app/ui/add_menu.dart';
import 'package:bitree/schedule/layout.dart';
import 'package:bitree/schedule/model.dart';
import 'package:bitree/schedule/ui/timetable_grid.dart';
import 'package:bitree/ui/app_dropdown_field.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  const defaultRowHeight = 64.0;
  const defaultGutterWidth = 64.0;
  final monday = DateTime.utc(2026, 10, 26);
  final course = Course(
    id: 'course',
    name: '离散数学',
    weekday: DateTime.friday,
    startSection: 3,
    endSection: 4,
    weeks: [1],
  );
  final event = AgendaEntry(
    id: 'event',
    title: '羽毛球',
    kind: AgendaKind.event,
    startsAt: DateTime.utc(2026, 10, 31, 11, 35),
    endsAt: DateTime.utc(2026, 10, 31, 12, 20),
  );
  final schedule = SemesterSchedule(
    term: '2026-2027-1',
    firstMonday: monday,
    courses: [course],
  );
  final addCourse = find.widgetWithText(MenuItemButton, '添加课程');

  Future<TestAppController> showGrid(
    WidgetTester tester, {
    VoidCallback? onOutsideTap,
    Size size = const Size(800, 1000),
    double gutterWidth = defaultGutterWidth,
    double rowHeight = defaultRowHeight,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = TestAppController(schedule: schedule, entries: [event]);
    await controller.initialize();
    final time = ValueNotifier(DateTime.utc(2026, 10, 27, 8));
    addTearDown(time.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: bitreeTheme(Brightness.light),
        home: Scaffold(
          appBar: AppBar(
            title: const Text('课表'),
            actions: [
              IconButton(
                tooltip: '其他操作',
                onPressed: onOutsideTap ?? () {},
                icon: const Icon(Icons.more_horiz),
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: TimetableGrid(
              timetable: controller.timetable,
              agenda: controller.agenda,
              monday: monday,
              layouts: [
                for (var day = 0; day < 7; day++)
                  groupCalendarItems(
                    calendarItemsOn(monday.add(Duration(days: day)), schedule, [
                      event,
                    ]),
                    monday.add(Duration(days: day)),
                  ),
              ],
              gutterWidth: gutterWidth,
              rowHeight: rowHeight,
              todayColumn: null,
              todayBackground: Colors.transparent,
              currentTime: time,
            ),
          ),
        ),
      ),
    );
    return controller;
  }

  Offset cell(WidgetTester tester, int day, int section) {
    final grid = tester.getRect(find.byType(TimetableGrid));
    final width = (grid.width - defaultGutterWidth) / 7;
    return grid.topLeft +
        Offset(
          defaultGutterWidth + (day + 0.5) * width,
          (section - 0.5) * defaultRowHeight,
        );
  }

  Future<void> openMenu(
    WidgetTester tester, {
    int day = 0,
    int section = 2,
  }) async {
    await tester.tapAt(cell(tester, day, section));
    await tester.pumpAndSettle();
    expect(addCourse, findsOneWidget);
    expect(
      tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(MenuItemButton),
              matching: find.byType(Text),
            ),
          )
          .map((label) => label.data),
      ['添加课程', '添加日程', '添加 DDL'],
    );
  }

  void expectClosed(WidgetTester tester) {
    expect(addCourse, findsNothing);
    expect(tester.widget<AddMenu>(find.byType(AddMenu)).selection, isNull);
    expect(tester.takeException(), isNull);
  }

  testWidgets('Compact period labels fit their rows', (tester) async {
    await showGrid(
      tester,
      size: const Size(320, 844),
      gutterWidth: 30,
      rowHeight: 53.2,
    );

    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('08:45'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final sameCell in [true, false]) {
    testWidgets(
      'Tapping ${sameCell ? 'the selected' : 'another'} empty cell only closes the menu',
      (tester) async {
        await showGrid(tester);
        await openMenu(tester);
        await tester.tapAt(
          sameCell
              ? cell(tester, 0, 2) - const Offset(30, 20)
              : cell(tester, 6, 6),
        );
        await tester.pumpAndSettle();
        expectClosed(tester);

        await openMenu(tester, day: 6, section: 6);
        final selection = tester
            .widget<AddMenu>(find.byType(AddMenu))
            .selection!;
        expect(selection.date.weekday, DateTime.sunday);
        expect(selection.startSection, 6);
      },
    );
  }

  for (final occupied in [(day: 4, section: 3), (day: 5, section: 5)]) {
    testWidgets(
      'Tapping an occupied cell ${occupied.day} closes the menu and opens details',
      (tester) async {
        await showGrid(tester);
        await openMenu(tester);
        await tester.tapAt(cell(tester, occupied.day, occupied.section));
        await tester.pumpAndSettle();
        expectClosed(tester);
        expect(find.byType(BottomSheet), findsOneWidget);
        if (occupied.day == 4) {
          expect(
            find.descendant(
              of: find.byType(BottomSheet),
              matching: find.text(course.name),
            ),
            findsOneWidget,
          );
        }
      },
    );
  }

  testWidgets('Outside controls still receive their tap', (tester) async {
    var taps = 0;
    await showGrid(tester, onOutsideTap: () => taps++);
    await openMenu(tester);
    await tester.tap(find.byTooltip('其他操作'));
    await tester.pumpAndSettle();
    expectClosed(tester);
    expect(taps, 1);
  });

  for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
    testWidgets('$kind outside taps keep the closing menu actions unchanged', (
      tester,
    ) async {
      await showGrid(tester);
      await openMenu(tester, day: 6, section: 9);
      final panel = find.byWidgetPredicate(
        (widget) => widget is Material && widget.elevation == 6,
      );
      final opened = tester.getRect(panel);
      var height = opened.height;
      final gesture = await tester.startGesture(cell(tester, 3, 7), kind: kind);
      await tester.pump();
      await gesture.up();
      for (var frame = 0; frame < 15; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (panel.evaluate().isEmpty) break;
        expect(
          tester
              .widgetList<Text>(
                find.descendant(
                  of: find.byType(MenuItemButton),
                  matching: find.byType(Text),
                ),
              )
              .map((label) => label.data),
          ['添加课程', '添加日程', '添加 DDL'],
        );
        final closing = tester.getRect(panel);
        expect(closing.height, lessThanOrEqualTo(height));
        expect(closing.left, closeTo(opened.left, 0.1));
        expect(closing.top, closeTo(opened.top, 0.1));
        height = closing.height;
      }
      await tester.pumpAndSettle();
      expectClosed(tester);
    });
  }

  testWidgets('Cancelled drags clear the selection and a new drag can finish', (
    tester,
  ) async {
    await showGrid(tester);
    final cancelled = await tester.startGesture(cell(tester, 0, 2));
    await tester.pump(const Duration(milliseconds: 600));
    await cancelled.moveTo(cell(tester, 0, 4));
    await tester.pump();
    expect(
      tester.widget<AddMenu>(find.byType(AddMenu)).selection!.endSection,
      4,
    );
    await cancelled.cancel();
    await tester.pumpAndSettle();
    expectClosed(tester);

    final completed = await tester.startGesture(cell(tester, 1, 3));
    await tester.pump(const Duration(milliseconds: 600));
    await completed.moveTo(cell(tester, 1, 5));
    await tester.pump();
    final selection = tester.widget<AddMenu>(find.byType(AddMenu)).selection!;
    expect(selection.date.weekday, DateTime.tuesday);
    expect(selection.startSection, 3);
    expect(selection.endSection, 5);
    await completed.up();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(addCourse, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final (kind, day, start, end) in [
    (PointerDeviceKind.mouse, 1, 2, 5),
    (PointerDeviceKind.touch, 4, 2, 5),
    (PointerDeviceKind.touch, 4, 3, 6),
    (PointerDeviceKind.touch, 5, 5, 7),
    (PointerDeviceKind.mouse, 4, 4, 2),
    (PointerDeviceKind.mouse, 5, 4, 6),
  ]) {
    testWidgets('$kind selects day $day from $start through $end', (
      tester,
    ) async {
      await showGrid(tester);
      final gesture = await tester.startGesture(
        cell(tester, day, start),
        kind: kind,
      );
      if (kind == PointerDeviceKind.touch) {
        await tester.pump(const Duration(milliseconds: 600));
      }
      await gesture.moveTo(cell(tester, day, end));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(addCourse, findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      final selection = tester.widget<AddMenu>(find.byType(AddMenu)).selection!;
      expect(selection.date, monday.add(Duration(days: day)));
      expect(selection.startSection, start < end ? start : end);
      expect(selection.endSection, start > end ? start : end);
      if (kind == PointerDeviceKind.touch && day == 4 && start == 3) {
        await tester.tap(addCourse);
        await tester.pumpAndSettle();
        for (final (label, section) in [('开始节次', 3), ('结束节次', 6)]) {
          final field = find.byWidgetPredicate(
            (widget) =>
                widget is AppDropdownField<int> && widget.label == label,
          );
          expect(tester.widget<AppDropdownField<int>>(field).value, section);
        }
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Releasing an edge drag stops scrolling and keeps the menu open',
    (tester) async {
      await showGrid(tester, size: const Size(390, 600));
      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      final start = cell(tester, 0, 2);
      final gesture = await tester.startGesture(start);
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(Offset(start.dx, 596));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(scrollable.position.pixels, greaterThan(0));
      expect(scrollable.position.isScrollingNotifier.value, isTrue);
      await gesture.up();
      final releasedOffset = scrollable.position.pixels;
      for (var frame = 0; frame < 24; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(scrollable.position.isScrollingNotifier.value, isFalse);
      expect(addCourse, findsOneWidget);
      expect(scrollable.position.pixels, releasedOffset);
      final offset = scrollable.position.pixels;
      await tester.pump(const Duration(milliseconds: 200));
      expect(scrollable.position.pixels, offset);
      expect(addCourse, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Leaving the grid during edge scrolling releases the drag', (
    tester,
  ) async {
    await showGrid(tester, size: const Size(390, 600));
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    final start = cell(tester, 0, 2);
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(Offset(start.dx, 596));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(scrollable.position.isScrollingNotifier.value, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final (kind, day, startSection, endSection, autoScroll) in [
    (PointerDeviceKind.touch, 0, 2, 12, false),
    (PointerDeviceKind.touch, 2, 12, 2, false),
    (PointerDeviceKind.mouse, 0, 2, 12, false),
    (PointerDeviceKind.touch, 6, 2, 12, true),
  ]) {
    testWidgets(
      '$kind long selection stays in day $day despite horizontal drift, scrolling $autoScroll',
      (tester) async {
        final size = Size(390, autoScroll ? 600 : 900);
        await showGrid(tester, size: size);
        final scrollable = tester.state<ScrollableState>(
          find.byType(Scrollable),
        );
        final start = cell(tester, day, startSection);
        final end = autoScroll
            ? Offset(start.dx, size.height - 12)
            : cell(tester, day, endSection);
        final release = Offset(day == 0 ? size.width - 20 : 20, end.dy);
        final gesture = await tester.startGesture(start, kind: kind);
        if (kind == PointerDeviceKind.touch) {
          await tester.pump(const Duration(milliseconds: 600));
        }
        await gesture.moveTo(release);
        await tester.pump();
        if (autoScroll) {
          for (var frame = 0; frame < 30; frame++) {
            await tester.pump(const Duration(milliseconds: 20));
          }
          expect(scrollable.position.pixels, greaterThan(0));
        }
        await gesture.up();
        await tester.pumpAndSettle();
        final panel = tester.getRect(
          find.byWidgetPredicate(
            (widget) => widget is Material && widget.elevation == 6,
          ),
        );
        expect(
          panel.left,
          closeTo(start.dx.clamp(8, size.width - panel.width - 8), .1),
        );
        final top = release.dy + panel.height <= size.height - 8
            ? release.dy
            : release.dy - panel.height;
        expect(panel.top, closeTo(top, .1));
        expect(panel.left, greaterThanOrEqualTo(8));
        expect(panel.right, lessThanOrEqualTo(size.width - 8));
        final selection = tester
            .widget<AddMenu>(find.byType(AddMenu))
            .selection!;
        expect(selection.date.weekday, day + 1);
        expect(
          selection.startSection,
          startSection < endSection ? startSection : endSection,
        );
        if (!autoScroll) {
          expect(
            selection.endSection,
            startSection > endSection ? startSection : endSection,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Menu actions retain the selected date and section', (
    tester,
  ) async {
    await showGrid(tester);
    await openMenu(tester, day: 6, section: 6);
    await tester.tap(addCourse);
    await tester.pumpAndSettle();
    expect(find.text('保存课程'), findsOneWidget);
    for (final field in [('星期', DateTime.sunday), ('开始节次', 6)]) {
      final finder = find.byWidgetPredicate(
        (widget) => widget is AppDropdownField<int> && widget.label == field.$1,
      );
      expect(tester.widget<AppDropdownField<int>>(finder).value, field.$2);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('The DDL shortcut saves the selected time and semester', (
    tester,
  ) async {
    final controller = await showGrid(tester);
    await openMenu(tester, day: 6, section: 6);
    await tester.tap(find.widgetWithText(MenuItemButton, '添加 DDL'));
    await tester.pumpAndSettle();
    expect(find.text('添加DDL'), findsOneWidget);
    expect(find.text('截止'), findsOneWidget);
    expect(find.text('结束'), findsNothing);
    final name = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == '名称',
    );
    await tester.enterText(name, '实验报告');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    final entry = controller.agenda.entries
        .where((entry) => entry.isDeadline)
        .single;
    expect(entry.title, '实验报告');
    expect(entry.startsAt, DateTime.utc(2026, 11, 1, 13, 20));
    expect(entry.endsAt, isNull);
    expect(entry.term, schedule.term);
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
