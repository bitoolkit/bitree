import 'package:bitree/agenda/model.dart';
import 'package:bitree/agenda/timeline_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day = DateTime.utc(2026, 11, 17);
  const window = DeadlineCutoffWindow(
    enabled: true, startMinute: 10 * 60, endMinute: 18 * 60,
  );

  test('A retained layout preserves complete feature reservations at every zoom', () {
    final entries = [
      AgendaEntry(
        id: 'plain', title: '普通DDL', kind: AgendaKind.deadline,
        startsAt: day.add(const Duration(hours: 8)), tailDays: 1,
      ),
      AgendaEntry(
        id: 'adjusted', title: '伪截止', kind: AgendaKind.deadline,
        startsAt: day.add(const Duration(hours: 14)),
        deadlineCutoffWindow: window, tailDays: 30,
      ),
      AgendaEntry(
        id: 'open', title: '仅开始', kind: AgendaKind.deadline,
        startsAt: day.add(const Duration(hours: 12)), startOnly: true,
      ),
      AgendaEntry(
        id: 'event', title: '普通日程', kind: AgendaKind.event,
        startsAt: day.add(const Duration(hours: 11)),
        endsAt: day.add(const Duration(hours: 13)),
      ),
      AgendaEntry(
        id: 'exam', title: '考试', kind: AgendaKind.exam,
        startsAt: day.add(const Duration(hours: 12)),
        endsAt: day.add(const Duration(hours: 15)),
      ),
    ];
    const days = 6;
    const cardSpan = Duration(hours: 138); // (6 - .25) baseline days.
    final layout = AgendaTimelineLayout(
      entries,
      minimumEventSpan: const Duration(hours: 1),
      deadlineCardSpan: cardSpan,
      layoutDays: days,
    );
    final initial = layout.atZoom(1);
    final lanes = {for (final p in initial) p.entry.id: p.lane};
    final bounds = {
      for (final p in initial)
        p.entry.id: (start: p.start, end: p.end, layoutEnd: p.layoutEnd),
    };
    for (final zoom in [1.0, 2.0, 8.0, 24.0, 4.0, 1.0]) {
      for (final p in layout.atZoom(zoom)) {
        final entry = p.entry;
        expect(p.lane, lanes[entry.id]);
        expect((start: p.start, end: p.end, layoutEnd: p.layoutEnd), bounds[entry.id]);
        final fixedSpan = Duration(
          microseconds: (cardSpan.inMicroseconds / zoom).ceil(),
        );
        final anchor = entry.isDeadline ? entry.dueAt : entry.startsAt;
        expect(p.start, entry.startOnly
            ? entry.startsAt : anchor.subtract(const Duration(days: days)));
        expect(p.end, entry.startOnly
            ? entry.startsAt.add(const Duration(days: days))
            : entry.isDeadline ? entry.realDueAt : entry.endsAt);
        expect(p.paintStart, entry.startOnly
            ? entry.startsAt : anchor.subtract(fixedSpan));
        expect(p.paintEnd, entry.startOnly
            ? entry.startsAt.add(fixedSpan) : p.end);
      }
    }
  });

  test('An extension or information reservation cannot yield its lane to a neighbour', () {
    final adjusted = AgendaEntry(
      id: 'adjusted', title: '伪提前', kind: AgendaKind.deadline,
      startsAt: day.add(const Duration(hours: 14)),
      deadlineCutoffWindow: window,
    );
    final event = AgendaEntry(
      id: 'event', title: '延伸段内日程', kind: AgendaKind.event,
      startsAt: day.add(const Duration(hours: 11)),
      endsAt: day.add(const Duration(hours: 12)),
    );
    final layout = AgendaTimelineLayout(
      [adjusted, event],
      minimumEventSpan: const Duration(minutes: 1),
      deadlineCardSpan: const Duration(hours: 90),
    );
    for (final zoom in [1.0, 4.0, 24.0]) {
      final projected = layout.atZoom(zoom);
      expect(projected.map((p) => p.lane).toSet(), hasLength(2));
      final ddl = projected.singleWhere((p) => p.entry.id == adjusted.id);
      expect(ddl.paintEnd, adjusted.realDueAt);
      expect(ddl.paintStart.isBefore(adjusted.dueAt), isTrue);
    }
  });
}
