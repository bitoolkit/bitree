import 'package:bitree/agenda/deadline_source.dart';
import 'package:bitree/agenda/model.dart';
import 'package:bitree/agenda/ui/agenda_detail.dart';
import 'package:bitree/agenda/ui/agenda_editor.dart';
import 'package:bitree/agenda/ui/agenda_operations.dart';
import 'package:bitree/agenda/ui/calendar_screen.dart';
import 'package:bitree/agenda/view_mode.dart';
import 'package:bitree/app/ui/settings_screen.dart';
import 'package:bitree/automation/ui/automation_screen.dart';
import 'package:bitree/schedule/model.dart';
import 'package:bitree/schedule/ui/course_editor.dart';
import 'package:bitree/schedule/ui/home_screen.dart';
import 'package:bitree/ui/sheet_layout.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  testWidgets('automation is available through unlocked developer settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TestAppController();
    await controller.initialize();
    await tester.pumpWidget(
      MaterialApp(
        theme: bitreeTheme(Brightness.light),
        home: Scaffold(
          body: SettingsScreen(
            controller: controller,
            checkingForUpdates: false,
            onCheckForUpdates: () {},
          ),
        ),
      ),
    );
    expect(find.text('开发者模式'), findsNothing);
    controller.settings.unlockDeveloperMode();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('开发者模式'), 200);
    await tester.tap(find.text('开发者模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('自动化'));
    await tester.pumpAndSettle();
    expect(find.byType(AutomationScreen), findsOneWidget);
    expect(find.text('加载 Lua 文件'), findsOneWidget);
    await tester.tap(find.text('填入示例'));
    await tester.pump();
    final editor = tester.widget<TextField>(
      find.byKey(const ValueKey('automation-source')),
    );
    expect(editor.controller!.text, contains('function filter(data)'));
    expect(editor.controller!.text, contains('table.insert(deadlines, ddl)'));
    expect(find.textContaining('运行耗时：'), findsNothing);
    await tester.runAsync(
      () => controller.automation.saveScript(editor.controller!.text),
    );
    expect(controller.automation.executionDuration, isNotNull);
    await tester.pumpAndSettle();
    final executionTime = find.textContaining(RegExp(r'\d+\.\dms · 无变更'));
    final scrollable = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(AutomationScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(executionTime, findsOneWidget);
    expect(find.textContaining('运行耗时：'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'change summary is compact and generated entries stay read-only',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final start = DateTime.utc(2026, 9, 7, 12);
      final controller = TestAppController(
        entries: [
          for (final kind in [AgendaKind.event, AgendaKind.exam])
            AgendaEntry(
              id: kind.name,
              title: kind.name,
              kind: kind,
              startsAt: start,
              endsAt: start.add(const Duration(hours: 1)),
            ),
        ],
      );
      await controller.initialize();
      await tester.runAsync(
        () => controller.automation.saveScript('''
function filter(data)
    data.events[1].title = "展示活动"
    data.exams = {}
    table.insert(data.deadlines, {title = "脚本作业", startsAt = "2026-09-07T12:00:00.000Z"})
    return data
end
'''),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: bitreeTheme(Brightness.light),
          home: AutomationScreen(controller: controller.automation),
        ),
      );
      expect(
        find.textContaining(RegExp(r'\d+\.\dms · 增 1 删 1 改 1')),
        findsOneWidget,
      );
      final entry = controller.automation.entries.firstWhere(
        (entry) => entry.isDeadline,
      );
      final context = tester.element(find.byType(AutomationScreen));
      final sheet = showAgendaEntry(
        context,
        controller.agenda,
        entry,
        automation: controller.automation,
      );
      await tester.pumpAndSettle();
      expect(find.text('脚本作业'), findsWidgets);
      expect(find.byTooltip('删除'), findsNothing);
      expect(find.byType(SheetActionBar), findsNothing);
      expect(
        await deleteAgendaEntry(
          context,
          controller.agenda,
          entry,
          confirm: false,
        ),
        isFalse,
      );
      expect(controller.agenda.entries, hasLength(2));
      Navigator.of(tester.element(find.text('脚本作业').first)).pop();
      await tester.pumpAndSettle();
      await sheet;
      await tester.runAsync(
        () => controller.automation.saveScript('''
function filter(data)
    data.exams = {}
    return data
end
'''),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining(RegExp(r'\d+\.\dms · 删 1')), findsOneWidget);
    },
  );

  testWidgets('home and agenda consume the same presentation projection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.utc(2026, 9, 7, 8);
    final schedule = SemesterSchedule(
      term: '2026-2027-1',
      firstMonday: now,
      courses: [
        Course(
          id: 'c',
          name: '原课程',
          weekday: 1,
          startSection: 1,
          endSection: 2,
          weeks: [1],
        ),
      ],
    );
    final old = AgendaEntry(
      id: 'old',
      title: '旧作业',
      kind: AgendaKind.deadline,
      startsAt: now.add(const Duration(hours: 4)),
      source: DeadlineSource.lexue,
    );
    final current = AgendaEntry(
      id: 'new',
      title: '新作业',
      kind: AgendaKind.deadline,
      startsAt: now.add(const Duration(hours: 4)),
      source: DeadlineSource.eclass,
    );
    final controller = TestAppController(
      schedule: schedule,
      entries: [old, current],
      initialWeek: 1,
    );
    await controller.initialize();
    await controller.settings.setAgendaViewMode(AgendaViewMode.list);
    await tester.pumpWidget(
      MaterialApp(
        theme: bitreeTheme(Brightness.light),
        home: Scaffold(
          body: HomeScreen(controller: controller, now: now),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('原课程'), findsWidgets);
    await tester.runAsync(
      () => controller.automation.saveScript('''
function filter(data)
    data.courses[1].name = "展示课程"
    local deadlines = {}
    for _, ddl in ipairs(data.deadlines) do
        if ddl.source ~= "lexue" then
            ddl.title = "展示作业"
            table.insert(deadlines, ddl)
        end
    end
    data.deadlines = deadlines
    return data
end
'''),
    );
    await tester.pumpAndSettle();
    expect(find.text('展示课程'), findsWidgets);
    expect(find.text('原课程'), findsNothing);
    expect(find.text('旧作业'), findsNothing);
    await tester.pumpWidget(
      MaterialApp(
        theme: bitreeTheme(Brightness.light),
        home: Scaffold(
          body: CalendarScreen(controller: controller, now: now),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('展示作业'), findsWidgets);
    expect(find.text('旧作业'), findsNothing);
    expect(find.text('新作业'), findsNothing);
    await tester.runAsync(() => controller.automation.setEnabled(false));
    await tester.pumpAndSettle();
    expect(find.text('旧作业'), findsWidgets);
    expect(find.text('新作业'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('editors resolve presentation copies to original records', (
    tester,
  ) async {
    final course = Course(
      id: 'course',
      name: '原课程',
      weekday: 1,
      startSection: 1,
      endSection: 2,
      weeks: [1],
    );
    final schedule = SemesterSchedule(
      term: '2026-2027-1',
      firstMonday: DateTime.utc(2026, 9, 7),
      courses: [course],
    );
    final entry = AgendaEntry(
      id: 'ddl',
      title: '原作业',
      kind: AgendaKind.deadline,
      startsAt: DateTime.utc(2026, 9, 7, 12),
    );
    final controller = TestAppController(schedule: schedule, entries: [entry]);
    await controller.initialize();
    await tester.runAsync(
      () => controller.automation.saveScript('''
function filter(data)
    data.courses[1].name = "展示课程"
    data.deadlines[1].title = "展示作业"
    return data
end
'''),
    );
    expect(controller.automation.error, isNull);
    await tester.pumpWidget(
      MaterialApp(
        theme: bitreeTheme(Brightness.light),
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                TextButton(
                  onPressed: () => editCourse(
                    context,
                    controller.timetable,
                    course: controller.automation.schedule!.courses.single,
                  ),
                  child: const Text('课程编辑'),
                ),
                TextButton(
                  onPressed: () => editAgenda(
                    context,
                    controller.agenda,
                    entry: controller.automation.entries.single,
                  ),
                  child: const Text('DDL 编辑'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('课程编辑'));
    await tester.pumpAndSettle();
    expect(find.text('原课程'), findsOneWidget);
    expect(find.text('展示课程'), findsNothing);
    Navigator.of(tester.element(find.text('原课程'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('DDL 编辑'));
    await tester.pumpAndSettle();
    expect(find.text('原作业'), findsOneWidget);
    expect(find.text('展示作业'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
