import 'dart:math' as math;

import 'package:bitree/agenda/model.dart';
import 'package:bitree/agenda/timeline_layout.dart';
import 'package:bitree/agenda/ui/agenda_timeline.dart';
import 'package:bitree/agenda/ui/timeline_entry.dart';
import 'package:bitree/l10n/app_localizations_zh.dart';
import 'package:bitree/l10n/formats.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

List<AgendaEntry> _stackedDeadlines() => [
  for (var index = 0; index < 24; index++)
    AgendaEntry(
      id: 'stacked-${index.toString().padLeft(2, '0')}',
      title: '重叠作业 $index',
      kind: AgendaKind.deadline,
      startsAt: _date.add(const Duration(hours: 12)),
    ),
];

Future<TestAppController> _show(
  WidgetTester tester,
  List<AgendaEntry> entries, {
  double scale = 1,
  Brightness brightness = Brightness.light,
  ValueNotifier<bool>? visible,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final app = TestAppController(entries: entries);
  await app.initialize();
  final visibility = visible ?? ValueNotifier(true);
  if (visible == null) addTearDown(visibility.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: bitreeTheme(brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: ValueListenableBuilder<bool>(
          valueListenable: visibility,
          builder: (context, isVisible, _) => AgendaTimeline(
            controller: app.agenda,
            entries: entries,
            now: _date.add(const Duration(hours: 12)),
            visible: isVisible,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return app;
}

ScrollPosition _lanePosition(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(
        of: find.byKey(const ValueKey('agenda-timeline-lanes')),
        matching: find.byType(Scrollable),
      ),
    )
    .position;

Future<void> _wheel(
  WidgetTester tester,
  Offset delta, {
  bool vertical = false,
}) async {
  if (vertical) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  tester.binding.handlePointerEvent(
    PointerScrollEvent(
      position: tester.getCenter(
        find.byKey(const ValueKey('agenda-timeline-lanes')),
      ),
      scrollDelta: delta,
    ),
  );
  await tester.pumpAndSettle();
  if (vertical) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
}

void main() {
  for (final bottom in [false, true]) {
    testWidgets(
      'Horizontal panning preserves a held ${bottom ? 'bottom' : 'top'} overscroll',
      (tester) async {
        final entries = [
          ..._stackedDeadlines(),
          for (var index = 0; index < 25; index++)
            AgendaEntry(
              id: 'future-$index',
              title: '后续作业 $index',
              kind: AgendaKind.deadline,
              startsAt: _date.add(const Duration(days: 10, hours: 12)),
            ),
        ];
        await _show(tester, entries);
        final position = _lanePosition(tester);
        if (bottom) {
          position.jumpTo(position.maxScrollExtent);
          await tester.pumpAndSettle();
        }
        final dy = bottom ? -1.0 : 1.0;
        final gesture = await tester.startGesture(const Offset(330, 500));
        var released = false;
        try {
          await gesture.moveBy(Offset(0, dy * 30));
          await tester.pump(const Duration(milliseconds: 16));
          await gesture.moveBy(Offset(0, dy * 180));
          await tester.pump(const Duration(milliseconds: 16));
          final heldOffset = position.pixels;
          final maximum = position.maxScrollExtent;
          expect(
            heldOffset,
            bottom ? greaterThan(maximum + 10) : lessThan(-10),
          );
          final tracked = bottom ? entries[23] : entries.first;
          final heldTop = tester.getRect(_paintedBar(tracked)).top;

          for (var frame = 0; frame < 36; frame++) {
            await gesture.moveBy(const Offset(-4, 0));
            await tester.pump(const Duration(milliseconds: 16));
            expect(
              position.pixels,
              closeTo(heldOffset, .01),
              reason:
                  'frame=$frame, originalMax=$maximum, currentMax=${position.maxScrollExtent}',
            );
            expect(
              tester.getRect(_paintedBar(tracked)).top,
              closeTo(heldTop, .01),
            );
          }
          expect(position.maxScrollExtent, greaterThan(maximum));
          await gesture.up();
          released = true;
          await tester.pumpAndSettle();
          expect(
            position.pixels,
            closeTo(bottom ? position.maxScrollExtent : 0, .01),
          );
          expect(tester.takeException(), isNull);
        } finally {
          if (!released) await gesture.cancel();
          await tester.pumpAndSettle();
          await tester.pumpWidget(const SizedBox());
        }
      },
    );
  }

  testWidgets(
    'Background refreshes keep vertical position during horizontal drags',
    (tester) async {
      final entries = [
        for (var day = 0; day < 24; day++)
          for (var index = 0; index < (day == 0 || day == 22 ? 24 : 2); index++)
            AgendaEntry(
              id: 'frame-$day-$index',
              title: '作业 $day $index',
              kind: AgendaKind.deadline,
              startsAt: _date.add(Duration(days: day, hours: 12)),
            ),
      ];
      final app = await _show(tester, entries);
      late StateSetter refresh;
      await tester.pumpWidget(
        MaterialApp(
          theme: bitreeTheme(Brightness.light),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                refresh = setState;
                return AgendaTimeline(
                  controller: app.agenda,
                  entries: entries.toList(),
                  now: _date.add(const Duration(hours: 12)),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final position = _lanePosition(tester);
      position.jumpTo(position.maxScrollExtent * .8);
      await tester.pumpAndSettle();
      for (var swipe = 0; swipe < 4; swipe++) {
        final direction = swipe.isEven ? -1.0 : 1.0;
        final gesture = await tester.startGesture(const Offset(200, 600));
        await gesture.moveBy(Offset(direction * 24, 0));
        await tester.pump(const Duration(milliseconds: 16));
        for (var frame = 0; frame < 36; frame++) {
          final before = position.pixels;
          await gesture.moveBy(Offset(direction * 12, 0));
          refresh(() {});
          await tester.pump(const Duration(milliseconds: 16));
          expect(
            position.pixels,
            closeTo(before, .01),
            reason:
                'swipe=$swipe frame=$frame, offset=$before -> ${position.pixels}, max=${position.maxScrollExtent}',
          );
        }
        await gesture.cancel();
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Panning reuses the visible deadline content', (tester) async {
    final entries = _stackedDeadlines();
    await _show(tester, entries);
    final tracked = entries[4];
    final before = tester.getRect(_paintedBar(tracked));
    final previousCallback = debugOnRebuildDirtyWidget;
    var contentBuilds = 0;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      previousCallback?.call(element, builtOnce);
      if (element.widget case AgendaTimelineEntry(:final entry)
          when entry.id == tracked.id) {
        contentBuilds++;
      }
    };
    addTearDown(() => debugOnRebuildDirtyWidget = previousCallback);

    final gesture = await tester.startGesture(const Offset(340, 650));
    await gesture.moveBy(const Offset(-24, -24));
    await tester.pump(const Duration(milliseconds: 16));
    contentBuilds = 0;
    for (var frame = 0; frame < 12; frame++) {
      await gesture.moveBy(const Offset(-3, -1));
      await tester.pump(const Duration(milliseconds: 16));
    }
    final after = tester.getRect(_paintedBar(tracked));
    expect(after.left, lessThan(before.left));
    expect(after.top, lessThan(before.top));
    expect(contentBuilds, 0);
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Retained cards update their time, completion and text scale', (
    tester,
  ) async {
    final entry = _stackedDeadlines().first;
    final app = await _show(tester, [entry]);
    var entries = [entry];
    var now = _date.add(const Duration(hours: 11));
    var scale = 1.0;
    var brightness = Brightness.light;
    late StateSetter update;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return MaterialApp(
            theme: bitreeTheme(brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: AgendaTimeline(
                controller: app.agenda,
                entries: entries,
                now: now,
              ),
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('12:00 已逾期'), findsNothing);
    update(() => now = _date.add(const Duration(hours: 13)));
    await tester.pumpAndSettle();
    expect(find.text('12:00 已逾期'), findsOneWidget);

    update(() {
      entries = [entry.copyWith(done: true)];
      brightness = Brightness.dark;
      scale = 1.6;
    });
    await tester.pumpAndSettle();
    expect(find.text('12:00 已逾期'), findsNothing);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    expect(
      tester.widget<Text>(find.text(entry.title)).style!.decoration,
      TextDecoration.lineThrough,
    );
    expect(
      tester
          .getSize(find.byKey(ValueKey(('agenda-timeline-card', entry.id))))
          .width,
      closeTo(144 * scale, .001),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('Minimum display spans separate short events without changing their real times', () {
    final first = _event('first', 11);
    final second = _event('second', 14, exam: true);
    final entries = [first, second];
    final zoomedOut = layoutAgendaTimeline(
      entries,
      minimumEventSpan: const Duration(hours: 48),
      deadlineCardSpan: const Duration(days: 2),
      deadlineTailDaySpan: const Duration(days: 1),
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
      deadlineCardSpan: const Duration(hours: 2),
      deadlineTailDaySpan: const Duration(hours: 1),
    );
    expect(zoomedIn.map((placement) => placement.lane), [0, 0]);
    expect(zoomedIn.map((placement) => placement.end), [
      first.endsAt,
      second.endsAt,
    ]);
  });

  test('Long events and DDL endpoints retain their real times', () {
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
    final placements = layoutAgendaTimeline(
      [long, ddl],
      minimumEventSpan: const Duration(days: 2),
      deadlineCardSpan: const Duration(days: 2),
      deadlineTailDaySpan: const Duration(days: 1),
    );
    final eventPlacement = placements.singleWhere(
      (placement) => placement.entry == long,
    );
    final deadlinePlacement = placements.singleWhere(
      (placement) => placement.entry == ddl,
    );
    expect(eventPlacement.layoutEnd, long.endsAt);
    expect(
      deadlinePlacement.start,
      ddl.dueAt.subtract(const Duration(days: 2)),
    );
    expect(
      deadlinePlacement.paintStart,
      ddl.dueAt.subtract(const Duration(days: 3, hours: 18)),
    );
    expect(deadlinePlacement.layoutEnd, ddl.dueAt);
  });

  for (final days in [1, 7, 14]) {
    test('A $days-day DDL tail yields to another card in the same lane', () {
      final ddl = AgendaEntry(
        id: 'custom',
        title: '作业',
        kind: AgendaKind.deadline,
        startsAt: _date,
        allDay: true,
        tailDays: days,
      );
      final overlapping = AgendaEntry(
        id: 'overlap',
        title: '日程',
        kind: AgendaKind.event,
        startsAt: ddl.dueAt.subtract(const Duration(hours: 12)),
        endsAt: ddl.dueAt.subtract(const Duration(hours: 10)),
      );
      final placements = layoutAgendaTimeline(
        [ddl, overlapping],
        minimumEventSpan: const Duration(minutes: 1),
        deadlineCardSpan: const Duration(hours: 6),
        deadlineTailDaySpan: const Duration(days: 1),
      );
      final reservation = placements.singleWhere((p) => p.entry == ddl);
      expect(reservation.start, ddl.dueAt.subtract(const Duration(hours: 6)));
      expect(reservation.paintStart, overlapping.endsAt);
      expect(reservation.end, ddl.dueAt);
      expect(placements.map((p) => p.lane).toSet(), hasLength(1));
    });

    testWidgets('A $days-day DDL tail keeps its configured width on zoom', (
      tester,
    ) async {
      final ddl = AgendaEntry(
        id: 'custom',
        title: '作业',
        kind: AgendaKind.deadline,
        startsAt: _date.add(const Duration(hours: 13)),
        tailDays: days,
      );
      await _show(tester, [ddl]);
      final before = tester.getRect(_paintedBar(ddl));
      expect(before.width, closeTo(math.max(144, 48 * (days - .25)), .001));
      tester.widget<Slider>(find.byType(Slider)).onChanged!(24);
      await tester.pumpAndSettle();
      final after = tester.getRect(_paintedBar(ddl));
      expect(after.width, closeTo(before.width, .001));
      expect(after.right, closeTo(243, .001));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('Long DDL tails stay visible when the deadline is off screen', (
    tester,
  ) async {
    final ddl = AgendaEntry(
      id: 'future',
      title: '下周作业',
      kind: AgendaKind.deadline,
      startsAt: _date.add(const Duration(days: 7)),
      tailDays: 14,
    );
    await _show(tester, [ddl]);
    final viewport = tester.getRect(find.byType(AgendaTimeline));
    final tail = tester.getRect(_paintedBar(ddl));
    expect(tail.right, greaterThan(viewport.right));
    expect(tail.left, lessThan(viewport.right));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
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
          expect(
            rectangles.last.width,
            closeTo(math.max(180, 144 * scale), .001),
          );
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
    'Dense-to-sparse panning holds the vertical position until the user scrolls up',
    (tester) async {
      final entries = [
        for (var index = 0; index < 20; index++)
          AgendaEntry(
            id: 'dense-$index',
            title: '密集日程 $index',
            kind: AgendaKind.event,
            startsAt: _date.add(Duration(hours: 11, minutes: index)),
            endsAt: _date.add(const Duration(hours: 14)),
          ),
        AgendaEntry(
          id: 'sparse',
          title: '后续日程',
          kind: AgendaKind.event,
          startsAt: _date.add(const Duration(days: 12, hours: 11)),
          endsAt: _date.add(const Duration(days: 12, hours: 14)),
        ),
      ];
      await _show(tester, entries);
      final position = _lanePosition(tester);
      final denseMaximum = position.maxScrollExtent;
      expect(denseMaximum, greaterThan(200));
      position.jumpTo(denseMaximum * .75);
      await tester.pumpAndSettle();
      final before = position.pixels;

      await _wheel(tester, const Offset(48 * 12, 0));
      expect(_paintedBar(entries.last), findsNothing);
      expect(position.pixels, closeTo(before, .01));
      expect(position.maxScrollExtent, closeTo(before, .01));

      await _wheel(tester, const Offset(0, -80), vertical: true);
      final tightened = position.pixels;
      expect(tightened, closeTo(before - 80, .01));
      expect(position.maxScrollExtent, closeTo(tightened, .01));
      await _wheel(tester, const Offset(0, 250), vertical: true);
      expect(position.pixels, closeTo(tightened, .01));

      await _wheel(tester, const Offset(0, -2000), vertical: true);
      expect(position.pixels, 0);
      expect(position.maxScrollExtent, 0);
      expect(_paintedBar(entries.last), findsOneWidget);

      await _wheel(tester, const Offset(-48 * 12, 0));
      expect(position.pixels, 0);
      expect(position.maxScrollExtent, closeTo(denseMaximum, .01));
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      final viewport = tester.getRect(
        find.byKey(const ValueKey('agenda-timeline-lanes')),
      );
      final lastCard = tester.getRect(_paintedBar(entries[19]));
      final laneHeight = lastCard.height + 12;
      expect(
        viewport.bottom - lastCard.bottom,
        inInclusiveRange(laneHeight, laneHeight + 24),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final cancel in [false, true]) {
    testWidgets(
      'Repeated top-edge pulls rebound after ${cancel ? 'cancellation' : 'release'}',
      (tester) async {
        await _show(tester, []);
        final position = _lanePosition(tester);
        for (var attempt = 0; attempt < 3; attempt++) {
          final gesture = await tester.startGesture(const Offset(200, 180));
          await gesture.moveBy(const Offset(0, 30));
          await tester.pump(const Duration(milliseconds: 40));
          await gesture.moveBy(const Offset(0, 80));
          await tester.pump(const Duration(milliseconds: 40));
          expect(position.pixels, lessThan(0));
          if (cancel) {
            await gesture.cancel();
          } else {
            await gesture.up();
          }
          await tester.pumpAndSettle();
          expect(position.pixels, closeTo(0, .01));
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'Pulling past the bottom rebounds without growing the blank range',
    (tester) async {
      final entries = [
        for (var index = 0; index < 20; index++)
          AgendaEntry(
            id: 'bottom-$index',
            title: '重叠日程 $index',
            kind: AgendaKind.event,
            startsAt: _date.add(const Duration(hours: 11)),
            endsAt: _date.add(const Duration(hours: 14)),
          ),
      ];
      await _show(tester, entries);
      final position = _lanePosition(tester);
      final maximum = position.maxScrollExtent;
      position.jumpTo(maximum);
      await tester.pumpAndSettle();
      for (final cancel in [false, true]) {
        final gesture = await tester.startGesture(const Offset(200, 600));
        await gesture.moveBy(const Offset(0, -30));
        await tester.pump(const Duration(milliseconds: 40));
        await gesture.moveBy(const Offset(0, -80));
        await tester.pump(const Duration(milliseconds: 40));
        expect(position.pixels, greaterThan(maximum));
        expect(position.maxScrollExtent, closeTo(maximum, .01));
        if (cancel) {
          await gesture.cancel();
        } else {
          await gesture.up();
        }
        await tester.pumpAndSettle();
        expect(position.pixels, closeTo(maximum, .01));
        expect(position.maxScrollExtent, closeTo(maximum, .01));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'A top-edge pull settles when the timeline is hidden and shown again',
    (tester) async {
      final visible = ValueNotifier(true);
      addTearDown(visible.dispose);
      await _show(tester, [], visible: visible);
      final position = _lanePosition(tester);
      final gesture = await tester.startGesture(const Offset(200, 180));
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump(const Duration(milliseconds: 40));
      await gesture.moveBy(const Offset(0, 80));
      await tester.pump(const Duration(milliseconds: 40));
      expect(position.pixels, lessThan(0));
      visible.value = false;
      await tester.pump();
      await gesture.cancel();
      visible.value = true;
      await tester.pumpAndSettle();
      expect(position.pixels, closeTo(0, .01));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Wheel and zoom interruptions cannot leave a top-edge pull held',
    (tester) async {
      await _show(tester, []);
      final position = _lanePosition(tester);
      for (final zoom in [false, true]) {
        final gesture = await tester.startGesture(const Offset(200, 180));
        await gesture.moveBy(const Offset(0, 30));
        await tester.pump(const Duration(milliseconds: 40));
        await gesture.moveBy(const Offset(0, 80));
        await tester.pump(const Duration(milliseconds: 40));
        expect(position.pixels, lessThan(0));
        if (zoom) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await _wheel(tester, const Offset(48, 0));
        if (zoom) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        expect(position.pixels, closeTo(0, .01));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(position.pixels, closeTo(0, .01));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('DDL cards share lanes without their tails stealing taps', (
    tester,
  ) async {
    final first = AgendaEntry(
      id: 'first-ddl',
      title: '第一份作业',
      kind: AgendaKind.deadline,
      startsAt: _date.add(const Duration(hours: 13)),
    );
    final second = AgendaEntry(
      id: 'second-ddl',
      title: '第二份作业',
      kind: AgendaKind.deadline,
      startsAt: _date.add(const Duration(days: 3, hours: 13)),
    );
    await _show(tester, [first, second]);
    final firstCard = tester.getRect(_bar(first));
    final secondCard = tester.getRect(_bar(second));
    expect(firstCard.top, secondCard.top);
    expect(firstCard.overlaps(secondCard), isFalse);
    final firstTail = tester.getRect(_paintedBar(first));
    final secondTail = tester.getRect(_paintedBar(second));
    expect(secondTail.left, greaterThanOrEqualTo(firstCard.right - .01));
    expect(firstTail.left, lessThan(firstCard.left));
    await tester.tapAt(Offset(firstCard.left - 10, firstCard.center.dy));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    await tester.tapAt(firstCard.center);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Diagonal touch panning preserves direction while releasing blank range',
    (tester) async {
      final entries = _stackedDeadlines();
      await _show(tester, entries);
      final position = _lanePosition(tester);
      final maximum = position.maxScrollExtent;
      expect(maximum, greaterThan(0));
      position.jumpTo(maximum / 2);
      await tester.pumpAndSettle();
      final initialOffset = position.pixels;
      expect(
        entries.any((entry) => _paintedBar(entry).evaluate().isNotEmpty),
        isTrue,
      );

      final viewport = tester.getRect(
        find.byKey(const ValueKey('agenda-timeline-lanes')),
      );
      // Start in blank space to the right of the DDLs, not on an InkWell.
      // At 48px/day these steps move every DDL entirely out of the time window.
      final gesture = await tester.startGesture(
        Offset(viewport.right - 40, viewport.bottom - 80),
        kind: PointerDeviceKind.touch,
      );
      var previousOffset = initialOffset;
      for (var step = 1; step <= 16; step++) {
        await gesture.moveBy(
          const Offset(-20, -3),
          timeStamp: Duration(milliseconds: step * 32),
        );
        await tester.pump(const Duration(milliseconds: 32));
        expect(position.maxScrollExtent, lessThanOrEqualTo(maximum + .001));
        expect(position.pixels, greaterThanOrEqualTo(previousOffset - .001));
        previousOffset = position.pixels;
      }
      expect(position.pixels, greaterThan(initialOffset));
      for (final entry in entries) {
        expect(_paintedBar(entry), findsNothing);
      }

      final offsetBeforeReturn = position.pixels;
      for (var step = 17; step <= 32; step++) {
        await gesture.moveBy(
          const Offset(20, 3),
          timeStamp: Duration(milliseconds: step * 32),
        );
        await tester.pump(const Duration(milliseconds: 32));
        expect(position.maxScrollExtent, lessThanOrEqualTo(maximum + .001));
        expect(position.pixels, lessThanOrEqualTo(previousOffset + .001));
        previousOffset = position.pixels;
      }
      expect(position.pixels, lessThan(offsetBeforeReturn));
      expect(position.pixels, greaterThan(0));
      expect(
        entries.any((entry) => _paintedBar(entry).evaluate().isNotEmpty),
        isTrue,
      );
      // Cancel instead of releasing: this isolates drag/range behaviour from
      // velocity estimation and from how long a simulated fling takes to stop.
      await gesture.cancel();
      await tester.pumpAndSettle();
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(_paintedBar(entries.last), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Filtering a deep timeline culls at the newly clamped offset', (
    tester,
  ) async {
    final entries = [
      for (var index = 0; index < 24; index++)
        AgendaEntry(
          id: 'filtered-$index',
          title: '重叠作业 $index',
          kind: AgendaKind.deadline,
          startsAt: _date.add(const Duration(hours: 12)),
          term: index == 23 ? 'selected' : 'other',
        ),
    ];
    final app = await _show(tester, entries);
    var filtered = entries;
    String? selectedTerm;
    late StateSetter updateEntries;
    // Retain the same timeline State when the filtered data changes.
    await tester.pumpWidget(
      MaterialApp(
        theme: bitreeTheme(Brightness.light),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (_, setState) {
              updateEntries = setState;
              return AgendaTimeline(
                controller: app.agenda,
                entries: filtered,
                now: _date.add(const Duration(hours: 12)),
                filter: (kind: null, term: selectedTerm),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final timelineState = tester.state(find.byType(AgendaTimeline));
    final position = _lanePosition(tester);
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(0));
    expect(_paintedBar(entries.last), findsOneWidget);

    updateEntries(() {
      selectedTerm = 'selected';
      filtered = entries.where((entry) => entry.term == selectedTerm).toList();
    });
    // Check the first layout, not pumpAndSettle: a later unrelated rebuild
    // must not be required to recover cards culled using an obsolete offset.
    await tester.pump();
    expect(tester.state(find.byType(AgendaTimeline)), same(timelineState));
    expect(position.maxScrollExtent, 0);
    expect(position.pixels, 0);
    expect(_paintedBar(entries.last), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Growing the viewport culls at the newly clamped offset', (
    tester,
  ) async {
    final entries = _stackedDeadlines();
    await _show(tester, entries);
    final position = _lanePosition(tester);
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(0));
    expect(_paintedBar(entries.first), findsNothing);

    tester.view.physicalSize = const Size(390, 2200);
    await tester.pump();
    expect(position.maxScrollExtent, 0);
    expect(position.pixels, 0);
    expect(_paintedBar(entries.first), findsOneWidget);
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
