import 'package:bitree/agenda/calendar.dart';
import 'package:bitree/agenda/model.dart';
import 'package:bitree/schedule/layout.dart';
import 'package:bitree/schedule/timetable_axis.dart';
import 'package:flutter_test/flutter_test.dart';

final _monday = DateTime.utc(2026, 10, 26);

AgendaEntry _event(String id, int start, int end) => AgendaEntry(
  id: id,
  title: id,
  kind: AgendaKind.event,
  startsAt: _monday.add(Duration(minutes: start)),
  endsAt: _monday.add(Duration(minutes: end)),
);

TimetableAxis _axis(List<AgendaEntry> entries, {bool expanded = true}) =>
    weekTimetableAxis(
      [
        for (var day = 0; day < 7; day++)
          calendarItemsOn(_monday.add(Duration(days: day)), null, entries),
      ],
      _monday,
      expanded: expanded,
    );

void main() {
  test('Different days contribute the earliest start and latest end', () {
    final axis = _axis([
      _event('morning', 1440 + 7 * 60 + 20, 1440 + 8 * 60),
      _event('night', 5 * 1440 + 22 * 60 + 10, 5 * 1440 + 22 * 60 + 45),
    ]);
    expect(axis.startMinute, 420);
    expect(axis.endMinute, 1380);
    expect(axis.offsetForMinute(420), 0);
    expect(axis.offsetForMinute(1380), axis.length);
  });

  test('Midnight crossings cover both ends of their calendar days', () {
    final axis = _axis([_event('overnight', 23 * 60, 1440 + 2 * 60)]);
    expect(axis.startMinute, 0);
    expect(axis.endMinute, 1440);
  });

  test('Events outside the selected week are clipped or excluded', () {
    final fromPreviousWeek = _axis([_event('previous', -120, 60)]);
    expect(fromPreviousWeek.startMinute, 0);
    expect(fromPreviousWeek.endMinute, 60);
    final intoNextWeek = _axis([
      _event('next', 7 * 1440 - 60, 7 * 1440 + 120),
      _event('outside', 8 * 1440, 8 * 1440 + 60),
    ]);
    expect(intoNextWeek.startMinute, 1380);
    expect(intoNextWeek.endMinute, 1440);
  });

  test(
    'A narrow range keeps coordinates and whole-hour selection reversible',
    () {
      final axis = _axis([_event('short', 22 * 60 + 10, 22 * 60 + 20)]);
      expect(axis.startMinute, 1320);
      expect(axis.endMinute, 1380);
      expect(axis.length, greaterThan(0));
      expect(axis.offsetForMinute(0), 0);
      expect(axis.offsetForMinute(1440), axis.length);
      expect(axis.minuteAtOffset(0), 1320);
      expect(axis.minuteAtOffset(axis.length), 1380);
      for (final minute in [1320.0, 1335.25, 1379.99]) {
        expect(
          axis.minuteAtOffset(axis.offsetForMinute(minute)),
          closeTo(minute, 1e-6),
        );
      }
      expect(axis.cellAtOffset(0), (start: 1320, end: 1380));
      expect(axis.cellAtOffset(axis.length), (start: 1320, end: 1380));
    },
  );

  test('End times on the hour stay exact and seconds round outward', () {
    final exact = _axis([_event('exact', 1260, 1320)]);
    expect(exact.endMinute, 1320);
    final withSeconds = _axis([
      AgendaEntry(
        id: 'seconds',
        title: 'seconds',
        kind: AgendaKind.event,
        startsAt: _monday.add(const Duration(hours: 21, seconds: 1)),
        endsAt: _monday.add(const Duration(hours: 22, seconds: 1)),
      ),
    ]);
    expect(withSeconds.startMinute, 1260);
    expect(withSeconds.endMinute, 1380);
  });

  test('Empty expanded weeks retain the full day and collapsed mode retains periods', () {
    final empty = _axis([]);
    expect(empty.startMinute, 0);
    expect(empty.endMinute, 1440);
    final collapsed = _axis([_event('night', 1380, 1440)], expanded: false);
    expect(collapsed.expanded, isFalse);
    expect(collapsed.length, 13);
  });
}
