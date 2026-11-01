import 'package:bitree/l10n/app_localizations_en.dart';
import 'package:bitree/l10n/app_localizations_zh.dart';
import 'package:bitree/schedule/ics.dart';
import 'package:bitree/schedule/model.dart';
import 'package:flutter_test/flutter_test.dart';

SemesterSchedule _schedule() => SemesterSchedule(
  term: '2026-2027-1',
  firstMonday: DateTime.utc(2026, 10, 26),
  courses: [
    Course(
      id: 'math-course',
      name: 'Linear Algebra',
      teacher: 'Ada',
      room: 'Room 101',
      number: 'M1',
      weekday: 1,
      startSection: 5,
      endSection: 6,
      weeks: [3],
    ),
  ],
);

void main() {
  test('ICS export uses English metadata and description labels', () {
    final ics = scheduleToIcs(_schedule(), AppLocalizationsEn());

    expect(ics, contains('PRODID:-//BITree//Schedule//EN\r\n'));
    expect(ics, contains('X-WR-CALNAME:BITree Fall 2026–2027\r\n'));
    expect(
      ics,
      contains(
        r'DESCRIPTION:Week 3\, Sections 5–6\nInstructor: Ada\nCourse number: M1',
      ),
    );
  });

  test('ICS export keeps Chinese metadata and description labels', () {
    final ics = scheduleToIcs(_schedule(), AppLocalizationsZh());

    expect(ics, contains('PRODID:-//BITree//Schedule//ZH-CN\r\n'));
    expect(ics, contains('X-WR-CALNAME:BITree 2026–2027 秋季学期\r\n'));
    expect(ics, contains(r'DESCRIPTION:第 3 周 第 5–6 节\n教师：Ada\n课程号：M1'));
  });
}
