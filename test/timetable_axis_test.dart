import 'package:bitree/schedule/timetable_axis.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const axis = TimetableAxis(expanded: true);

  test('The full day is strictly increasing and can be inverted', () {
    expect(axis.offsetForMinute(0), 0);
    expect(axis.offsetForMinute(1440), axis.length);
    for (var minute = 0; minute < 1440; minute++) {
      expect(
        axis.offsetForMinute(minute + 1.0),
        greaterThan(axis.offsetForMinute(minute.toDouble())),
      );
      final sample = minute + 0.37;
      expect(
        axis.minuteAtOffset(axis.offsetForMinute(sample)),
        closeTo(sample, 0.000001),
      );
    }
    expect(axis.minuteAtOffset(axis.length), 1440);
    final monday = DateTime.utc(2026, 10, 26);
    expect(axis.offsetAt(monday.subtract(const Duration(hours: 1)), monday), 0);
    expect(
      axis.offsetAt(monday.add(const Duration(days: 1)), monday),
      axis.length,
    );
  });

  test(
    'Cosine shoulders tighten towards midnight and start at 08:00/21:00',
    () {
      double hourSpan(int hour) =>
          axis.offsetForMinute((hour + 1) * 60.0) -
          axis.offsetForMinute(hour * 60.0);
      for (var hour = 0; hour < 7; hour++) {
        expect(hourSpan(hour), lessThan(hourSpan(hour + 1)));
      }
      expect(hourSpan(21), greaterThan(hourSpan(22)));
      expect(hourSpan(22), greaterThan(hourSpan(23)));
      for (final boundary in [480.0, 1260.0]) {
        final before =
            axis.offsetForMinute(boundary) - axis.offsetForMinute(boundary - 1);
        final after =
            axis.offsetForMinute(boundary + 1) - axis.offsetForMinute(boundary);
        expect(before, closeTo(after, 0.00001));
      }
      final daytime = axis.offsetForMinute(1260) - axis.offsetForMinute(480);
      expect(daytime / axis.length, inExclusiveRange(0.75, 0.85));
      for (var section = 1; section <= 13; section++) {
        expect(
          axis.sectionEnd(section) - axis.sectionStart(section),
          closeTo(1, 1e-9),
        );
      }
      expect(axis.offsetForMinute(800), greaterThan(axis.offsetForMinute(740)));
    },
  );

  test(
    'Expanded selections distinguish hours, breaks and teaching periods',
    () {
      for (final (minute, start, end) in [
        (30.0, 30, 45),
        (480.0, 480, 525),
        (750.0, 750, 765),
        (795.0, 795, 800),
        (805.0, 800, 845),
        (1267.0, 1260, 1275),
        (1439.0, 1425, 1440),
      ]) {
        expect(axis.cellAtOffset(axis.offsetForMinute(minute)), (
          start: start,
          end: end,
        ));
      }
      const normal = TimetableAxis();
      expect(normal.length, 13);
      expect(normal.cellAtOffset(5.5), (start: 800, end: 845));
      expect(normal.offsetForMinute(750), normal.offsetForMinute(795));
    },
  );
}
