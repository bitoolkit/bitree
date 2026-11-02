import 'package:bitree/agenda/model.dart';
import 'package:bitree/agenda/timeline_layout.dart';
import 'package:bitree/agenda/ui/agenda_timeline.dart';
import 'package:bitree/l10n/app_localizations_zh.dart';
import 'package:bitree/l10n/formats.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

final _date = DateTime.utc(2026, 11, 17);

AgendaEntry _event(String id, int hour, {bool exam = false}) => AgendaEntry(
  id: id,
  title: exam ? '数据结构考试' : '短日程$id',
  kind: exam ? AgendaKind.exam : AgendaKind.event,
  startsAt: _date.add(Duration(hours: hour)),
  endsAt: _date.add(Duration(hours: hour, minutes: 5)),
);

Finder _bar(AgendaEntry entry) => find.bySemanticsLabel(
  RegExp(
    '^${RegExp.escape('${entry.kind.localizedLabel(AppLocalizationsZh())}，${entry.title}，')}',
  ),
);

Finder _paintedBar(AgendaEntry entry) =>
    find.byKey(ValueKey(('agenda-timeline-bar', entry.id)));

Future<TestAppController> _show(
  WidgetTester tester,
  List<AgendaEntry> entries, {
  double scale = 1,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final app = TestAppController(entries: entries);
  await app.initialize();
  await tester.pumpWidget(
    MaterialApp(
      theme: bitreeTheme(brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: AgendaTimeline(
          controller: app,
          entries: entries,
          now: _date.add(const Duration(hours: 12)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return app;
}

void main() {
  test('Minimum display spans separate short events without changing their real times', () {
    final first = _event('first', 11);
    final second = _event('second', 14, exam: true);
    final entries = [first, second];
    final zoomedOut = layoutAgendaTimeline(
      entries,
      minimumEventSpan: const Duration(hours: 48),
    );
    expect(zoomedOut.map((placement) => placement.lane), [0, 1]);
    expect(zoomedOut.first.start, first.startsAt);
    expect(zoomedOut.first.end, first.endsAt);
    expect(
      zoomedOut.first.layoutEnd,
      first.startsAt.add(const Duration(hours: 48)),
    );
    final zoomedIn = layoutAgendaTimeline(
      entries,
      minimumEventSpan: const Duration(hours: 2),
    );
    expect(zoomedIn.map((placement) => placement.lane), [0, 0]);
    expect(zoomedIn.map((placement) => placement.end), [
      first.endsAt,
      second.endsAt,
    ]);
  });

  test('Long events and DDL reservations retain their full intervals', () {
    final long = AgendaEntry(
      id: 'long',
      title: '多日日程',
      kind: AgendaKind.event,
      startsAt: _date,
      endsAt: _date.add(const Duration(days: 5)),
    );
    final ddl = AgendaEntry(
      id: 'ddl',
      title: '作业',
      kind: AgendaKind.deadline,
      startsAt: _date.add(const Duration(hours: 13)),
    );
    final placements = layoutAgendaTimeline([
      long,
      ddl,
    ], minimumEventSpan: const Duration(days: 2));
    final eventPlacement = placements.singleWhere(
      (placement) => placement.entry == long,
    );
    final deadlinePlacement = placements.singleWhere(
      (placement) => placement.entry == ddl,
    );
    expect(eventPlacement.layoutEnd, long.endsAt);
    expect(
      deadlinePlacement.start,
      ddl.dueAt.subtract(const Duration(days: 4)),
    );
    expect(deadlinePlacement.layoutEnd, ddl.dueAt);
  });

  for (final (brightness, scale) in [
    (Brightness.light, 1.0),
    (Brightness.dark, 1.6),
  ]) {
    testWidgets(
      'Short cards keep a fixed 2px minimum and stay tappable in $brightness, $scale',
      (tester) async {
        final first = _event('first', 11);
        final second = _event('second', 14, exam: true);
        final ddl = AgendaEntry(
          id: 'ddl',
          title: '第五章作业',
          kind: AgendaKind.deadline,
          startsAt: _date.add(const Duration(hours: 13)),
        );
        final entries = [first, second, ddl];
        final app = await _show(
          tester,
          entries,
          scale: scale,
          brightness: brightness,
        );
        final viewport = tester.getRect(find.byType(AgendaTimeline));
        void checkCards(double eventWidth) {
          final rectangles = entries
              .map((entry) => tester.getRect(_paintedBar(entry)))
              .toList();
          expect(rectangles.first.width, closeTo(eventWidth, .001));
          expect(
            rectangles[1].width,
            closeTo(
              eventWidth.clamp(0, viewport.right - rectangles[1].left),
              .001,
            ),
          );
          expect(rectangles.last.width, closeTo(180, .001));
          for (var index = 0; index < rectangles.length; index++) {
            expect(
              rectangles[index].height,
              closeTo(tester.getRect(_bar(entries[index])).height, .001),
            );
            for (var other = index + 1; other < rectangles.length; other++) {
              expect(rectangles[index].overlaps(rectangles[other]), isFalse);
            }
          }
          expect(
            tester.getSemantics(_bar(first)).label,
            contains('11:00–11:05'),
          );
          expect(tester.takeException(), isNull);
        }

        checkCards(2);
        tester.widget<Slider>(find.byType(Slider)).onChanged!(24);
        await tester.pumpAndSettle();
        // At 48px/hour, the real five-minute duration is 4px, above the 2px floor.
        checkCards(4);
        final short = tester.getRect(_bar(first));
        await tester.tapAt(Offset(short.right - 12, short.center.dy));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text(first.title),
          ),
          findsWidgets,
        );
        expect(app.agenda.entries, orderedEquals(entries));
        expect(first.endsAt, _date.add(const Duration(hours: 11, minutes: 5)));
        await tester.tap(find.byTooltip('关闭'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'A minimum-width card stays visible after its real end leaves the viewport',
    (tester) async {
      final beforeViewport = _date
          .subtract(const Duration(days: 4))
          .add(const Duration(hours: 10));
      final entry = AgendaEntry(
        id: 'edge',
        title: '边缘短日程',
        kind: AgendaKind.event,
        startsAt: beforeViewport,
        endsAt: beforeViewport.add(const Duration(minutes: 5)),
      );
      await _show(tester, [entry]);
      final painted = tester.getRect(_paintedBar(entry));
      expect(painted.left, 0);
      // Half of the 2px bar is clipped at the left edge; its hit target is wider.
      expect(painted.width, closeTo(1, .001));
      final card = tester.getRect(_bar(entry));
      expect(card.left, 0);
      await tester.tapAt(card.center);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Off-screen lanes do not add vertical blank pages', (
    tester,
  ) async {
    final current = _event('current', 11);
    final farDay = _date.add(const Duration(days: 30));
    final offScreen = [
      for (var index = 0; index < 20; index++)
        AgendaEntry(
          id: 'off-screen-$index',
          title: '远处日程 $index',
          kind: AgendaKind.event,
          startsAt: farDay.add(Duration(hours: 10, minutes: index)),
          endsAt: farDay.add(const Duration(hours: 14)),
        ),
    ];
    await _show(tester, [current, ...offScreen]);

    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const ValueKey('agenda-timeline-lanes')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.maxScrollExtent, 0);
    expect(_paintedBar(current), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Overlapping entries remain reachable below the viewport', (
    tester,
  ) async {
    final entries = [
      for (var index = 0; index < 20; index++)
        AgendaEntry(
          id: 'overlap-$index',
          title: '重叠日程 $index',
          kind: AgendaKind.event,
          startsAt: _date.add(Duration(hours: 11, minutes: index)),
          endsAt: _date.add(const Duration(hours: 14)),
        ),
    ];
    await _show(tester, entries);

    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const ValueKey('agenda-timeline-lanes')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(_paintedBar(entries.last), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Time ranges are visible on cards and long press previews complete endpoints',
    (tester) async {
      final entry = AgendaEntry(
        id: 'preview',
        title: '时间预览日程',
        kind: AgendaKind.event,
        startsAt: _date.add(const Duration(hours: 11)),
        endsAt: _date.add(const Duration(hours: 13)),
      );
      await _show(tester, [entry]);
      // Card text is conditional on available width; zoom in on a real 2h event.
      tester.widget<Slider>(find.byType(Slider)).onChanged!(24);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: _bar(entry), matching: find.text('11:00–13:00')),
        findsOneWidget,
      );
      await tester.longPress(_bar(entry));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('开始：2026-11-17 周二 11:00', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('结束：2026-11-17 周二 13:00', findRichText: true),
        findsOneWidget,
      );
      expect(find.byType(BottomSheet), findsNothing);
      await tester.tap(_bar(entry));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final allDay in [false, true]) {
    testWidgets('Multi-day entries label both dates, allDay=$allDay', (
      tester,
    ) async {
      final entry = AgendaEntry(
        id: 'multi',
        title: '跨天日程',
        kind: AgendaKind.event,
        startsAt: allDay ? _date : _date.add(const Duration(hours: 11)),
        endsAt: allDay
            ? _date.add(const Duration(days: 2))
            : _date.add(const Duration(days: 1, hours: 13)),
        allDay: allDay,
      );
      await _show(tester, [entry], scale: 1.6, brightness: Brightness.dark);
      expect(
        find.descendant(
          of: _bar(entry),
          matching: find.text(
            allDay ? '11/17–11/18\n全天' : '11/17 11:00\n→ 11/18 13:00',
          ),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final allDay in [false, true]) {
    testWidgets(
      'DDL cards show their deadline without losing the course label, allDay=$allDay',
      (tester) async {
        final entry = AgendaEntry(
          id: 'deadline',
          title: '第五章作业',
          kind: AgendaKind.deadline,
          startsAt: _date.add(const Duration(hours: 13)),
          course: '高等数学',
          allDay: allDay,
        );
        await _show(tester, [entry], scale: 1.6);
        expect(
          find.descendant(of: _bar(entry), matching: find.text('高等数学')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: _bar(entry),
            matching: find.text(allDay ? '全天截止' : '13:00 截止'),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('Hover previews the real interval without opening details', (
    tester,
  ) async {
    final entry = _event('hover', 11);
    await _show(tester, [entry]);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(10, 500));
    await mouse.moveTo(tester.getCenter(_bar(entry)));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('开始：2026-11-17 周二 11:00', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('结束：2026-11-17 周二 11:05', findRichText: true),
      findsOneWidget,
    );
    expect(find.byType(BottomSheet), findsNothing);
    await mouse.removePointer();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
