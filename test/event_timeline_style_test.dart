import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bitree/agenda/model.dart';
import 'package:bitree/agenda/ui/agenda_timeline.dart';
import 'package:bitree/agenda/ui/event_timeline_entry.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

final _date = DateTime.utc(2026, 11, 17);

AgendaEntry _event({bool exam = false, bool done = false}) => AgendaEntry(
  id: exam ? 'exam' : 'event',
  title: exam ? '考试' : '日程',
  kind: exam ? AgendaKind.exam : AgendaKind.event,
  startsAt: _date.add(const Duration(hours: 11)),
  endsAt: _date.add(const Duration(hours: 13)),
  done: done,
);

Future<ByteData> _pixels(WidgetTester tester, GlobalKey key) async =>
    (await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data!;
    }))!;

Future<TestAppController> _show(
  WidgetTester tester,
  List<AgendaEntry> entries,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final app = TestAppController(entries: entries);
  await app.initialize();
  await tester.pumpWidget(MaterialApp(
    theme: bitreeTheme(Brightness.light),
    home: Scaffold(body: AgendaTimeline(
      controller: app,
      entries: entries,
      now: _date.add(const Duration(hours: 10)),
    )),
  ));
  await tester.pumpAndSettle();
  return app;
}

void main() {
  for (final done in [false, true]) {
    testWidgets('Event stripes multiply existing completion alpha: $done', (
      tester,
    ) async {
      final key = GlobalKey();
      final completionAlpha = done ? .5 : 1.0;
      await tester.pumpWidget(MaterialApp(
        home: Center(child: RepaintBoundary(
          key: key,
          child: SizedBox(width: 120, height: 40, child: CustomPaint(
            painter: EventTimelinePainter(
              geometry: const EventTimelineGeometry(
                informationLeft: 0, startX: 80, endX: 110,
              ),
              fill: const Color(0xFF336699).withValues(alpha: completionAlpha),
              accent: const Color(0xFF995522).withValues(alpha: completionAlpha),
            ),
          )),
        )),
      ));
      await tester.pumpAndSettle();
      final data = await _pixels(tester, key);
      int channel(int x, int y, int component) =>
          data.getUint8((y * 120 + x) * 4 + component);
      // Bands alternate between the solid fill and its half alpha.
      expect(channel(10, 4, 3), closeTo(255 * completionAlpha, 2));
      expect(channel(26, 4, 3), closeTo(255 * completionAlpha * .5, 2));
      expect(channel(6, 8, 3), channel(10, 4, 3));
      if (!done) {
        // The inner border is the accent (red-led), unlike the fill-colored
        // stripes (blue-led). The 1.5px stroke never fully covers a pixel, so
        // compare premultiplied hue instead of an exact alpha.
        expect(channel(0, 20, 0), greaterThan(channel(0, 20, 2)));
      }
      expect(channel(10, 4, 0), lessThan(channel(10, 4, 2)));
      for (final (x, y) in [(10, 4), (26, 4), (90, 20)]) {
        final alpha = channel(x, y, 3) / 255;
        expect(channel(x, y, 0), closeTo(0x33 * alpha, 2));
        expect(channel(x, y, 1), closeTo(0x66 * alpha, 2));
        expect(channel(x, y, 2), closeTo(0x99 * alpha, 2));
      }
      expect(channel(90, 20, 3), closeTo(255 * completionAlpha, 2));
      // The real interval is solid: no vertical or horizontal fade.
      expect(channel(90, 8, 3), channel(100, 25, 3));
      // Both temporal boundaries use the accent, independently of duration.
      for (final x in [79, 109]) {
        if (!done) {
          expect(channel(x, 20, 0), closeTo(0x99, 2));
          expect(channel(x, 20, 1), closeTo(0x55, 2));
          expect(channel(x, 20, 2), closeTo(0x22, 2));
        } else {
          // Translucent marker paint composites over the interval/inner border.
          expect(channel(x, 20, 0), greaterThan(channel(90, 20, 0)));
        }
      }
      expect(channel(111, 20, 3), 0);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('Hidden information bars keep the interval and both lines only', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: Center(child: RepaintBoundary(
        key: key,
        child: SizedBox(width: 120, height: 40, child: CustomPaint(
          painter: const EventTimelinePainter(
            geometry: EventTimelineGeometry(
              informationLeft: 0, startX: 80, endX: 110,
            ),
            fill: Color(0xFF336699),
            accent: Color(0xFF995522),
            showInformation: false,
          ),
        )),
      )),
    ));
    await tester.pumpAndSettle();
    final data = await _pixels(tester, key);
    int channel(int x, int y, int component) =>
        data.getUint8((y * 120 + x) * 4 + component);
    // No stripes and no inner border where the information card used to be.
    for (final (x, y) in [(0, 20), (6, 8), (10, 4), (26, 4), (70, 20)]) {
      expect(channel(x, y, 3), 0, reason: 'info pixel $x,$y');
    }
    // The interval and both boundary lines still paint unchanged.
    expect(channel(90, 20, 3), 255);
    expect(channel(90, 8, 3), channel(100, 25, 3));
    for (final x in [79, 109]) {
      expect(channel(x, 20, 0), closeTo(0x99, 2));
      expect(channel(x, 20, 1), closeTo(0x55, 2));
      expect(channel(x, 20, 2), closeTo(0x22, 2));
    }
    expect(channel(111, 20, 3), 0);
    await tester.pumpWidget(const SizedBox());
  });

  for (final exam in [false, true]) {
    testWidgets('Event and exam information stays fixed while the span zooms: $exam', (
      tester,
    ) async {
      final entry = _event(exam: exam);
      final app = await _show(tester, [entry]);
      final information = find.byKey(ValueKey(('agenda-timeline-bar', entry.id)));
      final before = tester.widget<EventTimelineEntry>(
        find.byType(EventTimelineEntry),
      );
      expect(tester.getRect(information).width, closeTo(48 * 3.75, .001));
      expect(before.geometry.endX - before.geometry.startX, closeTo(4, .001));
      tester.widget<Slider>(find.byType(Slider)).onChanged!(24);
      await tester.pumpAndSettle();
      final after = tester.widget<EventTimelineEntry>(
        find.byType(EventTimelineEntry),
      );
      expect(tester.getRect(information).width, closeTo(48 * 3.75, .001));
      expect(after.geometry.endX - after.geometry.startX, closeTo(96, .001));
      await app.settings.setAgendaLayoutDays(6);
      await tester.pumpAndSettle();
      expect(tester.getRect(information).width, closeTo(48 * 5.75, .001));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
