import 'package:bitree/academics/model.dart';
import 'package:bitree/academics/ui/grades_screen.dart';
import 'package:bitree/school/storage.dart';
import 'package:bitree/ui/sheet_layout.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

CourseGrade _grade({
  required String name,
  required String result,
  required String term,
  required String attribute,
  required String category,
}) => CourseGrade(
  id: name,
  number: name,
  name: name,
  term: term,
  credits: 2,
  result: result,
  attribute: attribute,
  category: category,
);

Future<TestAppController> _appWithGrades(List<CourseGrade> grades) async {
  final store = MemoryAcademicStore();
  store.accounts['student'] = AcademicRecord(
    grades: grades,
    gradesUpdatedAt: DateTime.utc(2026, 11, 4),
  );
  final app = TestAppController(
    academicStore: store,
    schoolStorage: MemorySchoolStorage(
      credentials: const SchoolCredentials(
        username: 'student',
        password: 'password',
      ),
    ),
  );
  await app.initialize();
  return app;
}

void main() {
  testWidgets('A specific course updates the score scope and summary', (
    tester,
  ) async {
    final app = await _appWithGrades([
      _grade(
        name: '高等数学',
        result: '90',
        term: '2026-2027-1',
        attribute: '必修',
        category: '专业课',
      ),
      _grade(
        name: '大学物理',
        result: '75',
        term: '2026-2027-1',
        attribute: '必修',
        category: '专业课',
      ),
      _grade(
        name: '摄影',
        result: '85',
        term: '2026-2027-2',
        attribute: '选修',
        category: '通识课',
      ),
      _grade(
        name: '体育',
        result: '良好',
        term: '2026-2027-2',
        attribute: '必修',
        category: '通识课',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: bitreeTheme(Brightness.light),
        home: GradesScreen(controller: app),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('计分课程'), findsOneWidget);
    expect(find.text('80 分及以上'), findsOneWidget);
    expect(find.text('3 门'), findsOneWidget);
    expect(find.text('2 门'), findsOneWidget);
    expect(find.text('66.7%'), findsOneWidget);

    await tester.tap(find.byKey(const Key('grade-scope-button')));
    await tester.pumpAndSettle();
    final sheet = find.byType(SheetLayout);
    expect(sheet, findsOneWidget);
    final course = find.descendant(of: sheet, matching: find.text('高等数学'));
    await tester.ensureVisible(course);
    await tester.pumpAndSettle();
    await tester.tap(course);
    await tester.pump();
    await tester.tap(find.text('应用'));
    await tester.pumpAndSettle();

    expect(find.text('计分课程'), findsOneWidget);
    expect(find.text('1 门'), findsNWidgets(2));
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('统计范围（已筛选）'), findsOneWidget);
    expect(find.text('高等数学'), findsOneWidget);
    expect(find.text('大学物理'), findsNothing);
    expect(find.text('摄影'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('The score scope stays usable on a narrow large-text screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = await _appWithGrades([
      _grade(
        name: '一门名称很长的专业基础课程',
        result: '88',
        term: '2026-2027-1',
        attribute: '必修',
        category: '专业基础课程',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: bitreeTheme(Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: GradesScreen(controller: app),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('grade-scope-button')));
    await tester.tap(find.byKey(const Key('grade-scope-button')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(SheetLayout),
        matching: find.text('统计范围'),
      ),
      findsOneWidget,
    );
    expect(find.text('应用').hitTestable(), findsOneWidget);
    expect(find.text('全部课程'), findsOneWidget);

    final course = find.descendant(
      of: find.byType(SheetLayout),
      matching: find.text('一门名称很长的专业基础课程'),
    );
    await tester.ensureVisible(course);
    await tester.pumpAndSettle();
    await tester.tap(course);
    await tester.pump();
    await tester.tap(find.text('应用'));
    await tester.pumpAndSettle();

    expect(find.text('统计范围（已筛选）').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
