import 'package:bitree/agenda/model.dart';
import 'package:bitree/core/time.dart';
import 'package:bitree/schedule/model.dart';
import 'package:bitree/schedule/ui/course_detail.dart';
import 'package:bitree/ui/sheet_layout.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  final date = DateTime.utc(2026, 10, 27);
  Course course(
    String id,
    int start,
    int end,
    String room, {
    int weekday = 2,
    List<int> weeks = const [1],
  }) => Course(
    id: id,
    name: id,
    room: room,
    weekday: weekday,
    startSection: start,
    endSection: end,
    weeks: weeks,
  );

  for (final (size, scale) in [
    (const Size(320, 640), 1.0),
    (const Size(390, 844), 1.8),
    (const Size(1200, 800), 1.0),
  ]) {
    testWidgets(
      'Next course stays in the drawer and uses only this day and week at $size, $scale',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final first = course('概率论与数理统计', 3, 4, '理教楼105');
        final next = course('数据结构', 6, 7, '综教B103');
        final last = course('JAVA语言程序设计', 11, 13, '综教A204');
        final controller = TestAppController(
          schedule: SemesterSchedule(
            term: '2026-2027-1',
            firstMonday: mondayOf(date),
            courses: [
              first,
              next,
              last,
              course('重叠课程', 4, 5, '理教楼105'),
              course('下周课程', 5, 5, '理教楼105', weeks: [2]),
              course('明天课程', 5, 5, '理教楼105', weekday: 3),
            ],
          ),
          entries: [
            AgendaEntry(
              id: 'deadline',
              title: 'DDL不能混入课程',
              kind: AgendaKind.deadline,
              startsAt: date.add(const Duration(hours: 12)),
            ),
          ],
        );
        await controller.initialize();
        await tester.pumpWidget(
          MaterialApp(
            theme: bitreeTheme(Brightness.light),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () =>
                      showCourse(context, controller, first, date: date),
                  child: const Text('课程详情'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('课程详情'));
        await tester.pumpAndSettle();
        expect(find.text('课程学习'), findsNothing);
        expect(find.text('观看直播'), findsNothing);
        expect(find.text('跨片区换楼'), findsOneWidget);
        expect(find.text(next.name), findsOneWidget);
        expect(find.text('下周课程'), findsNothing);
        expect(find.text('明天课程'), findsNothing);
        expect(find.text('DDL不能混入课程'), findsNothing);
        expect(find.text('重叠课程'), findsNothing);
        await tester.ensureVisible(find.text(next.name));
        await tester.tap(find.text(next.name));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.text('同一片区换楼'), findsOneWidget);
        expect(find.text(last.name), findsOneWidget);
        expect(find.text('跨片区换楼'), findsNothing);
        final title = tester.getRect(find.text(next.name));
        final sheet = tester.getRect(find.byType(SheetLayout));
        expect(title.top, greaterThanOrEqualTo(sheet.top));
        expect(title.bottom, lessThan(sheet.bottom));
        expect(
          tester.getSize(find.byType(SheetLayout)).width,
          lessThanOrEqualTo(560),
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('关闭'));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
      },
    );
  }
}
