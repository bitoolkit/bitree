import 'dart:async';

import 'package:bitree/agenda/model.dart';
import 'package:bitree/agenda/ui/calendar_screen.dart';
import 'package:bitree/schedule/model.dart';
import 'package:bitree/schedule/store.dart';
import 'package:bitree/schedule/ui/home_screen.dart';
import 'package:bitree/ui/editor_sheet.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

class _BlockingScheduleStore extends MemoryScheduleStore {
  _BlockingScheduleStore({required super.selected});

  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> write(ScheduleLibrary library) async {
    if (!started.isCompleted) started.complete();
    await release.future;
    await super.write(library);
  }
}

void main() {
  final now = DateTime.utc(2026, 10, 28, 12);

  for (final home in [true, false]) {
    for (final size in [const Size(320, 844), const Size(1200, 900)]) {
      testWidgets(
        '${home ? 'Home' : 'Agenda'} offers the same ordered add actions at $size',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          final controller = TestAppController();
          await controller.initialize();
          await tester.pumpWidget(
            MaterialApp(
              theme: bitreeTheme(Brightness.light),
              home: Scaffold(
                body: home
                    ? HomeScreen(
                        controller: controller,
                        now: now,
                        active: false,
                      )
                    : CalendarScreen(
                        controller: controller,
                        now: now,
                        active: false,
                      ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.byTooltip('添加'));
          await tester.pumpAndSettle();
          final labels = find.descendant(
            of: find.byType(MenuItemButton),
            matching: find.byType(Text),
          );
          expect(tester.widgetList<Text>(labels).map((label) => label.data), [
            '添加课程',
            '添加日程',
            '添加 DDL',
          ]);
          final addCourse = find.widgetWithText(MenuItemButton, '添加课程');
          final addAgenda = find.widgetWithText(MenuItemButton, '添加日程');
          final addDeadline = find.widgetWithText(MenuItemButton, '添加 DDL');
          final course = tester.getRect(addCourse);
          final agenda = tester.getRect(addAgenda);
          final deadline = tester.getRect(addDeadline);
          expect(course.center.dy, lessThan(agenda.center.dy));
          expect(agenda.center.dy, lessThan(deadline.center.dy));
          expect(agenda.right, lessThanOrEqualTo(size.width));
          expect(deadline.right, lessThanOrEqualTo(size.width));

          await tester.tap(addCourse);
          await tester.pumpAndSettle();
          expect(
            tester.widget<EditorSheet>(find.byType(EditorSheet)).title,
            '添加课程',
          );
          await tester.tap(find.byTooltip('关闭'));
          await tester.pumpAndSettle();

          await tester.tap(find.byTooltip('添加'));
          await tester.pumpAndSettle();
          await tester.tap(addAgenda);
          await tester.pumpAndSettle();
          expect(
            tester.widget<EditorSheet>(find.byType(EditorSheet)).title,
            '添加日程',
          );
          final kinds = tester.widget<SegmentedButton<AgendaKind>>(
            find.byType(SegmentedButton<AgendaKind>),
          );
          expect(kinds.segments.map((segment) => segment.value), [
            AgendaKind.event,
            AgendaKind.deadline,
          ]);
          expect(find.text('考试'), findsNothing);
          await tester.tap(find.text('DDL'));
          await tester.pumpAndSettle();
          expect(
            tester.widget<EditorSheet>(find.byType(EditorSheet)).title,
            '添加DDL',
          );
          expect(find.text('结束'), findsNothing);
          await tester.tap(
            find.descendant(
              of: find.byType(SegmentedButton<AgendaKind>),
              matching: find.text('日程'),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.widget<EditorSheet>(find.byType(EditorSheet)).title,
            '添加日程',
          );
          expect(find.text('结束'), findsOneWidget);
          await tester.tap(find.byTooltip('关闭'));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('添加'));
          await tester.pumpAndSettle();
          await tester.tap(addDeadline);
          await tester.pumpAndSettle();
          expect(
            tester.widget<EditorSheet>(find.byType(EditorSheet)).title,
            '添加DDL',
          );
          expect(
            tester
                .widget<SegmentedButton<AgendaKind>>(
                  find.byType(SegmentedButton<AgendaKind>),
                )
                .selected,
            {AgendaKind.deadline},
          );
          expect(find.text('截止'), findsOneWidget);
          expect(find.text('结束'), findsNothing);
          expect(find.text('地点（选填）'), findsNothing);
          await tester.tap(find.byTooltip('关闭'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets('One busy editor does not block unrelated add actions', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final schedule = SemesterSchedule(
      term: '2026-2027-1',
      firstMonday: DateTime.utc(2026, 10, 26),
      courses: const [],
    );
    final store = _BlockingScheduleStore(selected: schedule);
    final controller = TestAppController(scheduleStore: store);
    await controller.initialize();
    final save = controller.timetable.setWeekRange(first: 1, last: 16);
    await store.started.future;

    await tester.pumpWidget(
      MaterialApp(
        theme: bitreeTheme(Brightness.light),
        home: Scaffold(
          body: HomeScreen(controller: controller, now: now, active: false),
        ),
      ),
    );
    await tester.pump();

    expect(controller.timetable.busy, isTrue);
    await tester.tap(find.byTooltip('添加'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<MenuItemButton>(find.widgetWithText(MenuItemButton, '添加课程'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<MenuItemButton>(find.widgetWithText(MenuItemButton, '添加日程'))
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<MenuItemButton>(find.widgetWithText(MenuItemButton, '添加 DDL'))
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);

    store.release.complete();
    await save;
    await tester.pumpAndSettle();
  });
}
