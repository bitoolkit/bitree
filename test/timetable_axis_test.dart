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
    'The overnight curve splits equally at 03:00 without moving midnight',
    () {
      double hourSpan(int hour) =>
          axis.offsetForMinute((hour + 1) * 60.0) -
          axis.offsetForMinute(hour * 60.0);
      for (var step = 0; step < 6; step++) {
        final before = (2 - step + 24) % 24;
        expect(hourSpan(before), closeTo(hourSpan(3 + step), 1e-9));
      }
      expect(hourSpan(0), greaterThan(hourSpan(1)));
      expect(hourSpan(1), greaterThan(hourSpan(2)));
      expect(hourSpan(3), lessThan(hourSpan(4)));
      expect(hourSpan(4), lessThan(hourSpan(5)));
      expect(hourSpan(21), greaterThan(hourSpan(22)));
      expect(hourSpan(22), greaterThan(hourSpan(23)));

      final beforeThree =
          axis.length - axis.offsetForMinute(1260) + axis.offsetForMinute(180);
      final afterThree = axis.offsetForMinute(540) - axis.offsetForMinute(180);
      expect(beforeThree, closeTo(afterThree, 1e-9));
      expect(axis.offsetForMinute(0), 0);
      expect(axis.offsetForMinute(1440), axis.length);

      for (final boundary in [180.0, 540.0, 1260.0]) {
        final before =
            axis.offsetForMinute(boundary) - axis.offsetForMinute(boundary - 1);
        final after =
            axis.offsetForMinute(boundary + 1) - axis.offsetForMinute(boundary);
        expect(before, closeTo(after, 0.00001));
      }
      final midnightBefore = axis.length - axis.offsetForMinute(1439);
      final midnightAfter = axis.offsetForMinute(1);
      expect(midnightBefore, closeTo(midnightAfter, 0.0001));

      final fullMinute = axis.offsetForMinute(601) - axis.offsetForMinute(600);
      final atThree = axis.offsetForMinute(181) - axis.offsetForMinute(180);
      expect(atThree / fullMinute, closeTo(0.5, 0.002));
      expect(midnightAfter / fullMinute, closeTo(0.866, 0.002));
      for (var section = 1; section <= 13; section++) {
        final span = axis.sectionEnd(section) - axis.sectionStart(section);
        if (section <= 2) {
          // Morning classes follow the curve up to 09:00 and stay selectable.
          expect(span, inInclusiveRange(0.98, 1.000001));
        } else {
          expect(span, closeTo(1, 1e-9));
        }
      }
      expect(axis.offsetForMinute(800), greaterThan(axis.offsetForMinute(740)));
    },
  );

  test(
    'Expanded selections distinguish hours, breaks and teaching periods',
    () {
      for (final (minute, start, end) in [
        (0.0, 0, 60),
        (29.0, 0, 60),
        (30.0, 0, 60),
        (59.0, 0, 60),
        (60.0, 60, 120),
        (479.0, 420, 480),
        (480.0, 480, 525),
        (527.0, 525, 530),
        (535.0, 530, 575),
        (540.0, 530, 575),
        (750.0, 750, 765),
        (795.0, 795, 800),
        (805.0, 800, 845),
        (1260.0, 1260, 1320),
        (1267.0, 1260, 1320),
        (1290.0, 1260, 1320),
        (1320.0, 1320, 1380),
        (1439.0, 1380, 1440),
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
