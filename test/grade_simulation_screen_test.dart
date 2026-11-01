import 'dart:math' as math;

import 'package:bitree/academics/ui/grade_simulation_screen.dart';
import 'package:bitree/schedule/model.dart';
import 'package:bitree/ui/editor_sheet.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

Finder input(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

void main() {
  final course = Course(
    id: 'course',
    name: '概率论与数理统计',
    weekday: DateTime.monday,
    startSection: 3,
    endSection: 4,
    weeks: [1],
  );
  final schedule = SemesterSchedule(
    term: '2026-2027-1',
    firstMonday: DateTime.utc(2026, 10, 26),
    courses: [course],
  );

  Future<void> showSimulation(
    WidgetTester tester,
    TestAppController controller,
    Size size,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
    await controller.initialize();
    await tester.pumpWidget(
      MaterialApp(
        theme: bitreeTheme(Brightness.light),
        home: GradeSimulationScreen(controller: controller),
      ),
    );
    await tester.tap(find.text('添加课程'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('添加试算课程'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    final sheet = find.byType(EditorSheet);
    expect(sheet, findsOneWidget);
    expect(tester.getSize(sheet).width, math.min(560, size.width));
  }

  for (final size in [const Size(390, 844), const Size(1200, 800)]) {
    testWidgets('Select, save and edit a course at width ${size.width}', (
      tester,
    ) async {
      await showSimulation(tester, TestAppController(schedule: schedule), size);
      await tester.tap(find.text('手动填写'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(course.name));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(input('课程名称')).controller!.text,
        course.name,
      );
      if (size.width < 600) {
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(input('课程学分'));
      await tester.enterText(input('课程学分'), '3');
      await tester.ensureVisible(input('预计成绩'));
      await tester.enterText(input('预计成绩'), '90');
      final save = find.widgetWithText(FilledButton, '保存');
      expect(
        tester.getRect(save).bottom,
        lessThan(size.height - tester.view.viewInsets.bottom),
      );
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('3.80'), findsOneWidget);

      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      final tile = find.widgetWithText(ListTile, course.name);
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('修改试算课程'), findsOneWidget);
      await tester.ensureVisible(input('预计成绩'));
      await tester.enterText(input('预计成绩'), '88');
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('3.70'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Manual simulation works without imported courses', (
    tester,
  ) async {
    await showSimulation(tester, TestAppController(), const Size(390, 844));
    expect(find.text('手动填写'), findsNothing);
    await tester.enterText(input('课程名称'), '高等数学');
    await tester.enterText(input('课程学分'), '5');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, '高等数学'), findsOneWidget);
    expect(find.text('3.60'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
