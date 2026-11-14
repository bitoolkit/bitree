part of 'lexue_deadlines.dart';

List<AgendaEntry> _parseLexueCalendar(String calendar) {
  final unfolded = calendar.replaceAll(RegExp(r'\r?\n[ \t]'), '');
  final result = <AgendaEntry>[];
  for (final block in unfolded.split('BEGIN:VEVENT').skip(1)) {
    final properties = <String, ({String parameters, String value})>{};
    for (final line
        in block.split('END:VEVENT').first.split(RegExp(r'\r?\n'))) {
      final colon = line.indexOf(':');
      if (colon < 0) continue;
      final key = line.substring(0, colon);
      properties[key.split(';').first] = (
        parameters: key,
        value: _unescapeCalendarText(line.substring(colon + 1)),
      );
    }
    final start = _property(properties, 'DTSTART');
    final dateOnly = start.value.length == 8;
    final rawUrl = properties['URL']?.value;
    final taskUrl = rawUrl == null ? null : Uri.tryParse(rawUrl);
    result.add(
      AgendaEntry(
        id: 'lexue-${_property(properties, 'UID').value}',
        title: _property(properties, 'SUMMARY').value,
        kind: AgendaKind.deadline,
        startsAt: _calendarDate(start.value, start.parameters),
        allDay: dateOnly,
        notes:
            html
                .parse(properties['DESCRIPTION']?.value ?? '')
                .body
                ?.text
                .trim() ??
            '',
        course: properties['CATEGORIES']?.value ?? '',
        source: DeadlineSource.lexue,
        local: false,
        url:
            taskUrl != null &&
                taskUrl.scheme == 'https' &&
                taskUrl.host == DeadlineSource.lexue.host &&
                taskUrl.userInfo.isEmpty &&
                (taskUrl.path.startsWith('/mod/') ||
                    taskUrl.path.startsWith('/course/'))
            ? taskUrl
            : null,
      ),
    );
  }
  return result;
}

({String parameters, String value}) _property(
  Map<String, ({String parameters, String value})> properties,
  String key,
) => properties[key] ?? (throw FormatException('乐学日历事件缺少 $key'));

String _unescapeCalendarText(String value) => value.replaceAllMapped(
  RegExp(r'\\([nN,;\\])'),
  (match) => switch (match[1]) {
    'n' || 'N' => '\n',
    _ => match[1]!,
  },
);

DateTime _calendarDate(String value, String parameters) {
  final parsed = DateTime.parse(value);
  final date = DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
  );
  final timezone = parameters
      .split(';')
      .where((part) => part.startsWith('TZID='))
      .firstOrNull
      ?.substring(5)
      .replaceAll('"', '');
  if (parsed.isUtc || timezone == 'UTC') {
    return date.add(const Duration(hours: 8));
  }
  return date;
}
