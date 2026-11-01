import 'package:bitree/agenda/model.dart';
import 'package:bitree/agenda/ui/calendar_screen.dart';
import 'package:bitree/agenda/view_mode.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/row_swipe.dart';
import 'support/test_app.dart';

void main() {
  Future<TestAppController> showAgenda(
    WidgetTester tester, {
    AgendaKind kind = AgendaKind.deadline,
    int count = 1,
    bool deleted = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final app = TestAppController(
      entries: [
        for (var index = 0; index < count; index++)
          AgendaEntry(
            id: index == 0 ? 'task' : 'task$index',
            title: index == 0 ? '第三章作业' : '作业 $index',
            kind: kind,
            startsAt: DateTime.utc(2099, 1, 2, 20, index),
            endsAt: kind == AgendaKind.deadline
                ? null
                : DateTime.utc(2099, 1, 2, 21, index),
            deleted: deleted,
          ),
      ],
    );
    await app.initialize();
    await app.setAgendaViewMode(AgendaViewMode.list);
    await tester.pumpWidget(
      MaterialApp(
        theme: bitreeTheme(Brightness.light),
        home: Scaffold(
          body: CalendarScreen(controller: app, now: DateTime.utc(2099, 1, 1)),
        ),
      ),
    );
    return app;
  }

  testWidgets('A full right swipe deletes and undo restores the entry', (
    tester,
  ) async {
    final app = await showAgenda(tester);
    await swipeRow(
      tester,
      find.byKey(const ValueKey('task')),
      const Offset(250, 0),
    );
    await tester.pumpAndSettle();
    expect(app.agenda.entries, isEmpty);
    expect(app.agenda.deletedDeadlines.single.id, 'task');
    expect(find.text('第三章作业'), findsNothing);
    expect(find.text('未完成 0'), findsOneWidget);
    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();
    expect(app.agenda.entries.single.id, 'task');
    expect(app.agenda.deletedDeadlines, isEmpty);
    expect(find.text('已恢复“第三章作业”'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('已恢复“第三章作业”'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Full left swipes complete and restore through the status filter',
    (tester) async {
      final app = await showAgenda(tester);
      await swipeRow(
        tester,
        find.byKey(const ValueKey('task')),
        const Offset(-250, 0),
      );
      await tester.pumpAndSettle();
      expect(app.agenda.entries.single.done, isTrue);
      await tester.tap(find.text('已完成 1'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('task')).hitTestable(), findsOneWidget);
      await swipeRow(
        tester,
        find.byKey(const ValueKey('task')).hitTestable(),
        const Offset(-250, 0),
      );
      await tester.pumpAndSettle();
      expect(app.agenda.entries.single.done, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Deleted deadlines can be restored from the agenda header', (
    tester,
  ) async {
    final app = await showAgenda(tester, deleted: true);
    final restoreButton = find.byTooltip('已删除的 DDL');
    expect(restoreButton, findsOneWidget);
    await tester.tap(restoreButton);
    await tester.pumpAndSettle();
    expect(find.text('已删除的 DDL'), findsOneWidget);
    await tester.tap(find.text('恢复'));
    await tester.pumpAndSettle();
    expect(app.agenda.entries.single.id, 'task');
    expect(app.agenda.deletedDeadlines, isEmpty);
    expect(restoreButton, findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
    testWidgets(
      'A short $kind swipe reveals delete immediately, without changing data',
      (tester) async {
        final app = await showAgenda(tester);
        final row = find.byKey(const ValueKey('task'));
        final title = find.text('第三章作业').first;
        final before = tester.getTopLeft(title);
        final gesture = await tester.startGesture(
          tester.getCenter(row),
          kind: kind,
        );
        await gesture.moveBy(
          const Offset(24, 0),
          timeStamp: const Duration(milliseconds: 30),
        );
        await tester.pump();
        expect(tester.getTopLeft(title).dx, closeTo(before.dx + 24, 1));
        await gesture.moveBy(
          const Offset(56, 0),
          timeStamp: const Duration(milliseconds: 100),
        );
        await gesture.up(timeStamp: const Duration(milliseconds: 180));
        await tester.pumpAndSettle();
        expect(app.agenda.entries.single.done, isFalse);
        expect(app.agenda.deletedDeadlines, isEmpty);
        expect(find.text('删除'), findsOneWidget);
        expect(
          tester
              .widget<SegmentedButton<int>>(find.byType(SegmentedButton<int>))
              .selected,
          {0},
        );
        await tester.tap(find.text('删除'));
        await tester.pumpAndSettle();
        expect(app.agenda.entries, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('A short left swipe exposes a working completion button', (
    tester,
  ) async {
    final app = await showAgenda(tester);
    await swipeRow(
      tester,
      find.byKey(const ValueKey('task')),
      const Offset(-90, 0),
    );
    await tester.pumpAndSettle();
    expect(app.agenda.entries.single.done, isFalse);
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(app.agenda.entries.single.done, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'A diagonal drag scrolls, and wheel scrolling closes exposed actions',
    (tester) async {
      final app = await showAgenda(tester, count: 20);
      final row = find.byKey(const ValueKey('task3'));
      final before = tester.getTopLeft(row);
      final gesture = await tester.startGesture(tester.getCenter(row));
      await gesture.moveBy(
        const Offset(-20, -30),
        timeStamp: const Duration(milliseconds: 30),
      );
      await tester.pump();
      await gesture.moveBy(
        const Offset(0, -100),
        timeStamp: const Duration(milliseconds: 150),
      );
      await gesture.up(timeStamp: const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(row).dy, lessThan(before.dy - 80));
      expect(app.agenda.entries.every((entry) => !entry.done), isTrue);
      await swipeRow(tester, row, const Offset(80, 0));
      await tester.pumpAndSettle();
      expect(find.text('删除'), findsOneWidget);
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getCenter(row),
          scrollDelta: const Offset(0, 100),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('删除'), findsNothing);
      expect(app.agenda.entries, hasLength(20));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Starting another row closes the first without opening details', (
    tester,
  ) async {
    final app = await showAgenda(tester, count: 2);
    await swipeRow(
      tester,
      find.byKey(const ValueKey('task')),
      const Offset(80, 0),
    );
    await tester.pumpAndSettle();
    final next = await startRowSwipe(
      tester,
      find.byKey(const ValueKey('task1')),
      const Offset(-80, 0),
    );
    await next.up(timeStamp: const Duration(milliseconds: 240));
    await tester.pumpAndSettle();
    expect(find.text('删除'), findsNothing);
    expect(find.text('完成'), findsOneWidget);
    await tester.tapAt(tester.getCenter(find.byKey(const ValueKey('task1'))));
    await tester.pumpAndSettle();
    expect(find.text('完成'), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
    expect(app.agenda.entries.every((entry) => !entry.done), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Trackpad movement does not execute row actions', (tester) async {
    final app = await showAgenda(tester);
    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.trackpad,
    );
    final origin = tester.getCenter(find.byKey(const ValueKey('task')));
    await gesture.panZoomStart(origin);
    await gesture.panZoomUpdate(
      origin,
      pan: const Offset(-260, 0),
      timeStamp: const Duration(milliseconds: 100),
    );
    await gesture.panZoomEnd(timeStamp: const Duration(milliseconds: 180));
    await tester.pumpAndSettle();
    expect(app.agenda.entries.single.done, isFalse);
    expect(app.agenda.deletedDeadlines, isEmpty);
    expect(find.text('完成'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A schedule has only a right swipe delete action', (
    tester,
  ) async {
    final app = await showAgenda(tester, kind: AgendaKind.event);
    final row = find.byKey(const ValueKey('task'));
    await swipeRow(tester, row, const Offset(-250, 0));
    await tester.pumpAndSettle();
    expect(app.agenda.entries.single.kind, AgendaKind.event);
    expect(app.agenda.entries.single.done, isFalse);
    expect(find.text('完成'), findsNothing);
    await swipeRow(tester, row, const Offset(90, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(app.agenda.entries, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Swiping away deletion feedback keeps the deadline deleted', (
    tester,
  ) async {
    final app = await showAgenda(tester);
    await swipeRow(
      tester,
      find.byKey(const ValueKey('task')),
      const Offset(250, 0),
    );
    await tester.pumpAndSettle();
    await tester.fling(find.text('已删除“第三章作业”'), const Offset(240, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('撤销'), findsNothing);
    expect(app.agenda.entries, isEmpty);
    expect(app.agenda.deletedDeadlines.single.id, 'task');
    expect(tester.takeException(), isNull);
  });
}
