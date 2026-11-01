import 'section_times.dart';
import 'time_position.dart';

class TimetableSelection {
  const TimetableSelection({
    required this.date,
    required this.startSection,
    required this.endSection,
  });

  final DateTime date;
  final int startSection;
  final int endSection;

  DateTime get startsAt => _at(sectionTimes[startSection - 1].$1);
  DateTime get endsAt => _at(sectionTimes[endSection - 1].$2);

  /// Elapsed height in the timetable, where breaks have no height.
  /// Null means this occurrence is not currently in progress.
  double? progressAt(DateTime now) {
    if (now.isBefore(startsAt) || !now.isBefore(endsAt)) return null;
    final section = sectionOffsetAt(now)!;
    return (section - startSection + 1) / (endSection - startSection + 1);
  }

  DateTime _at(String time) {
    final parts = time.split(':').map(int.parse).toList();
    return DateTime.utc(date.year, date.month, date.day, parts[0], parts[1]);
  }
}
