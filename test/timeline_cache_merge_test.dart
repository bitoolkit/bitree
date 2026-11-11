import 'package:bitree/agenda/model.dart';
import 'package:bitree/agenda/ui/adjusted_deadline_painter.dart';
import 'package:bitree/agenda/ui/event_timeline_entry.dart';
import 'package:bitree/agenda/ui/timeline_entry.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2030, 1, 2, 8);

Future<void> _show(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(
    theme: bitreeTheme(Brightness.light),
    home: Scaffold(body: Center(child: SizedBox(
      width: 240, height: 100, child: child,
    ))),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Adjusted DDL reuses text but refreshes geometry and tap callback', (
    tester,
  ) async {
    final entry = AgendaEntry(
      id: 'adjusted', title: '缓存作业', kind: AgendaKind.deadline,
      startsAt: DateTime.utc(2030, 1, 2, 14),
      deadlineCutoffWindow: const DeadlineCutoffWindow(
        enabled: true, startMinute: 600, endMinute: 1080,
      ),
    );
    var tapped = 0;
    Widget card(double realX, VoidCallback onTap) => AgendaTimelineEntry(
      entry: entry, now: _now, barWidth: 180, deadlineWidth: 180,
      adjustedGeometry: AdjustedDeadlineGeometry(
        bodyLeft: 0, effectiveX: 180, realX: realX,
      ),
      onTap: onTap,
    );
    await _show(tester, card(200, () => tapped = 1));
    final title = tester.widget<Text>(find.text(entry.title));
    final state = tester.state(find.byType(AgendaTimelineEntry));
    await _show(tester, card(230, () => tapped = 2));
    expect(tester.state(find.byType(AgendaTimelineEntry)), same(state));
    expect(tester.widget<Text>(find.text(entry.title)), same(title));
    final surface = tester.widget<AdjustedDeadlineSurface>(
      find.byType(AdjustedDeadlineSurface),
    );
    expect(surface.geometry.realX, 230);
    final painter = tester.widget<CustomPaint>(find.byWidgetPredicate(
      (widget) => widget is CustomPaint &&
          widget.foregroundPainter is AdjustedDeadlineMarkerPainter,
    ));
    expect((painter.foregroundPainter! as AdjustedDeadlineMarkerPainter).realX, 230);
    await tester.tap(find.text(entry.title));
    await tester.pumpAndSettle();
    expect(tapped, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Event text cache is independent of time-span geometry', (
    tester,
  ) async {
    final entry = AgendaEntry(
      id: 'event', title: '缓存日程', kind: AgendaKind.event,
      startsAt: DateTime.utc(2030, 1, 2, 10),
      endsAt: DateTime.utc(2030, 1, 2, 11),
    );
    Widget card(AgendaEntry value, double endX) => EventTimelineEntry(
      entry: value, now: _now, informationWidth: 180,
      geometry: EventTimelineGeometry(
        informationLeft: 0, startX: 180, endX: endX,
      ),
      onTap: () {},
    );
    await _show(tester, card(entry, 190));
    final title = tester.widget<Text>(find.text(entry.title));
    await _show(tester, card(entry, 220));
    expect(tester.widget<Text>(find.text(entry.title)), same(title));
    EventTimelinePainter painter() => tester.widget<CustomPaint>(
      find.byWidgetPredicate((widget) => widget is CustomPaint &&
          widget.painter is EventTimelinePainter),
    ).painter! as EventTimelinePainter;
    expect(painter().geometry.endX, 220);
    final originalAlpha = painter().fill.a;
    await _show(tester, card(entry.copyWith(done: true), 220));
    expect(tester.widget<Text>(find.text(entry.title)), isNot(same(title)));
    expect(painter().fill.a, closeTo(originalAlpha * .5, .001));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
