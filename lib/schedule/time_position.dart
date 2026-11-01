import '../core/time.dart';
import 'section_times.dart';

int _minutes(String time) {
  final parts = time.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

/// Position in equal-height sections, or null outside the timetable's hours.
/// Breaks have no height, so the position waits at the next section boundary.
double? sectionOffsetAt(DateTime now) {
  final minute = now.hour * 60 + now.minute + now.second / 60;
  if (minute < _minutes(sectionTimes.first.$1) ||
      minute >= _minutes(sectionTimes.last.$2)) {
    return null;
  }

  for (var index = 0; index < sectionTimes.length; index++) {
    final start = _minutes(sectionTimes[index].$1);
    final end = _minutes(sectionTimes[index].$2);
    if (minute < start) return index.toDouble();
    if (minute <= end) return index + (minute - start) / (end - start);
  }
  return null;
}

/// Outside class hours, wait at the next morning's first section.
({DateTime time, double section}) timeIndicatorPositionAt(DateTime now) {
  final section = sectionOffsetAt(now);
  if (section != null) return (time: now, section: section);

  var date = calendarDate(now);
  final minute = now.hour * 60 + now.minute;
  if (minute >= _minutes(sectionTimes.last.$2)) {
    date = date.add(const Duration(days: 1));
  }

  return (
    time: date.add(Duration(minutes: _minutes(sectionTimes.first.$1))),
    section: 0,
  );
}
