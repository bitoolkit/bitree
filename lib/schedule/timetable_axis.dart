import 'dart:math' as math;

import '../core/time.dart';
import 'section_times.dart';

/// Shared coordinates for cards, labels, the clock and pointer selection.
/// One unit is the height of a teaching period, in either display mode.
class TimetableAxis {
  const TimetableAxis({this.expanded = false});

  final bool expanded;
  static const morningEnd = 9 * 60;
  static const eveningStart = 21 * 60;
  static const compressionMidpoint = 3 * 60;
  static const dayEnd = 24 * 60;
  static final periods = [
    for (final period in sectionTimes)
      (start: clockMinute(period.$1), end: clockMinute(period.$2)),
  ];
  static final _expandedOffsets = _buildExpandedOffsets();

  double get length =>
      expanded ? _expandedOffsets.last : sectionTimes.length.toDouble();

  static int clockMinute(String clock) {
    final parts = clock.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  static double _density(double minute) {
    if (minute < morningEnd || minute >= eveningStart) {
      // Treat 21:00–03:00 and 03:00–09:00 as equal six-hour shoulders.
      // Unwrap only the curve's phase; grid coordinates still start at 00:00.
      final nightMinute = minute >= eveningStart ? minute - dayEnd : minute;
      final distance = (nightMinute - compressionMidpoint).abs();
      final phase =
          (1 - distance / (morningEnd - compressionMidpoint)) * math.pi / 3;
      return math.cos(phase) / 45;
    }
    final teaching =
        minute >= periods.last.end ||
        periods.any((period) => minute >= period.start && minute < period.end);
    return (teaching ? 1.0 : 0.2) / 45;
  }

  static List<double> _buildExpandedOffsets() {
    final offsets = <double>[0];
    for (var minute = 0; minute < dayEnd; minute++) {
      // Integrate minute-sized bins, including partial teaching periods
      // before 09:00, and reuse the same coordinates everywhere in the grid.
      offsets.add(offsets.last + _density(minute + 0.5));
    }
    return List.unmodifiable(offsets);
  }

  double offsetAt(DateTime time, DateTime date) => offsetForMinute(
    time.difference(calendarDate(date)).inMicroseconds /
        Duration.microsecondsPerMinute,
  );

  double offsetForMinute(double minute) {
    minute = minute.clamp(0, dayEnd).toDouble();
    if (expanded) {
      final index = minute.floor();
      if (index == dayEnd) return length;
      return _expandedOffsets[index] +
          (minute - index) *
              (_expandedOffsets[index + 1] - _expandedOffsets[index]);
    }
    for (var index = 0; index < periods.length; index++) {
      final period = periods[index];
      if (minute <= period.start) return index.toDouble();
      if (minute < period.end) {
        return index + (minute - period.start) / (period.end - period.start);
      }
    }
    return length;
  }

  double minuteAtOffset(double offset) {
    offset = offset.clamp(0, length).toDouble();
    if (!expanded) {
      final index = offset.floor().clamp(0, periods.length - 1);
      final period = periods[index];
      return period.start + (offset - index) * (period.end - period.start);
    }
    var low = 0;
    var high = dayEnd;
    while (low + 1 < high) {
      final middle = (low + high) ~/ 2;
      if (_expandedOffsets[middle] <= offset) {
        low = middle;
      } else {
        high = middle;
      }
    }
    return low +
        (offset - _expandedOffsets[low]) /
            (_expandedOffsets[high] - _expandedOffsets[low]);
  }

  double sectionStart(int section) =>
      offsetForMinute(periods[section - 1].start.toDouble());
  double sectionEnd(int section) =>
      offsetForMinute(periods[section - 1].end.toDouble());

  static int? sectionAtMinute(int minute) {
    for (var index = 0; index < periods.length; index++) {
      if (minute >= periods[index].start && minute < periods[index].end) {
        return index + 1;
      }
    }
    return null;
  }

  /// Teaching periods snap as before. Early/late hours snap to whole hours;
  /// daytime breaks use quarter hours, clipped to the surrounding classes.
  ({int start, int end}) cellAtOffset(double offset) {
    if (!expanded) {
      final index = offset.floor().clamp(0, periods.length - 1);
      return periods[index];
    }
    final minute = minuteAtOffset(offset).floor().clamp(0, dayEnd - 1);
    final section = sectionAtMinute(minute);
    if (section != null) return periods[section - 1];
    final step = minute < morningEnd || minute >= eveningStart ? 60 : 15;
    final previous = periods.where((period) => period.end <= minute).lastOrNull;
    final next = periods.where((period) => period.start > minute).firstOrNull;
    return (
      start: math.max(previous?.end ?? 0, minute ~/ step * step),
      end: math.min(next?.start ?? dayEnd, (minute ~/ step + 1) * step),
    );
  }
}
