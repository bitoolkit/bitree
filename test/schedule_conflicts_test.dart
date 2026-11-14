import 'package:bitree/agenda/calendar.dart';
import 'package:bitree/l10n/app_localizations_zh.dart';
import 'package:bitree/l10n/formats.dart';
import 'package:bitree/schedule/layout.dart';
import 'package:bitree/schedule/model.dart';
import 'package:bitree/schedule/ui/conflicting_courses.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  final date = DateTime.utc(2026, 10, 30);

  Course course(
    String id,
    String name, {
    required int start,
    required int end,
    String room = '',
  }) => Course(
    id: id,
    name: name,
    room: room,
    weekday: DateTime.friday,
    startSection: start,
    endSection: end,
    weeks: [1],
  );

  test(
    'Touching courses stay separate while chained overlaps remain one block',
    () {
      final touching = [
        course('first', '第一门', start: 1, end: 2),
        course('second', '第二门', start: 3, end: 4),
      ].map((course) => CalendarItem.course(course, date)).toList();

      final separate = groupCalendarItems(touching, date);
      expect(separate, hasLength(2));
      expect(separate.map((block) => block.start), [0, 2]);

      final chained = [
        course('a', '课程 A', start: 3, end: 5),
        course('b', '课程 B', start: 4, end: 7),
        course('c', '课程 C', start: 6, end: 8),
        course('d', '课程 D', start: 8, end: 10),
      ].map((course) => CalendarItem.course(course, date)).toList();

      final grouped = groupCalendarItems(chained, date);
      expect(grouped, hasLength(1));
      expect(grouped.single.start, 2);
      expect(grouped.single.end, 10);
      expect(grouped.single.items.map((item) => item.stableTitle), [
        '课程 A',
        '课程 B',
        '课程 C',
        '课程 D',
      ]);
    },
  );

  testWidgets(
    'A narrow conflict card lists every course and its exact sections',
    (tester) async {
      final courses = [
        course('a', '马克思主义基本原理', start: 3, end: 5),
        course('b', '数据结构', start: 4, end: 7),
        course('c', '概率论与数理统计', start: 6, end: 8),
        course('d', '大学物理实验', start: 8, end: 10),
      ];
      final app = TestAppController(
        schedule: SemesterSchedule(
          term: '2026-2027-1',
          firstMonday: DateTime.utc(2026, 10, 26),
          courses: courses,
        ),
      );
      await app.initialize();

      await tester.pumpWidget(
        MaterialApp(
          theme: bitreeTheme(Brightness.light),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 48,
                height: 448,
                child: ConflictingCourses(
                  courses: courses,
                  controller: app.timetable,
                  isToday: true,
                  date: date,
                ),
              ),
            ),
          ),
        ),
      );

      final l10n = AppLocalizationsZh();
      expect(find.text('4门'), findsOneWidget);
      for (final item in courses) {
        expect(find.text(item.name), findsOneWidget);
        expect(find.text(localizedCourseSection(l10n, item)), findsOneWidget);
      }
      expect(find.text('教室待定'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byType(ConflictingCourses));
      await tester.pumpAndSettle();
      expect(find.text('选择课程'), findsOneWidget);
      final sheet = find.byType(BottomSheet);
      expect(sheet, findsOneWidget);
      for (final item in courses) {
        expect(
          find.descendant(of: sheet, matching: find.text(item.name)),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'A wide conflict card fills its height with distinct course bands',
    (tester) async {
      final courses = [
        course('a', 'erwer', room: '文萃楼 F704', start: 6, end: 7),
        course('b', '大学物理 A II', room: '理教楼 105', start: 6, end: 7),
      ];
      final app = TestAppController(
        schedule: SemesterSchedule(
          term: '2026-2027-1',
          firstMonday: DateTime.utc(2026, 10, 26),
          courses: courses,
        ),
      );
      await app.initialize();

      await tester.pumpWidget(
        MaterialApp(
          theme: bitreeTheme(Brightness.light),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 240,
                height: 180,
                child: ConflictingCourses(
                  courses: courses,
                  controller: app.timetable,
                  isToday: false,
                  date: date,
                ),
              ),
            ),
          ),
        ),
      );

      final first = tester.getRect(
        find.byKey(const ValueKey('conflict-course-a')),
      );
      final second = tester.getRect(
        find.byKey(const ValueKey('conflict-course-b')),
      );
      expect(first.height, closeTo(second.height, 1));
      expect(first.height, greaterThan(40));
      expect(first.bottom, lessThan(second.top));
      expect(find.text('文萃楼 F704'), findsOneWidget);
      expect(find.text('理教楼 105'), findsOneWidget);
      expect(find.byType(Tooltip), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
