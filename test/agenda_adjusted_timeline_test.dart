import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bitree/agenda/deadline_source.dart';
import 'package:bitree/agenda/model.dart';
import 'package:bitree/agenda/timeline_layout.dart';
import 'package:bitree/agenda/ui/adjusted_deadline_painter.dart';
import 'package:bitree/agenda/ui/agenda_timeline.dart';
import 'package:bitree/agenda/ui/timeline_entry.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

final _date = DateTime.utc(2026, 11, 17);
const _window = DeadlineCutoffWindow(
  enabled: true,
  startMinute: 10 * 60,
  endMinute: 18 * 60,
);

AgendaEntry _deadline({
  String id = 'adjusted',
  int tailDays = 4,
  bool done = false,
  bool startOnly = false,
  DateTime? at,
  DeadlineCutoffWindow window = _window,
}) => AgendaEntry(
  id: id,
  title: '测试截止时间',
  kind: AgendaKind.deadline,
  startsAt: at ?? _date.add(const Duration(hours: 14)),
  tailDays: tailDays,
  done: done,
  source: DeadlineSource.eclass,
  startOnly: startOnly,
  deadlineCutoffWindow: window,
);

Finder _body(AgendaEntry entry) =>
    find.byKey(ValueKey(('agenda-timeline-bar', entry.id)));

Finder _surface(AgendaEntry entry) =>
    find.byKey(ValueKey(('agenda-timeline-adjusted', entry.id)));

Future<TestAppController> _showTimeline(
  WidgetTester tester,
  List<AgendaEntry> entries, {
  DeadlineCutoffWindow window = _window,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final app = TestAppController(entries: entries);
  await app.initialize();
  await app.settings.setDeadlineCutoff(window);
  await tester.pumpWidget(
    MaterialApp(
      theme: bitreeTheme(Brightness.light),
      home: Scaffold(
        body: AgendaTimeline(
          controller: app,
          entries: entries,
          now: _date.add(const Duration(hours: 8)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return app;
}

Future<ByteData> _pixels(WidgetTester tester, GlobalKey key) async =>
    (await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      image.dispose();
      return data!;
    }))!;

void main() {
  test('Adjusted reservations use four days and include the real interval', () {
    final entry = _deadline(tailDays: 14);
    final placement = layoutAgendaTimeline(
      [entry],
      minimumEventSpan: const Duration(minutes: 1),
    ).single;
    expect(placement.start, entry.dueAt.subtract(const Duration(days: 4)));
    expect(placement.end, entry.realDueAt);
    expect(placement.layoutEnd, entry.realDueAt);
    expect(entry.startsAt, _date.add(const Duration(hours: 14)));
    expect(entry.tailDays, 14);
  });

  test('An event inside the extension must occupy another lane', () {
    final ddl = _deadline();
    final event = AgendaEntry(
      id: 'event',
      title: '间隙中的日程',
      kind: AgendaKind.event,
      startsAt: _date.add(const Duration(hours: 11)),
      endsAt: _date.add(const Duration(hours: 12)),
    );
    final placements = layoutAgendaTimeline(
      [ddl, event],
      minimumEventSpan: const Duration(minutes: 1),
    );
    expect(placements.map((p) => p.lane).toSet(), hasLength(2));
  });

  test('Unadjusted and start-only reservations retain their custom tails', () {
    for (final startOnly in [false, true]) {
      final entry = _deadline(
        tailDays: 14,
        startOnly: startOnly,
        window: const DeadlineCutoffWindow(),
      );
      final placement = layoutAgendaTimeline(
        [entry],
        minimumEventSpan: const Duration(minutes: 1),
      ).single;
      expect(
        placement.start,
        startOnly
            ? entry.startsAt
            : entry.dueAt.subtract(const Duration(days: 14)),
      );
      expect(
        placement.end,
        startOnly
            ? entry.startsAt.add(const Duration(days: 14))
            : entry.realDueAt,
      );
    }
  });

  testWidgets('The fixed body ends at effective due; the extension zooms', (
    tester,
  ) async {
    final entry = _deadline(tailDays: 14);
    await _showTimeline(tester, [entry]);
    final before = tester.getRect(_body(entry));
    final geometryBefore =
        tester.widget<AdjustedDeadlineSurface>(_surface(entry)).geometry;
    expect(before.width, closeTo(48 * 3.75, .001));
    expect(
      geometryBefore.realX - geometryBefore.effectiveX,
      closeTo(8, .001),
    );
    expect(
      before.right,
      closeTo(tester.getTopLeft(_surface(entry)).dx +
          geometryBefore.effectiveX, .001),
    );

    tester.widget<Slider>(find.byType(Slider)).onChanged!(24);
    await tester.pumpAndSettle();
    final after = tester.getRect(_body(entry));
    final geometryAfter =
        tester.widget<AdjustedDeadlineSurface>(_surface(entry)).geometry;
    expect(after.width, closeTo(before.width, .001));
    expect(
      geometryAfter.realX - geometryAfter.effectiveX,
      closeTo(4 * 48, .001),
    );
    final painter = tester.widget<CustomPaint>(
      find.descendant(
        of: _surface(entry),
        matching: find.byWidgetPredicate(
          (widget) => widget is CustomPaint &&
              widget.painter is AdjustedDeadlineExtensionPainter,
        ),
      ),
    );
    expect(
      (painter.painter! as AdjustedDeadlineExtensionPainter).stripeWidth,
      16,
    );
    expect(painter.foregroundPainter, isA<AdjustedDeadlineMarkerPainter>());
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('A single-point window still paints both coincident markers', (
    tester,
  ) async {
    const point = DeadlineCutoffWindow(
      enabled: true,
      startMinute: 14 * 60,
      endMinute: 14 * 60,
    );
    final entry = _deadline(tailDays: 14, window: point);
    expect(entry.hasDeadlineCutoff, isTrue);
    expect(entry.hasAdjustedDeadline, isFalse);
    await _showTimeline(tester, [entry], window: point);
    final surface = tester.widget<AdjustedDeadlineSurface>(_surface(entry));
    expect(surface.geometry.realX, surface.geometry.effectiveX);
    expect(surface.realMarkerColor.a, closeTo(.5, .001));
    expect(tester.getRect(_body(entry)).width, closeTo(48 * 3.75, .001));
    final placement = layoutAgendaTimeline(
      [entry],
      minimumEventSpan: const Duration(minutes: 1),
    ).single;
    expect(placement.start, entry.dueAt.subtract(const Duration(days: 4)));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('A direct timeline observes cutoff changes on the same entries', (
    tester,
  ) async {
    final raw = _deadline(window: const DeadlineCutoffWindow());
    final app = await _showTimeline(
      tester,
      [raw],
      window: const DeadlineCutoffWindow(),
    );
    expect(_surface(raw), findsNothing);
    final initialRight = tester.getRect(_body(raw)).right;
    await app.settings.setDeadlineCutoff(_window);
    await tester.pumpAndSettle();
    expect(_surface(raw), findsOneWidget);
    expect(tester.getRect(_body(raw)).right, lessThan(initialRight));
    final firstRight = tester.getRect(_body(raw)).right;
    await app.settings.setDeadlineCutoff(
      _window.copyWith(startMinute: 12 * 60),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(_body(raw)).right, greaterThan(firstRight));
    await app.settings.setDeadlineCutoff(const DeadlineCutoffWindow());
    await tester.pumpAndSettle();
    expect(_surface(raw), findsNothing);
    expect(tester.getRect(_body(raw)).right, closeTo(initialRight, .001));
    expect(raw.startsAt, _date.add(const Duration(hours: 14)));
    expect(raw.hasAdjustedDeadline, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Settings are authoritative even for already-projected entries', (
    tester,
  ) async {
    final projected = _deadline();
    await _showTimeline(
      tester,
      [projected],
      window: const DeadlineCutoffWindow(),
    );
    expect(_surface(projected), findsNothing);
    expect(projected.hasAdjustedDeadline, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Extension-only visibility is bounded and remains tappable', (
    tester,
  ) async {
    final entry = _deadline(
      at: _date.add(const Duration(hours: 8)),
      window: const DeadlineCutoffWindow(enabled: true),
    );
    await _showTimeline(
      tester,
      [entry],
      window: const DeadlineCutoffWindow(enabled: true),
    );
    tester.widget<Slider>(find.byType(Slider)).onChanged!(24);
    await tester.pumpAndSettle();
    final surface = tester.getRect(_surface(entry));
    final body = tester.getRect(_body(entry));
    expect(body.right, lessThan(0));
    expect(surface.width, greaterThan(0));
    expect(surface.width, lessThanOrEqualTo(390));
    await tester.tapAt(surface.center);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final done in [false, true]) {
    testWidgets('Real marker and stripe palette are dimmed, done=$done', (
      tester,
    ) async {
      final entry = _deadline(done: done);
      await _showTimeline(tester, [entry]);
      final surface = tester.widget<AdjustedDeadlineSurface>(_surface(entry));
      expect(surface.realMarkerColor.a, closeTo(done ? .25 : .5, .001));
      expect(surface.fill.a, closeTo(done ? .5 : 1, .001));
      expect(surface.fill.r, greaterThan(0));
      expect(surface.fill.b, greaterThan(0));
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final done in [false, true]) {
    testWidgets('Stripes keep their palette, angle and alpha, done=$done', (
      tester,
    ) async {
      final key = GlobalKey();
      final alpha = done ? .5 : 1.0;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 80,
                height: 32,
                child: CustomPaint(
                  painter: AdjustedDeadlineExtensionPainter(
                    effectiveX: 0,
                    realX: 80,
                    color: const Color(0xFF336699).withValues(alpha: alpha),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final data = await _pixels(tester, key);
      int channel(int x, int y, int channel) =>
          data.getUint8((y * 80 + x) * 4 + channel);
      expect(channel(10, 4, 3), closeTo(255 * alpha * .32, 2));
      expect(channel(26, 4, 3), closeTo(255 * alpha * .16, 2));
      // x+y remains constant when moving along a 45-degree band.
      expect(channel(6, 8, 3), channel(10, 4, 3));
      for (final x in [10, 26]) {
        expect(channel(x, 4, 0), closeTo(0x33, 3));
        expect(channel(x, 4, 1), closeTo(0x66, 3));
        expect(channel(x, 4, 2), closeTo(0x99, 3));
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final gap in [0.0, 0.2]) {
    testWidgets('The real marker stays on top with a $gap pixel gap', (
      tester,
    ) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 80,
                height: 32,
                child: AdjustedDeadlineSurface(
                  geometry: AdjustedDeadlineGeometry(
                    bodyLeft: 0,
                    effectiveX: 40,
                    realX: 40 + gap,
                  ),
                  bodyWidth: 40,
                  fill: Colors.transparent,
                  realMarkerColor: Colors.red.withValues(alpha: .5),
                  semanticsLabel: '真实标线优先',
                  onTap: () {},
                  body: const DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: Colors.blue, width: 3),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final data = await _pixels(tester, key);
      final pixel = (16 * 80 + 38) * 4;
      // Red over blue is purple; blue painted last erases the red component.
      expect(data.getUint8(pixel), greaterThan(110));
      expect(data.getUint8(pixel + 2), greaterThan(110));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
