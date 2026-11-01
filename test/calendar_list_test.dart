import 'package:bitree/agenda/calendar.dart';
import 'package:bitree/agenda/controller.dart';
import 'package:bitree/agenda/deadline_source.dart';
import 'package:bitree/agenda/model.dart';
import 'package:bitree/agenda/ui/calendar_list.dart';
import 'package:bitree/agenda/ui/completion_text.dart';
import 'package:bitree/schedule/model.dart';
import 'package:bitree/schedule/ui/timetable_header.dart';
import 'package:bitree/ui/sheet_layout.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/row_swipe.dart';
import 'support/test_app.dart';

final _date = calendarDate(campusNow()).add(const Duration(days: 5));

AgendaEntry _deadline({
  int id = 1,
  DateTime? date,
  bool done = false,
  bool detailed = false,
}) => AgendaEntry(
  id: 'deadline$id',
  title: detailed ? '第$id章实验报告：线性表与链表的实现、测试及复杂度分析' : '第五章作业$id',
  kind: AgendaKind.deadline,
  startsAt: (date ?? _date).add(
    Duration(hours: id == 1 ? 18 : 23, minutes: id == 1 ? 0 : 59),
  ),
  source: DeadlineSource.eclass,
  course: detailed ? '2026–2027 秋季学期 · 概率论与数理统计中文班' : '高数数学',
  done: done,
);

Future<TestAppController> _open(
  WidgetTester tester,
  List<AgendaEntry> entries, {
  Size size = const Size(390, 844),
  double scale = 1,
  Brightness brightness = Brightness.light,
  List<CalendarItem>? picker,
  SemesterSchedule? schedule,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final agenda = AgendaController(MemoryAgendaStore(entries));
  final controller = TestAppController(agenda: agenda, schedule: schedule);
  await controller.initialize();

  await tester.pumpWidget(
    MaterialApp(
      theme: bitreeTheme(brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => picker == null
              ? TimetableHeader(
                  controller: controller,
                  monday: mondayOf(_date),
                  now: campusNow(),
                  gutterWidth: 40,
                  todayBackground: Colors.transparent,
                )
              : Center(
                  child: TextButton(
                    onPressed: () => showCalendarItems(
                      context,
                      controller,
                      '选择安排',
                      picker,
                      showDates: true,
                    ),
                    child: const Text('选择安排'),
                  ),
                ),
        ),
      ),
    ),
  );
  if (picker == null) {
    await tester.tap(
      find.bySemanticsLabel(
        RegExp('${_date.month}月${_date.day}日${weekdays[_date.weekday - 1]}'),
      ),
    );
  } else {
    await tester.tap(find.text('选择安排'));
  }
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  return controller;
}

void main() {
  testWidgets('The day drawer shares full left completion and right deletion', (
    tester,
  ) async {
    final controller = await _open(tester, [_deadline(), _deadline(id: 2)]);
    await swipeRow(
      tester,
      find.byKey(const ValueKey('deadline1')),
      const Offset(-240, 0),
    );
    await tester.pumpAndSettle();
    expect(
      controller.agenda.entries
          .firstWhere((entry) => entry.id == 'deadline1')
          .done,
      isTrue,
    );
    expect(find.text('已完成 1'), findsOneWidget);
    await swipeRow(
      tester,
      find.byKey(const ValueKey('deadline2')),
      const Offset(240, 0),
    );
    await tester.pumpAndSettle();
    expect(controller.agenda.entries.single.id, 'deadline1');
    expect(controller.agenda.deletedDeadlines.single.id, 'deadline2');
    expect(tester.takeException(), isNull);
  });

  for (final (size, scale) in [
    (const Size(390, 844), 1.0),
    (const Size(320, 640), 1.0),
    (const Size(320, 640), 1.8),
  ]) {
    testWidgets(
      'A title without secondary content aligns with its completion control at $size, $scale',
      (tester) async {
        final entry = AgendaEntry(
          id: 'plain',
          title: '1',
          kind: AgendaKind.deadline,
          startsAt: _date.add(const Duration(hours: 1, minutes: 11)),
        );
        await _open(tester, [entry], size: size, scale: scale);
        final title = tester.getRect(find.byType(CompletionText));
        final control = tester.getRect(find.byType(Checkbox));
        expect(title.center.dy, closeTo(control.center.dy, 0.5));
        expect(find.text('01:11'), findsOneWidget);
        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();
        expect(find.text('已完成 1'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'The entry description appears below its title, with course context retained',
    (tester) async {
      final entry = AgendaEntry(
        id: 'with-notes',
        title: '第二章作业',
        kind: AgendaKind.deadline,
        startsAt: _date.add(const Duration(hours: 18)),
        notes: '完成第二章习题，提交 PDF。',
        course: '离散数学',
      );
      await _open(tester, [entry]);
      final title = tester.getRect(find.byType(CompletionText));
      final description = tester.getRect(find.text(entry.notes));
      final course = tester.getRect(find.text(entry.course));
      expect(description.top, greaterThan(title.bottom));
      expect(description.left, title.left);
      expect(course.top, greaterThan(description.bottom));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Tapping the timetable date shows compact pending entries with prominent times',
    (tester) async {
      final entry = _deadline();
      await _open(tester, [
        entry,
        _deadline(id: 2, done: true),
        _deadline(id: 3, date: _date.add(const Duration(days: 1))),
      ]);
      expect(find.text(agendaDateLabel(_date)), findsOneWidget);
      expect(find.text('1项日程'), findsOneWidget);
      expect(find.text(entry.title), findsWidgets);
      expect(find.text('第五章作业2'), findsNothing);
      expect(find.text('第五章作业3'), findsNothing);
      expect(find.byType(Checkbox), findsOneWidget);
      expect(find.text('高数数学'), findsOneWidget);
      expect(find.text('18:00'), findsOneWidget);
      expect(find.text('截止'), findsOneWidget);
      final time = tester.widget<Text>(find.text('18:00'));
      final source = tester.widget<Text>(find.text('高数数学'));
      expect(time.style!.fontSize, greaterThan(source.style!.fontSize!));
      expect(tester.getSize(find.byType(BottomSheet)).height, lessThan(350));
    },
  );

  testWidgets(
    'A day entry opens the existing detail sheet without leaving two sheets',
    (tester) async {
      final entry = _deadline();
      await _open(tester, [entry]);
      await tester.tap(find.text(entry.title).first);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('1项日程'), findsNothing);
      expect(find.text('标记完成'), findsOneWidget);
      expect(find.text('18:00  截止', findRichText: true), findsOneWidget);
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Day checklist updates in place, can restore completed DDL, and excludes courses',
    (tester) async {
      final entry = _deadline();
      final course = Course(
        id: 'course',
        name: '课程不属于日程',
        weekday: _date.weekday,
        startSection: 1,
        endSection: 2,
        weeks: [1],
      );
      final controller = await _open(
        tester,
        [entry],
        schedule: SemesterSchedule(
          term: '2026-2027-1',
          firstMonday: mondayOf(_date),
          courses: [course],
        ),
      );
      expect(find.text('1项日程'), findsOneWidget);
      expect(find.text(course.name), findsNothing);
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(controller.agenda.entries.single.done, isTrue);
      expect(find.text('没有未完成的日程'), findsOneWidget);
      expect(find.text('1项日程'), findsNothing);
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.tap(find.text('已完成 1'));
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(controller.agenda.entries.single.done, isFalse);
      expect(find.text('1项日程'), findsOneWidget);
      expect(find.text('已完成 1'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (size, scale, brightness) in [
    (const Size(320, 640), 1.0, Brightness.light),
    (const Size(320, 640), 1.8, Brightness.dark),
    (const Size(390, 844), 1.6, Brightness.light),
    (const Size(1440, 900), 1.0, Brightness.dark),
  ]) {
    testWidgets(
      'Long day lists scroll with a reachable fixed header at $size, $scale',
      (tester) async {
        final entries = [
          for (var id = 1; id <= 12; id++) _deadline(id: id, detailed: true),
        ];
        await _open(
          tester,
          entries,
          size: size,
          scale: scale,
          brightness: brightness,
        );
        final closeBefore = tester.getRect(find.byTooltip('关闭'));
        await tester.scrollUntilVisible(
          find.text(entries.last.title).first,
          200,
          scrollable: find
              .descendant(
                of: find.byType(SheetLayout),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(tester.getRect(find.byTooltip('关闭')), closeBefore);
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

  testWidgets('An empty date remains compact', (tester) async {
    await _open(tester, []);
    expect(find.text('没有未完成的日程'), findsOneWidget);
    expect(tester.getSize(find.byType(BottomSheet)).height, lessThan(280));
    expect(find.text('0项日程'), findsNothing);
  });

  testWidgets(
    'The shared picker preserves overdue status and course navigation',
    (tester) async {
      final overdue = _deadline(date: DateTime.utc(2020, 1, 1));
      final course = Course(
        id: 'course',
        name: '离散数学',
        weekday: 1,
        startSection: 3,
        endSection: 4,
        weeks: [1],
        room: '理教楼105',
      );
      final done = _deadline(id: 2, done: true);
      await _open(
        tester,
        [overdue, done],
        picker: [
          CalendarItem.agenda(overdue),
          CalendarItem.agenda(done),
          CalendarItem.course(course, _date),
        ],
      );
      expect(find.text('已逾期'), findsOneWidget);
      final overdueTime = tester.widget<Text>(find.text('18:00'));
      expect(
        overdueTime.style!.color,
        bitreeTheme(Brightness.light).colorScheme.error,
      );
      final completed = tester
          .widgetList<CompletionText>(find.byType(CompletionText))
          .where((widget) => widget.completed)
          .toList();
      expect(completed, hasLength(1));
      expect(completed.single.text, done.title);
      await tester.ensureVisible(find.text(course.name).first);
      await tester.tap(find.text(course.name).first);
      await tester.pumpAndSettle();
      expect(find.text('编辑课程'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
