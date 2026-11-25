import 'package:bitree/agenda/model.dart';
import 'package:bitree/agenda/timeline_layout.dart';
import 'package:bitree/agenda/ui/agenda_timeline.dart';
import 'package:bitree/agenda/ui/event_timeline_entry.dart';
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

String _startPreview(AgendaEntry entry) {
  final l10n = AppLocalizationsZh();
  return l10n.agendaTimelineStarts(localizedAgendaDateTime(l10n, entry.startsAt));
}

String _endPreview(AgendaEntry entry) {
  final l10n = AppLocalizationsZh();
  return l10n.agendaTimelineEnds(localizedAgendaDateTime(l10n, entry.endsAt!));
}

List<AgendaEntry> _stackedDeadlines() => [
  for (var index = 0; index < 24; index++)
    AgendaEntry(
      id: 'stacked-${index.toString().padLeft(2, '0')}',
      title: '重叠作业 $index',
      kind: AgendaKind.deadline,
      startsAt: _date.add(const Duration(hours: 12)),
    ),
];

ScrollPosition _lanePosition(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(
        of: find.byKey(const ValueKey('agenda-timeline-lanes')),
        matching: find.byType(Scrollable),
      ),
    )
    .position;

Future<TestAppController> _show(
  WidgetTester tester,
  List<AgendaEntry> entries, {
  double scale = 1,
  Brightness brightness = Brightness.light,
  int layoutDays = 4,
  ValueNotifier<bool>? visible,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final app = TestAppController(entries: entries);
  await app.initialize();
  await app.settings.setAgendaLayoutDays(layoutDays);
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
            controller: app,
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
              startsAt: _date.add(const Duration(days: 20, hours: 12)),
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
          expect(position.maxScrollExtent, closeTo(maximum, .01));
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
          for (var index = 0; index < (day % 3 == 0 ? 24 : 2); index++)
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
                  controller: app,
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
                controller: app,
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
          .getSize(_paintedBar(entry))
          .width,
      closeTo(180, .001),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Marking done keeps lanes until the page is re-entered', (
    tester,
  ) async {
    AgendaEntry ddl(String id) => AgendaEntry(
      id: id,
      title: '作业 $id',
      kind: AgendaKind.deadline,
      startsAt: _date.add(const Duration(hours: 12)),
    );
    final first = ddl('a');
    final second = ddl('b');
    final app = await _show(tester, [first, second]);
    var entries = [first, second];
    var active = true;
    late StateSetter update;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return MaterialApp(
            theme: bitreeTheme(Brightness.light),
            home: Scaffold(
              body: AgendaTimeline(
                controller: app,
                entries: entries,
                now: _date.add(const Duration(hours: 11)),
                active: active,
              ),
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    final firstTop = tester.getRect(_paintedBar(first)).top;
    final secondTop = tester.getRect(_paintedBar(second)).top;
    expect(firstTop, lessThan(secondTop));

    // An in-page completion must not reshuffle the retained lanes — even
    // though controller.save re-appends the touched entry, changing the
    // list order while the multiset stays the same.
    update(() => entries = [second, first.copyWith(done: true)]);
    await tester.pumpAndSettle();
    expect(tester.getRect(_paintedBar(first)).top, closeTo(firstTop, .001));
    expect(tester.getRect(_paintedBar(second)).top, closeTo(secondTop, .001));

    // Leaving and re-entering the page re-sorts with the new priorities.
    update(() => active = false);
    await tester.pumpAndSettle();
    update(() => active = true);
    await tester.pumpAndSettle();
    expect(tester.getRect(_paintedBar(second)).top, closeTo(firstTop, .001));
    expect(tester.getRect(_paintedBar(first)).top, closeTo(secondTop, .001));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Zooming reuses unchanged deadline text', (tester) async {
    final entries = _stackedDeadlines();
    await _show(tester, entries);
    final tracked = entries[4];
    final initialTop = tester.getRect(_paintedBar(tracked)).top;
    final previousCallback = debugOnRebuildDirtyWidget;
    var titleBuilds = 0;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      previousCallback?.call(element, builtOnce);
      if (element.widget case Text(data: final text)
          when text == tracked.title) {
        titleBuilds++;
      }
    };
    addTearDown(() => debugOnRebuildDirtyWidget = previousCallback);

    for (final zoom in [2.0, 4.0, 8.0, 16.0, 24.0, 12.0, 4.0, 1.0]) {
      tester.widget<Slider>(find.byType(Slider)).onChanged!(zoom);
      await tester.pumpAndSettle();
      expect(titleBuilds, 0);
      expect(
        tester.getRect(_paintedBar(tracked)).top,
        closeTo(initialTop, .001),
      );
      expect(
        tester.getRect(_paintedBar(tracked)).width,
        closeTo(180, .001),
      );
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Zoom keeps mixed entries in their original lanes', (
    tester,
  ) async {
    final entries = [
      for (final hour in [12, 14, 16])
        AgendaEntry(
          id: 'zoom-ddl-$hour',
          title: '作业 $hour',
          kind: AgendaKind.deadline,
          startsAt: _date.add(Duration(hours: hour)),
        ),
      _event('zoom-event', 10),
      AgendaEntry(
        id: 'zoom-open',
        title: '开放测验',
        kind: AgendaKind.deadline,
        startsAt: _date.add(const Duration(hours: 13)),
        startOnly: true,
      ),
    ];
    await _show(tester, entries);
    final originalTops = {
      for (final entry in entries)
        entry.id: tester.getRect(_paintedBar(entry)).top,
    };
    for (final zoom in [1.5, 4.0, 12.0, 24.0, 8.0, 2.0, 1.0]) {
      tester.widget<Slider>(find.byType(Slider)).onChanged!(zoom);
      await tester.pumpAndSettle();
      for (final entry in entries) {
        expect(
          tester.getRect(_paintedBar(entry)).top,
          closeTo(originalTops[entry.id]!, .001),
          reason: '${entry.id}, zoom=$zoom',
        );
      }
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Pinching preserves lanes, focal time and the vertical position',
    (tester) async {
      final first = AgendaEntry(
        id: 'pinch-first',
        title: '第一份作业',
        kind: AgendaKind.deadline,
        startsAt: _date.add(const Duration(hours: 12)),
      );
      final second = AgendaEntry(
        id: 'pinch-second',
        title: '第二份作业',
        kind: AgendaKind.deadline,
        startsAt: _date.add(const Duration(hours: 12, minutes: 30)),
      );
      await _show(tester, [first, second]);
      final originalTop = tester.getRect(_paintedBar(second)).top;
      final left = await tester.startGesture(
        const Offset(185, 600),
        pointer: 1,
      );
      final right = await tester.startGesture(
        const Offset(205, 600),
        pointer: 2,
      );
      await left.moveTo(const Offset(160, 600));
      await right.moveTo(const Offset(230, 600));
      await tester.pump();
      final initialZoom = tester.widget<Slider>(find.byType(Slider)).value;
      final initialRight = tester.getRect(_paintedBar(first)).right;
      final initialOffset = _lanePosition(tester).pixels;
      for (var step = 1; step <= 14; step++) {
        await left.moveTo(Offset(160 - step * 10, 600));
        await right.moveTo(Offset(230 + step * 10, 600));
        await tester.pump(const Duration(milliseconds: 16));
        final zoom = tester.widget<Slider>(find.byType(Slider)).value;
        expect(
          tester.getRect(_paintedBar(first)).right,
          closeTo(195 + (initialRight - 195) * zoom / initialZoom, .01),
        );
        expect(
          tester.getRect(_paintedBar(second)).top,
          closeTo(originalTop, .01),
        );
        expect(_lanePosition(tester).pixels, closeTo(initialOffset, .01));
      }
      await right.up();
      await tester.pump();
      final beforeRelease = tester.getRect(_paintedBar(first)).right;
      await left.up();
      await tester.pumpAndSettle();
      expect(
        tester.getRect(_paintedBar(first)).right,
        closeTo(beforeRelease, .01),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Ctrl-wheel zoom keeps the pointer time anchored', (
    tester,
  ) async {
    final ddl = AgendaEntry(
      id: 'wheel-zoom',
      title: '作业',
      kind: AgendaKind.deadline,
      startsAt: _date.add(const Duration(hours: 13)),
    );
    await _show(tester, [ddl]);
    const anchor = Offset(140, 600);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    for (final delta in [-100.0, -200.0, -250.0, 150.0, 200.0]) {
      final before = tester.getRect(_paintedBar(ddl));
      final previousZoom = tester.widget<Slider>(find.byType(Slider)).value;
      tester.binding.handlePointerEvent(
        PointerScrollEvent(position: anchor, scrollDelta: Offset(0, delta)),
      );
      await tester.pumpAndSettle();
      final zoom = tester.widget<Slider>(find.byType(Slider)).value;
      final after = tester.getRect(_paintedBar(ddl));
      expect(
        after.right,
        closeTo(
          anchor.dx + (before.right - anchor.dx) * zoom / previousZoom,
          .01,
        ),
      );
      expect(after.top, closeTo(before.top, .01));
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

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

  test('Event information reservations keep real endpoints and minimum hit spans', () {
    final first = _event('first', 11);
    final second = _event('second', 14, exam: true);
    final entries = [first, second];
    final zoomedOut = layoutAgendaTimeline(
      entries,
      minimumEventSpan: const Duration(hours: 48),
      now: _date,
    );
    final eventLead = Duration(
      microseconds:
          (Duration.microsecondsPerDay *
                  (AgendaTimelineLayout.defaultEventInfoDays +
                      AgendaTimelineLayout.eventInfoGutterDays))
              .round(),
    );
    final outFirst = zoomedOut.singleWhere((p) => p.entry == first);
    final outSecond = zoomedOut.singleWhere((p) => p.entry == second);
    // Live exams claim the top lane over ordinary live events.
    expect(outSecond.lane, 0);
    expect(outFirst.lane, 1);
    expect(outFirst.start, first.startsAt.subtract(eventLead));
    expect(outFirst.end, first.endsAt);
    expect(
      outFirst.layoutEnd,
      first.startsAt.add(const Duration(hours: 48)),
    );
    final zoomedIn = layoutAgendaTimeline(
      entries,
      minimumEventSpan: const Duration(hours: 2),
      now: _date,
    );
    final inFirst = zoomedIn.singleWhere((p) => p.entry == first);
    final inSecond = zoomedIn.singleWhere((p) => p.entry == second);
    // Their real intervals do not overlap, but the compact information
    // reservations do, independently of the minimum hit-target span.
    expect(inSecond.lane, 0);
    expect(inFirst.lane, 1);
    expect(inFirst.start, first.startsAt.subtract(eventLead));
    expect(
      inFirst.layoutEnd,
      first.startsAt.add(const Duration(hours: 2)),
    );
    expect(inFirst.end, first.endsAt);
    expect(inSecond.end, second.endsAt);
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
    ], minimumEventSpan: const Duration(days: 2), now: _date);
    final eventPlacement = placements.singleWhere(
      (placement) => placement.entry == long,
    );
    final deadlinePlacement = placements.singleWhere(
      (placement) => placement.entry == ddl,
    );
    final eventLead = Duration(
      microseconds:
          (Duration.microsecondsPerDay *
                  (AgendaTimelineLayout.defaultEventInfoDays +
                      AgendaTimelineLayout.eventInfoGutterDays))
              .round(),
    );
    final ddlSpan = Duration(
      microseconds:
          (Duration.microsecondsPerDay * (AgendaEntry.defaultTailDays - .25))
              .round(),
    );
    expect(eventPlacement.start, long.startsAt.subtract(eventLead));
    expect(eventPlacement.end, long.endsAt);
    expect(eventPlacement.layoutEnd, long.endsAt);
    expect(deadlinePlacement.start, ddl.dueAt.subtract(ddlSpan));
    expect(deadlinePlacement.layoutEnd, ddl.dueAt);
  });

  test('Live DDLs claim the top lanes over done ones', () {
    final finished = AgendaEntry(
      id: 'finished',
      title: '已完成作业',
      kind: AgendaKind.deadline,
      startsAt: _date.add(const Duration(hours: 12)),
      done: true,
    );
    final live = AgendaEntry(
      id: 'live',
      title: '未完成作业',
      kind: AgendaKind.deadline,
      startsAt: _date.add(const Duration(hours: 12)),
    );
    final placements = layoutAgendaTimeline(
      [finished, live],
      minimumEventSpan: const Duration(minutes: 1),
      now: _date,
    );
    expect(placements.singleWhere((p) => p.entry == live).lane, 0);
    expect(placements.singleWhere((p) => p.entry == finished).lane, 1);
  });

  test('A start-only DDL sinks once ticked off', () {
    final ticked = AgendaEntry(
      id: 'ticked',
      title: '已交测验',
      kind: AgendaKind.deadline,
      startsAt: _date.add(const Duration(hours: 10)),
      startOnly: true,
      done: true,
    );
    final open = AgendaEntry(
      id: 'open',
      title: '开放测验',
      kind: AgendaKind.deadline,
      startsAt: _date.add(const Duration(hours: 10)),
      startOnly: true,
    );
    final placements = layoutAgendaTimeline(
      [ticked, open],
      minimumEventSpan: const Duration(minutes: 1),
      now: _date,
    );
    expect(placements.singleWhere((p) => p.entry == open).lane, 0);
    expect(placements.singleWhere((p) => p.entry == ticked).lane, 1);
  });

  test('Unfinished events outrank ended ones even when they start later', () {
    final ended = AgendaEntry(
      id: 'ended',
      title: '已结束的日程',
      kind: AgendaKind.event,
      startsAt: _date.subtract(const Duration(days: 1)),
      endsAt: _date.subtract(const Duration(hours: 1)),
    );
    final upcoming = AgendaEntry(
      id: 'upcoming',
      title: '数据结构考试',
      kind: AgendaKind.exam,
      startsAt: _date.add(const Duration(days: 2)),
      endsAt: _date.add(const Duration(days: 2, hours: 2)),
    );
    final placements = layoutAgendaTimeline(
      [ended, upcoming],
      minimumEventSpan: const Duration(minutes: 1),
      now: _date,
    );
    expect(placements.singleWhere((p) => p.entry == upcoming).lane, 0);
    expect(placements.singleWhere((p) => p.entry == ended).lane, 1);
  });

  test('Priority is best effort: a finished entry keeps a free top lane', () {
    final earlierLive = AgendaEntry(
      id: 'earlier-live',
      title: '较早的未完成作业',
      kind: AgendaKind.deadline,
      startsAt: _date.subtract(const Duration(days: 3)),
    );
    final laterFinished = AgendaEntry(
      id: 'later-finished',
      title: '较晚的已完成作业',
      kind: AgendaKind.deadline,
      startsAt: _date.add(const Duration(days: 1)),
      done: true,
    );
    final placements = layoutAgendaTimeline(
      [earlierLive, laterFinished],
      minimumEventSpan: const Duration(minutes: 1),
      now: _date,
    );
    expect(placements.map((p) => p.lane), everyElement(0));
  });

  test('A finished entry backfills a free span inside a live lane', () {
    final live = AgendaEntry(
      id: 'live-ahead',
      title: '远期作业',
      kind: AgendaKind.deadline,
      startsAt: _date.add(const Duration(days: 10)),
    );
    final finished = AgendaEntry(
      id: 'backfill',
      title: '补位日程',
      kind: AgendaKind.event,
      startsAt: _date,
      endsAt: _date.add(const Duration(hours: 1)),
    );
    final placements = layoutAgendaTimeline(
      [live, finished],
      minimumEventSpan: const Duration(minutes: 1),
      now: _date.add(const Duration(days: 2)),
    );
    final liveLane = placements.singleWhere((p) => p.entry == live).lane;
    expect(
      placements.singleWhere((p) => p.entry == finished).lane,
      liveLane,
    );
    expect(liveLane, 0);
  });

  test('A finished entry overlapping every live lane sinks below them', () {
    final first = AgendaEntry(
      id: 'live-one',
      title: '进行中日程',
      kind: AgendaKind.event,
      startsAt: _date.add(const Duration(hours: 12)),
      endsAt: _date.add(const Duration(hours: 18)),
    );
    final second = AgendaEntry(
      id: 'live-two',
      title: '进行中考点',
      kind: AgendaKind.event,
      startsAt: _date.add(const Duration(hours: 13)),
      endsAt: _date.add(const Duration(hours: 19)),
    );
    final finished = AgendaEntry(
      id: 'sunk',
      title: '结束于两条泳道之间',
      kind: AgendaKind.event,
      startsAt: _date.add(const Duration(hours: 12)),
      endsAt: _date.add(const Duration(hours: 13)),
    );
    final placements = layoutAgendaTimeline(
      [first, second, finished],
      minimumEventSpan: const Duration(minutes: 1),
      now: _date.add(const Duration(hours: 16)),
    );
    expect(
      placements.singleWhere((p) => p.entry == finished).lane,
      2,
    );
  });

  test('Two disjoint finished entries share one backfilled hole', () {
    final live = AgendaEntry(
      id: 'live-hole-host',
      title: '远期考试',
      kind: AgendaKind.exam,
      startsAt: _date.add(const Duration(days: 30, hours: 8)),
      endsAt: _date.add(const Duration(days: 32)),
    );
    final first = AgendaEntry(
      id: 'hole-one',
      title: '上午日程',
      kind: AgendaKind.event,
      startsAt: _date,
      endsAt: _date.add(const Duration(hours: 1)),
    );
    final second = AgendaEntry(
      id: 'hole-two',
      title: '一周后的上午日程',
      kind: AgendaKind.event,
      startsAt: _date.add(const Duration(days: 6)),
      endsAt: _date.add(const Duration(days: 6, hours: 1)),
    );
    final placements = layoutAgendaTimeline(
      [live, first, second],
      minimumEventSpan: const Duration(minutes: 1),
      now: _date.add(const Duration(days: 8)),
    );
    for (final entry in [live, first, second]) {
      expect(placements.singleWhere((p) => p.entry == entry).lane, 0);
    }
  });

  for (final days in [1, 7, 14]) {
    test('DDL lane reservations follow $days global layout days', () {
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
        startsAt: ddl.dueAt.subtract(Duration(days: days, hours: -7)),
        endsAt: ddl.dueAt.subtract(Duration(days: days, hours: -8)),
      );
      final placements = layoutAgendaTimeline(
        [
          ddl,
          overlapping,
        ],
        minimumEventSpan: const Duration(minutes: 1),
        now: _date,
        layoutDays: days,
      );
      final reservation = placements.singleWhere((p) => p.entry == ddl);
      final cardSpan = Duration(
        microseconds: (Duration.microsecondsPerDay * (days - .25)).round(),
      );
      expect(reservation.start, ddl.dueAt.subtract(cardSpan));
      expect(reservation.end, ddl.dueAt);
      expect(placements.map((p) => p.lane).toSet(), hasLength(2));
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
      await _show(tester, [ddl], layoutDays: days);
      final before = tester.getRect(_paintedBar(ddl));
      expect(before.width, closeTo(48 * (days - .25), .001));
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
    await _show(tester, [ddl], layoutDays: 14);
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
      'Short events keep fixed information cards and real time spans in $brightness, $scale',
      (tester) async {
        // Keep these intervals in the future at the fixed test clock so their
        // range caption is tested independently of overdue status formatting.
        final first = _event('first', 13);
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
        final initialEventWidths = <String, double>{};
        final maxEventWidth = 48 * 3.25 * scale.clamp(1.0, 1.35);
        void checkCards(double realIntervalWidth) {
          final rectangles = entries
              .map((entry) => tester.getRect(_paintedBar(entry)))
              .toList();
          for (var index = 0; index < rectangles.length; index++) {
            final entry = entries[index];
            if (entry.isDeadline) {
              expect(rectangles[index].width, closeTo(180, .001));
            } else {
              // Event/exam information cards stay compact and fixed across zoom.
              final expectedWidth = initialEventWidths.putIfAbsent(
                entry.id,
                () => rectangles[index].width,
              );
              expect(expectedWidth, greaterThanOrEqualTo(48 * 1.5 - .001));
              expect(expectedWidth, lessThanOrEqualTo(maxEventWidth + .001));
              expect(rectangles[index].width, closeTo(expectedWidth, .001));
            }
            expect(
              rectangles[index].height,
              closeTo(tester.getRect(_bar(entry)).height, .001),
            );
            for (var other = index + 1; other < rectangles.length; other++) {
              expect(rectangles[index].overlaps(rectangles[other]), isFalse);
            }
          }
          for (final entry in [first, second]) {
            final card = tester.widget<EventTimelineEntry>(
              find.byWidgetPredicate(
                (widget) => widget is EventTimelineEntry &&
                    widget.entry.id == entry.id,
              ),
            );
            final expectedWidth = initialEventWidths[entry.id]!;
            expect(card.informationWidth, closeTo(expectedWidth, .001));
            expect(
              card.geometry.startX - card.geometry.informationLeft,
              closeTo(expectedWidth, .001),
            );
            expect(
              card.geometry.endX - card.geometry.startX,
              closeTo(realIntervalWidth, .001),
            );
          }
          expect(
            tester.getSemantics(_bar(first)).label,
            contains('13:00–13:05'),
          );
          expect(tester.takeException(), isNull);
        }

        // At minimum zoom the five-minute real interval is below 2px. Its
        // markers stay at the actual times while the information area is wide.
        checkCards(2 * 5 / 60);
        tester.widget<Slider>(find.byType(Slider)).onChanged!(24);
        await tester.pumpAndSettle();
        checkCards(48 * 5 / 60);
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
        expect(first.endsAt, _date.add(const Duration(hours: 13, minutes: 5)));
        await tester.tap(find.byTooltip('关闭'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'A future event stays tappable while only its information tail is visible',
    (tester) async {
      final afterViewport = _date.add(const Duration(days: 5));
      final entry = AgendaEntry(
        id: 'edge',
        title: '边缘短日程',
        kind: AgendaKind.event,
        startsAt: afterViewport,
        endsAt: afterViewport.add(const Duration(minutes: 5)),
      );
      await _show(tester, [entry]);
      final viewport = tester.getRect(find.byType(AgendaTimeline));
      final painted = tester.getRect(_paintedBar(entry));
      expect(painted.width, greaterThanOrEqualTo(48 * 1.5 - .001));
      expect(painted.width, lessThanOrEqualTo(48 * 3.25 + .001));
      expect(painted.left, lessThan(viewport.right));
      expect(painted.right, greaterThan(viewport.right));
      final card = tester.getRect(_bar(entry));
      expect(card.right, lessThanOrEqualTo(viewport.right));
      expect(card.width, greaterThan(0));
      await tester.tapAt(Offset(viewport.right - 20, card.center.dy));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('An event wholly left of the viewport has no artificial 2px tail', (
    tester,
  ) async {
    final beforeViewport = _date
        .subtract(const Duration(days: 4))
        .add(const Duration(hours: 10));
    final entry = AgendaEntry(
      id: 'past-edge',
      title: '屏外短日程',
      kind: AgendaKind.event,
      startsAt: beforeViewport,
      endsAt: beforeViewport.add(const Duration(minutes: 5)),
    );
    await _show(tester, [entry]);
    expect(_paintedBar(entry), findsNothing);
    expect(_bar(entry), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Off-screen distant lanes collapse without rendering off-screen cards', (
    tester,
  ) async {
    final current = _event('current', 13);
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
    for (final entry in offScreen) {
      expect(_paintedBar(entry), findsNothing);
    }
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
    'Diagonal touch panning keeps the vertical direction across dense days',
    (tester) async {
      final entries = _stackedDeadlines();
      final trailing = [
        for (var index = 0; index < 24; index++)
          AgendaEntry(
            id: 'trailing-${index.toString().padLeft(2, '0')}',
            title: '后续重叠作业 $index',
            kind: AgendaKind.deadline,
            startsAt: _date.add(const Duration(days: 7, hours: 12)),
          ),
      ];
      await _show(tester, [...entries, ...trailing]);
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
        expect(position.maxScrollExtent, closeTo(maximum, .001));
        expect(
          position.pixels,
          greaterThanOrEqualTo(previousOffset - .001),
        );
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
        expect(position.maxScrollExtent, closeTo(maximum, .001));
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
    final entries = _stackedDeadlines();
    final app = await _show(tester, entries);
    var filtered = entries;
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
                controller: app,
                entries: filtered,
                now: _date.add(const Duration(hours: 12)),
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

    updateEntries(() => filtered = [entries.last]);
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
        find.textContaining(_startPreview(entry), findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining(_endPreview(entry), findRichText: true),
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
      find.textContaining(_startPreview(entry), findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining(_endPreview(entry), findRichText: true),
      findsOneWidget,
    );
    expect(find.byType(BottomSheet), findsNothing);
    await mouse.removePointer();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('Live exams claim top lanes and simultaneous course DDLs cluster cleanly', () {
    final now = DateTime.utc(2026, 12, 12, 12);
    final mooc = [
      for (var i = 0; i < 8; i++)
        AgendaEntry(
          id: 'mooc-$i',
          title: '慕课作业 $i',
          course: '大学物理',
          kind: AgendaKind.deadline,
          startsAt: DateTime.utc(2026, 12, 13, 23, 30),
        ),
    ];
    final numericalDdls = [
      for (var i = 4; i <= 6; i++)
        AgendaEntry(
          id: 'num-ch$i',
          title: '第$i章作业提交',
          course: '数值分析',
          kind: AgendaKind.deadline,
          startsAt: DateTime.utc(2026, 12, 16, 18, 28),
        ),
    ];
    final numericalExam = AgendaEntry(
      id: 'num-exam',
      title: '100086022[数值分析]',
      kind: AgendaKind.exam,
      startsAt: DateTime.utc(2026, 12, 16, 18, 30),
      endsAt: DateTime.utc(2026, 12, 16, 20, 30),
    );
    final placements = layoutAgendaTimeline(
      [...mooc, ...numericalDdls, numericalExam],
      minimumEventSpan: const Duration(minutes: 1),
      now: now,
    );
    final byId = {for (final p in placements) p.entry.id: p};
    // The live exam takes Lane 0 and does not collide with the 12/13 MOOC wave.
    expect(byId['num-exam']!.lane, 0);
    // The 3 simultaneous numerical-analysis DDLs stay contiguous right below it.
    final numLanes = [
      byId['num-ch4']!.lane,
      byId['num-ch5']!.lane,
      byId['num-ch6']!.lane,
    ]..sort();
    expect(numLanes, [1, 2, 3]);
    // And none of the 12/16 cards are pushed below the 8 MOOC DDLs.
    for (final p in placements) {
      expect(p.lane, lessThan(12));
    }
  });

  test('compactTimelineLanes collapses empty lanes smoothly without shrinking visible ones', () {
    final early = [
      for (var i = 0; i < 6; i++)
        AgendaEntry(
          id: 'early-$i',
          title: '早期作业 $i',
          kind: AgendaKind.deadline,
          startsAt: _date.add(const Duration(hours: 12)),
        ),
    ];
    final late = AgendaEntry(
      id: 'late-exam',
      title: '后期考试',
      kind: AgendaKind.exam,
      startsAt: _date.add(const Duration(days: 10, hours: 10)),
      endsAt: _date.add(const Duration(days: 10, hours: 12)),
    );
    final placements = layoutAgendaTimeline(
      [...early, late],
      minimumEventSpan: const Duration(minutes: 1),
      now: _date,
    );
    const laneHeight = 68.0;
    const feather = Duration(hours: 18);

    // On day 0, the 6 early lanes are visible (plus the exam's lane 0).
    final atEarly = compactTimelineLanes(
      placements,
      left: _date.subtract(const Duration(days: 3)),
      right: _date.add(const Duration(days: 3)),
      featherSpan: feather,
      laneHeight: laneHeight,
    );
    expect(atEarly.totalHeight, closeTo(6 * laneHeight, .001));
    for (var i = 0; i < 6; i++) {
      expect(atEarly.laneWeights[i], 1.0);
    }

    // Halfway through the feather past day 0, weights transition smoothly in (0, 1).
    final midFeather = compactTimelineLanes(
      placements,
      left: _date.add(const Duration(hours: 21)),
      right: _date.add(const Duration(days: 6)),
      featherSpan: feather,
      laneHeight: laneHeight,
    );
    for (var i = 0; i < 6; i++) {
      expect(midFeather.laneWeights[i], greaterThan(0));
      expect(midFeather.laneWeights[i], lessThan(1));
    }

    // On day 10, lanes 1..5 collapse completely while lane 0 stays full height.
    final atLate = compactTimelineLanes(
      placements,
      left: _date.add(const Duration(days: 7)),
      right: _date.add(const Duration(days: 13)),
      featherSpan: feather,
      laneHeight: laneHeight,
    );
    expect(atLate.laneWeights[0], 1.0);
    for (var i = 1; i < 6; i++) {
      expect(atLate.laneWeights[i], 0.0);
    }
    expect(atLate.totalHeight, closeTo(laneHeight, .001));
  });

  testWidgets('Panning past a dense day smoothly collapses empty lanes and restores them on return', (
    tester,
  ) async {
    final dense = _stackedDeadlines();
    final later = AgendaEntry(
      id: 'later-single',
      title: '后期单任务',
      kind: AgendaKind.deadline,
      startsAt: _date.add(const Duration(days: 10, hours: 12)),
    );
    await _show(tester, [...dense, later]);
    final position = _lanePosition(tester);
    final initialMax = position.maxScrollExtent;
    expect(initialMax, greaterThan(500));

    // Pan horizontally past the dense day into the sparse day-10 window.
    final gesture = await tester.startGesture(const Offset(340, 500));
    for (var step = 0; step < 24; step++) {
      await gesture.moveBy(const Offset(-20, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(position.maxScrollExtent, 0);
    expect(_paintedBar(later), findsOneWidget);

    // Panning back smoothly expands the dense day's lanes again.
    final back = await tester.startGesture(const Offset(60, 500));
    for (var step = 0; step < 24; step++) {
      await back.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await back.cancel();
    await tester.pumpAndSettle();
    expect(position.maxScrollExtent, closeTo(initialMax, .01));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Horizontal panning never shifts visible lower-lane cards vertically', (
    tester,
  ) async {
    // Upper lanes (0..2) exit the left edge while a lower-lane card (lane 3)
    // remains visible on screen, and trailing lanes (4..19) exit below it.
    final upper = [
      for (var i = 0; i < 3; i++)
        AgendaEntry(
          id: 'upper-$i',
          title: '上方任务 $i',
          kind: AgendaKind.deadline,
          startsAt: _date.add(const Duration(hours: 12)),
        ),
    ];
    final trailing = [
      for (var i = 0; i < 16; i++)
        AgendaEntry(
          id: 'trailing-$i',
          title: '下方密集任务 $i',
          kind: AgendaKind.deadline,
          startsAt: _date.add(const Duration(hours: 12)),
          done: true,
        ),
    ];
    final lower = AgendaEntry(
      id: 'lower-steady',
      title: '保持不动的任务',
      kind: AgendaKind.deadline,
      startsAt: _date.add(const Duration(days: 2, hours: 12)),
    );
    await _show(tester, [...upper, lower, ...trailing]);
    final position = _lanePosition(tester);
    final initialMax = position.maxScrollExtent;
    expect(initialMax, greaterThan(0));
    final initialTop = tester.getRect(_paintedBar(lower)).top;

    // Pan horizontally past day 0 so upper (lanes 0..2) and trailing (lanes 4..19)
    // leave the left edge completely while `lower` stays visible on screen.
    final gesture = await tester.startGesture(const Offset(340, 500));
    for (var step = 0; step < 18; step++) {
      await gesture.moveBy(const Offset(-14, 0));
      await tester.pump(const Duration(milliseconds: 16));
      expect(_paintedBar(lower), findsOneWidget);
      expect(
        tester.getRect(_paintedBar(lower)).top,
        closeTo(initialTop, .001),
        reason: 'step=$step: visible card shifted vertically during horizontal pan',
      );
    }
    await gesture.cancel();
    await tester.pumpAndSettle();
    // Day-0 cards (upper + trailing) are now completely off screen, yet `lower`
    // never shifted vertically while all 16 trailing lanes below it collapsed.
    expect(_paintedBar(upper.first), findsNothing);
    expect(_paintedBar(lower), findsOneWidget);
    expect(tester.getRect(_paintedBar(lower)).top, closeTo(initialTop, .001));
    expect(position.maxScrollExtent, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
