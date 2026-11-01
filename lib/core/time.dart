/// Calendar dates are UTC midnights so daylight-saving changes never alter
/// academic week numbers.
DateTime calendarDate(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

/// The campus wall clock, represented as a UTC value for stable date math.
DateTime campusNow() => DateTime.now().toUtc().add(const Duration(hours: 8));

DateTime mondayOf(DateTime date) =>
    calendarDate(date).subtract(Duration(days: date.weekday - 1));

String dateText(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String clockText(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';
