import 'dart:io';

import 'package:bitree/academics/model.dart';
import 'package:bitree/academics/ui/credit_targets_dialog.dart';
import 'package:bitree/agenda/controller.dart';
import 'package:bitree/agenda/model.dart';
import 'package:bitree/agenda/ui/agenda_editor.dart';
import 'package:bitree/agenda/ui/clear_deadlines_sheet.dart';
import 'package:bitree/agenda/ui/deleted_deadlines.dart';
import 'package:bitree/schedule/model.dart';
import 'package:bitree/schedule/store.dart';
import 'package:bitree/schedule/ui/course_editor.dart';
import 'package:bitree/schedule/ui/week_range_dialog.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

class _FailingAgendaStore extends MemoryAgendaStore {
  _FailingAgendaStore([super.entries]);

  @override
  Future<void> write(List<AgendaEntry> entries) async {
    throw const FileSystemException('agenda write failed');
  }
}

class _FailingScheduleStore extends MemoryScheduleStore {
  _FailingScheduleStore(SemesterSchedule schedule)
    : super(schedules: [schedule]);

  @override
  Future<void> write(ScheduleLibrary library) async {
    throw const FileSystemException('schedule write failed');
  }
}

class _FailingAcademicStore extends MemoryAcademicStore {
  @override
  Future<void> write(String account, AcademicRecord record) async {
    throw const FileSystemException('academic write failed');
  }
}

Future<void> _host(
  WidgetTester tester,
  Future<void> Function(BuildContext context) open,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: bitreeTheme(Brightness.light),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => open(context),
            child: const Text('打开'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Agenda save failure keeps the editor and its input visible', (
    tester,
  ) async {
    final app = TestAppController(
      agenda: AgendaController(_FailingAgendaStore()),
    );
    await app.initialize();
    await _host(
      tester,
      (context) => editAgenda(context, app.agenda, kind: AgendaKind.deadline),
    );

    await tester.enterText(find.byType(TextFormField).first, '保留的作业');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('未能保存更改，请重试。'), findsOneWidget);
    expect(find.text('保留的作业'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Course and week-range writes explain failures in place', (
    tester,
  ) async {
    final schedule = SemesterSchedule(
      term: '2026-2027-1',
      firstMonday: DateTime.utc(2026, 10, 26),
      courses: const [],
    );
    final app = TestAppController(
      scheduleStore: _FailingScheduleStore(schedule),
    );
    await app.initialize();
    await _host(tester, (context) => editCourse(context, app.timetable));

    await tester.enterText(find.byType(TextFormField).first, '保留的课程');
    await tester.tap(find.text('保存课程'));
    await tester.pumpAndSettle();
    expect(find.text('未能保存更改，请重试。'), findsOneWidget);
    expect(find.text('保留的课程'), findsOneWidget);

    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    await _host(tester, (context) => manageTermWeeks(context, app.timetable));
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();
    expect(find.text('未能保存更改，请重试。'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Clear deadlines failure remains actionable in its sheet', (
    tester,
  ) async {
    final entry = AgendaEntry(
      id: 'deadline',
      title: '课程作业',
      kind: AgendaKind.deadline,
      startsAt: DateTime.utc(2026, 11, 2, 23, 59),
    );
    final app = TestAppController(
      agenda: AgendaController(_FailingAgendaStore([entry])),
    );
    await app.initialize();
    await _host(tester, (context) => showClearDeadlines(context, app.agenda));

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '删除 1 条 DDL'));
    await tester.pumpAndSettle();

    expect(find.text('未能删除，请重试。'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Restore failure keeps deleted DDL available for retry', (
    tester,
  ) async {
    final entry = AgendaEntry(
      id: 'deleted',
      title: '待恢复作业',
      kind: AgendaKind.deadline,
      startsAt: DateTime.utc(2026, 11, 2, 23, 59),
      deleted: true,
    );
    final app = TestAppController(
      agenda: AgendaController(_FailingAgendaStore([entry])),
    );
    await app.initialize();
    await _host(tester, (context) => showDeletedDeadlines(context, app.agenda));

    await tester.tap(find.byTooltip('恢复'));
    await tester.pumpAndSettle();

    expect(find.text('未能恢复，请重试。'), findsOneWidget);
    expect(find.text('待恢复作业'), findsOneWidget);
    expect(app.agenda.deletedDeadlines.single.id, 'deleted');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Credit target save failure remains visible and retryable', (
    tester,
  ) async {
    final app = TestAppController(academicStore: _FailingAcademicStore());
    await app.initialize();
    await app.academics.load('student');
    await _host(tester, (context) => editCreditTargets(context, app.academics));

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('未能保存更改，请重试。'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
