import '../agenda/model.dart';
import '../core/json.dart';
import 'session.dart';

Future<({String term, List<AgendaEntry> exams})> fetchSchoolExams(
  SchoolSession session, {
  required String term,
}) async {
  await session.request(session.network.examApp, stopAtLogin: true);
  final response = await session.json(
    'modules/ksap/cxxsksap.do',
    app: 'wdksapMobile',
    form: {'XNXQDM': term, '*order': '-KSRQ'},
  );
  final rows = [
    for (final row in jsonListField(
      jsonObjectField(jsonObjectField(response, 'datas'), 'cxxsksap'),
      'rows',
    ))
      jsonObject(row, 'cxxsksap.rows[]'),
  ];
  final exams = rows.map((row) {
    final date = jsonDateTime('KSRQ', row['KSRQ']);
    final times = RegExp(r'(\d{2}):(\d{2})')
        .allMatches(jsonStringField(row, 'KSSJMS'))
        .toList();
    if (times.length < 2) {
      throw const FormatException('考试时间格式不正确');
    }

    DateTime at(RegExpMatch time) => DateTime.utc(
      date.year,
      date.month,
      date.day,
      int.parse(time[1]!),
      int.parse(time[2]!),
    );

    final start = at(times[0]);
    final subject = jsonStringField(row, 'KCM');
    final courseCode = jsonStringField(row, 'KCH');
    return AgendaEntry(
      id: 'exam-$term-$courseCode-$subject-${start.toIso8601String()}',
      title: subject,
      kind: AgendaKind.exam,
      startsAt: start,
      endsAt: at(times[1]),
      location: jsonStringFieldOrNull(row, 'JASMC') ?? '',
      notes: [
        if (row['ZWH'] case final String seat when seat.isNotEmpty) '座位号：$seat',
        if (row['KSMC'] case final String mode when mode.isNotEmpty) mode,
        if (row['ZJJSXM'] case final String teacher when teacher.isNotEmpty)
          '教师：$teacher',
      ].join('\n'),
      term: term,
      local: false,
    );
  }).toList();
  return (term: term, exams: exams);
}
