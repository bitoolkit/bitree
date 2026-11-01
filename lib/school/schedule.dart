import '../schedule/model.dart';

SemesterSchedule parseSchoolSchedule({
  required String term,
  required DateTime termStartMonday,
  required List<Map<String, dynamic>> rows,
}) {
  final maskStartOffset = _maskStartOffset(rows);

  // The school calendar includes negative weeks. Local dates use week 1's Monday.
  return SemesterSchedule(
    term: term,
    firstMonday: calendarDate(termStartMonday)
        .subtract(Duration(days: maskStartOffset * 7)),
    courses: [for (final row in rows) _parseCourse(row, maskStartOffset)],
    syncedAt: DateTime.now().toUtc(),
  );
}

Course _parseCourse(Map<String, dynamic> row, int maskStartOffset) {
  final mask = row['SKZC']?.toString() ?? '';

  final weeks = [
    for (var index = 0; index < mask.length; index++)
      if (mask[index] == '1') weekFromOffset(maskStartOffset + index),
  ];

  return Course.imported(
    name: row['KCM']?.toString() ?? '',
    teacher: row['SKJS']?.toString() ?? '',
    room: row['JASMC']?.toString() ?? '',
    campus: row['XXXQMC']?.toString() ?? '',
    number: row['KCH']?.toString() ?? '',
    description: row['YPSJDD']?.toString() ?? '',
    weekday: _optionalInt(row['SKXQ']),
    startSection: _optionalInt(row['KSJC']),
    endSection: _optionalInt(row['JSJC']),
    weeks: weeks,
  );
}

int? _optionalInt(Object? value) {
  final text = value?.toString();
  if (text == null || text.isEmpty || text == '0') return null;

  final parsed = int.tryParse(text);
  if (parsed == null) {
    throw FormatException('课表节次格式不正确：$text');
  }
  return parsed;
}

int _maskStartOffset(List<Map<String, dynamic>> rows) {
  // A term's masks share an origin. Match all set bits against displayed weeks.
  for (final row in rows) {
    final describedWeeks = _describedWeeks(row['YPSJDD']?.toString() ?? '');
    final mask = row['SKZC']?.toString() ?? '';
    final positions = [
      for (var index = 0; index < mask.length; index++)
        if (mask[index] == '1') index,
    ];
    if (describedWeeks.isEmpty || describedWeeks.length != positions.length) {
      continue;
    }

    final offset = weekOffset(describedWeeks.first) - positions.first;
    final matches = positions.indexed.every(
      (entry) => weekFromOffset(offset + entry.$2) == describedWeeks[entry.$1],
    );
    if (matches) return offset;
  }

  return 0;
}

List<int> _describedWeeks(String description) {
  final ranges = RegExp(r'(-?\d+)\s*(?:[-–~～]\s*(-?\d+)\s*)?周');
  final weeks = <int>[
    for (final match in ranges.allMatches(description))
      if (match[2] == null)
        int.parse(match[1]!)
      else
        ...academicWeeks(int.parse(match[1]!), int.parse(match[2]!)),
  ];

  return weeks.toSet().toList()..sort();
}
