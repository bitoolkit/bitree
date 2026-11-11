import 'dart:async';

import 'package:bitree/agenda/agenda_color.dart';
import 'package:bitree/agenda/controller.dart';
import 'package:bitree/agenda/deadline_source.dart';
import 'package:bitree/agenda/model.dart';
import 'package:bitree/agenda/ui/agenda_detail.dart';
import 'package:bitree/agenda/ui/completion_text.dart';
import 'package:bitree/l10n/app_localizations_zh.dart';
import 'package:bitree/l10n/formats.dart';
import 'package:bitree/ui/sheet_layout.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  final url = Uri.https('lexue.bit.edu.cn', '/mod/assign/view.php', {
    'id': '42',
  });
  AgendaEntry deadline({
    bool detailed = false,
    bool allDay = false,
    int tailDays = 4,
  }) =>
      AgendaEntry(
        id: 'assignment',
        title: detailed ? '第三章作业：线性表与链表的实现、测试和复杂度分析' : '1',
        kind: AgendaKind.deadline,
        startsAt: DateTime.utc(2020, 10, 27, 1, 11),
        allDay: allDay,
        tailDays: tailDays,
        course: detailed ? '2026–2027 秋季学期 · 数据结构中文班' : '',
        source: detailed ? DeadlineSource.lexue : null,
        url: detailed ? url : null,
        location: detailed ? '文萃楼F704，计算机实验室' : '',
        notes: detailed
            ? List.filled(20, '提交源码和实验报告，说明边界条件与测试结果。').join('\n')
            : '',
      );

  Future<TestAppController> open(
    WidgetTester tester,
    AgendaEntry entry, {
    Size size = const Size(390, 844),
    double scale = 1,
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final agenda = AgendaController(MemoryAgendaStore([entry]));

    final controller = TestAppController(agenda: agenda);

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
            builder: (context) => Center(
              child: TextButton(
                onPressed: () =>
                    showAgendaEntry(context, controller.agenda, entry),
                child: const Text('打开详情'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开详情'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    return controller;
  }

  Finder presetColor(AgendaColor color) => find
      .byWidgetPredicate(
        (widget) =>
            widget is ColorIndicator && widget.color.toARGB32() == color.value,
      )
      .first;

  testWidgets(
    'A sparse deadline has one title, a prominent time and a secondary edit action',
    (tester) async {
      final entry = deadline();
      await open(tester, entry);
      final title = tester.widget<Text>(find.text(entry.title).first);
      final category = tester.widget<Text>(find.text('DDL'));
      expect(title.style!.fontSize, greaterThan(category.style!.fontSize!));
      expect(find.text('已逾期'), findsOneWidget);
      expect(find.text('01:11  截止', findRichText: true), findsOneWidget);
      expect(find.textContaining('已截止'), findsNothing);
      expect(find.byType(CompletionText), findsOneWidget);
      expect(find.widgetWithText(TextButton, '编辑'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '标记完成'), findsOneWidget);
      expect(tester.getSize(find.byType(SheetLayout)).height, lessThan(450));
    },
  );

  for (final (size, scale, brightness) in [
    (const Size(320, 640), 1.0, Brightness.light),
    (const Size(390, 844), 1.6, Brightness.light),
    (const Size(320, 640), 1.8, Brightness.dark),
    (const Size(1440, 900), 1.0, Brightness.dark),
  ]) {
    testWidgets(
      'Long details scroll while actions stay visible at $size, $scale, $brightness',
      (tester) async {
        final entry = deadline(detailed: true);
        await open(
          tester,
          entry,
          size: size,
          scale: scale,
          brightness: brightness,
        );
        final complete = find.widgetWithText(FilledButton, '标记完成');
        final sheet = tester.getRect(find.byType(SheetLayout));
        expect(sheet.width, lessThanOrEqualTo(560));
        expect(
          tester.getRect(complete).bottom,
          lessThanOrEqualTo(size.height - 12),
        );
        await tester.scrollUntilVisible(
          find.text('备注'),
          180,
          scrollable: find
              .descendant(
                of: find.byType(SheetLayout),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.text('打开作业'), findsOneWidget);
        expect(
          tester.getRect(complete).bottom,
          lessThanOrEqualTo(size.height - 12),
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('关闭'));
        await tester.pumpAndSettle();
        expect(find.byType(SheetLayout), findsNothing);
      },
    );
  }

  testWidgets(
    'Completing and restoring a deadline update the same sheet without striking metadata',
    (tester) async {
      final entry = deadline(detailed: true);
      final controller = await open(tester, entry);
      await tester.tap(find.text('标记完成'));
      await tester.pumpAndSettle();
      expect(controller.agenda.entries.single.done, isTrue);
      expect(find.text('已完成'), findsOneWidget);
      expect(find.text('已逾期'), findsNothing);
      expect(find.byType(CompletionText), findsOneWidget);
      expect(
        tester.widget<CompletionText>(find.byType(CompletionText)).completed,
        isTrue,
      );
      await tester.tap(find.text('标为未完成'));
      await tester.pumpAndSettle();
      expect(controller.agenda.entries.single.done, isFalse);
      expect(find.text('已逾期'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final kind in [AgendaKind.event, AgendaKind.exam]) {
    testWidgets('A past $kind completes and reopens in the same detail sheet', (
      tester,
    ) async {
      final entry = AgendaEntry(
        id: 'past-${kind.name}',
        title: '过期待办',
        kind: kind,
        startsAt: DateTime.utc(2020, 10, 27, 9),
        endsAt: DateTime.utc(2020, 10, 27, 11),
        done: false,
        // This exam already used its automatic completion opportunity; opening
        // or editing its sheet must not consume the user's explicit undo.
        examAutoCompletionHandled: kind == AgendaKind.exam,
        completionSchemaVersion: AgendaEntry.currentCompletionSchemaVersion,
      );
      final controller = await open(tester, entry);
      final sheet = tester.element(find.byType(SheetLayout));
      expect(find.text('已逾期'), findsOneWidget);
      expect(find.widgetWithText(TextButton, '编辑'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '标记完成'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '标记完成'));
      await tester.pumpAndSettle();
      expect(tester.element(find.byType(SheetLayout)), same(sheet));
      expect(controller.agenda.entries.single.done, isTrue);
      expect(find.text('已完成'), findsOneWidget);
      expect(find.text('已逾期'), findsNothing);
      expect(
        tester.widget<CompletionText>(find.byType(CompletionText)).completed,
        isTrue,
      );
      await tester.tap(find.widgetWithText(FilledButton, '标为未完成'));
      await tester.pumpAndSettle();
      expect(tester.element(find.byType(SheetLayout)), same(sheet));
      final reopened = controller.agenda.entries.single;
      expect(reopened.done, isFalse);
      expect(reopened.overdue(DateTime.utc(2030)), isTrue);
      if (kind == AgendaKind.exam) {
        expect(reopened.examAutoCompletionHandled, isTrue);
      }
      expect(find.text('已逾期'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Delete still asks for confirmation and closes after deletion', (
    tester,
  ) async {
    final controller = await open(tester, deadline());
    await tester.tap(find.byTooltip('删除'));
    await tester.pumpAndSettle();
    expect(find.text('删除DDL？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(controller.agenda.entries, hasLength(1));
    expect(find.byType(SheetLayout), findsOneWidget);
    await tester.tap(find.byTooltip('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();
    expect(controller.agenda.entries, isEmpty);
    expect(find.byType(SheetLayout), findsNothing);
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('The original assignment opens from its source row', (
    tester,
  ) async {
    final launched = <String>[];
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'launch') {
            launched.add((call.arguments as Map)['url'] as String);
            return true;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    await open(tester, deadline(detailed: true));
    await tester.ensureVisible(find.text('打开作业'));
    await tester.tap(find.text('打开作业'));
    await tester.pumpAndSettle();
    expect(launched, [url.toString()]);
    expect(find.byType(SheetLayout), findsOneWidget);
  });

  testWidgets('Edit preserves the entry and legacy width without a per-item slider', (
    tester,
  ) async {
    final controller = await open(tester, deadline(tailDays: 14));
    await tester.tap(find.widgetWithText(TextButton, '编辑'));
    await tester.pumpAndSettle();
    expect(find.text('编辑DDL'), findsOneWidget);
    final name = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == '名称',
    );
    expect(tester.widget<TextField>(name).controller!.text, '1');
    expect(find.byKey(const ValueKey('agenda-start-date')), findsOneWidget);
    expect(find.byKey(const ValueKey('agenda-start-time')), findsOneWidget);
    expect(find.text('备注（选填）'), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.byType(Slider), findsNothing);
    expect(find.text('拖尾长度（天）'), findsNothing);
    expect(controller.agenda.entries.single.tailDays, 14);
    await tester.tap(find.byKey(const ValueKey('agenda-more-options')));
    await tester.pumpAndSettle();
    expect(find.text('备注（选填）'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    await tester.enterText(name, '第二章习题');
    final colorField = find.byKey(const ValueKey('agenda-color-field'));
    await tester.ensureVisible(colorField);
    await tester.tap(colorField);
    await tester.pumpAndSettle();
    expect(find.byType(ColorIndicator), findsWidgets);
    expect(presetColor(AgendaColor.blue), findsOneWidget);
    final coral = presetColor(AgendaColor.coral);
    await tester.tap(coral);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '应用'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(controller.agenda.entries.single.id, 'assignment');
    expect(controller.agenda.entries.single.title, '第二章习题');
    expect(controller.agenda.entries.single.color, AgendaColor.coral);
    expect(controller.agenda.entries.single.tailDays, 14);
    expect(find.byType(SheetLayout), findsNothing);
    unawaited(
      showAgendaEntry(
        tester.element(find.text('打开详情')),
        controller.agenda,
        controller.agenda.entries.single,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '编辑'));
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsNothing);
    expect(controller.agenda.entries.single.tailDays, 14);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('agenda-color-value')))
          .data,
      '珊瑚色',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Editing an adjusted coloured DDL saves the real timestamp', (
    tester,
  ) async {
    final real = DateTime.utc(2030, 11, 11, 7);
    final entry = AgendaEntry(
      id: 'adjusted-colour',
      title: '跨日作业',
      kind: AgendaKind.deadline,
      startsAt: real,
      tailDays: 14,
      color: AgendaColor.blue,
      done: true,
    );
    final controller = await open(tester, entry);
    await controller.settings.setDeadlineCutoff(
      const DeadlineCutoffWindow(enabled: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('22:00  伪截止', findRichText: true), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '编辑'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('agenda-start-date')),
        matching: find.text('2030-11-11'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('agenda-start-time')),
        matching: find.text('07:00'),
      ),
      findsOneWidget,
    );
    expect(find.byType(Slider), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    final saved = controller.agenda.entries.single;
    expect(saved.startsAt, real);
    expect(saved.realDueAt, real);
    expect(saved.dueAt, DateTime.utc(2030, 11, 10, 22));
    expect(saved.tailDays, 14);
    expect(saved.color, AgendaColor.blue);
    expect(saved.done, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('An imported exam keeps its type and schedule when edited', (
    tester,
  ) async {
    final entry = AgendaEntry(
      id: 'exam-2026-2027-1-math',
      title: '高等数学',
      kind: AgendaKind.exam,
      startsAt: DateTime.utc(2026, 12, 28, 9),
      endsAt: DateTime.utc(2026, 12, 28, 11),
      location: '文萃楼F704',
      notes: '座位号：12',
      done: true,
      examAutoCompletionHandled: true,
      term: '2026-2027-1',
      local: false,
    );
    final controller = await open(tester, entry);
    await tester.tap(find.widgetWithText(TextButton, '编辑'));
    await tester.pumpAndSettle();
    expect(find.text('编辑考试'), findsOneWidget);
    expect(find.text('拖尾长度（天）'), findsNothing);
    expect(find.text('日程颜色'), findsNothing);
    expect(find.byType(SegmentedButton<AgendaKind>), findsNothing);
    final name = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == '名称',
    );
    await tester.enterText(name, '高等数学期末考试');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    final saved = controller.agenda.entries.single;
    expect(saved.id, entry.id);
    expect(saved.title, '高等数学期末考试');
    expect(saved.kind, AgendaKind.exam);
    expect(saved.startsAt, entry.startsAt);
    expect(saved.endsAt, entry.endsAt);
    expect(saved.location, entry.location);
    expect(saved.notes, entry.notes);
    expect(saved.term, entry.term);
    expect(saved.done, isTrue);
    expect(saved.examAutoCompletionHandled, isTrue);
    expect(saved.completionSchemaVersion, entry.completionSchemaVersion);
    expect(saved.local, isTrue);
    expect(find.byType(SheetLayout), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Editing structured exam metadata turns the localized view into saved text',
    (tester) async {
      final entry = AgendaEntry(
        id: 'exam-2026-2027-1-math',
        title: '高等数学',
        kind: AgendaKind.exam,
        startsAt: DateTime.utc(2026, 12, 28, 9),
        endsAt: DateTime.utc(2026, 12, 28, 11),
        location: '文萃楼F704',
        term: '2026-2027-1',
        local: false,
        done: false,
        examAutoCompletionHandled: true,
        details: const ExamAgendaDetails(
          seat: '12',
          mode: '闭卷',
          teacher: '张老师',
        ),
      );
      final controller = await open(tester, entry);
      await tester.tap(find.widgetWithText(TextButton, '编辑'));
      await tester.pumpAndSettle();
      final notes = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == '备注（选填）',
      );
      expect(
        tester.widget<TextField>(notes).controller!.text,
        '座位号：12\n闭卷\n教师：张老师',
      );
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();
      final saved = controller.agenda.entries.single;
      expect(saved.details, isNull);
      expect(saved.notes, '座位号：12\n闭卷\n教师：张老师');
      expect(saved.done, isFalse);
      expect(saved.examAutoCompletionHandled, isTrue);
      expect(saved.completionSchemaVersion, entry.completionSchemaVersion);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'All-day deadlines and multi-day activities show meaningful time ranges',
    (tester) async {
      await open(tester, deadline(allDay: true));
      expect(find.text('当天结束前', findRichText: true), findsOneWidget);
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      final start = DateTime.utc(2020, 10, 27);
      final end = DateTime.utc(2020, 10, 30);
      await open(
        tester,
        AgendaEntry(
          id: 'event',
          title: '校外实践',
          kind: AgendaKind.event,
          startsAt: start,
          endsAt: end,
          allDay: true,
          done: false,
          completionSchemaVersion: AgendaEntry.currentCompletionSchemaVersion,
        ),
      );
      expect(
        find.text(
          '${localizedAgendaDate(AppLocalizationsZh(), start)} – '
          '${localizedAgendaDate(AppLocalizationsZh(), end.subtract(const Duration(days: 1)))}',
        ),
        findsOneWidget,
      );
      expect(find.text('全天', findRichText: true), findsOneWidget);
      expect(find.text('已结束'), findsNothing);
      expect(find.text('已逾期'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '标记完成'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('DDL color choices fit a narrow screen with large text', (
    tester,
  ) async {
    await open(
      tester,
      deadline(detailed: true),
      size: const Size(320, 640),
      scale: 1.8,
      brightness: Brightness.dark,
    );
    await tester.tap(find.widgetWithText(TextButton, '编辑'));
    await tester.pumpAndSettle();

    final label = find.text('日程颜色');
    await tester.ensureVisible(label);
    await tester.tap(find.byKey(const ValueKey('agenda-color-field')));
    await tester.pumpAndSettle();
    final rose = presetColor(AgendaColor.rose);
    await tester.ensureVisible(rose);
    await tester.tap(rose);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '应用'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('agenda-color-value')))
          .data,
      '玫红',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('A regular agenda entry can save a custom colour', (
    tester,
  ) async {
    final entry = AgendaEntry(
      id: 'event-color',
      title: '社团活动',
      kind: AgendaKind.event,
      startsAt: DateTime.utc(2020, 10, 27, 18),
      endsAt: DateTime.utc(2020, 10, 27, 20),
    );
    final controller = await open(tester, entry);
    await tester.tap(find.widgetWithText(TextButton, '编辑'));
    await tester.pumpAndSettle();

    final colorField = find.byKey(const ValueKey('agenda-color-field'));
    await tester.ensureVisible(colorField);
    await tester.tap(colorField);
    await tester.pumpAndSettle();
    final teal = presetColor(AgendaColor.teal);
    await tester.ensureVisible(teal);
    await tester.tap(teal);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '应用'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(controller.agenda.entries.single.color, AgendaColor.teal);
    expect(tester.takeException(), isNull);
  });

  testWidgets('The color picker supports arbitrary custom colors', (
    tester,
  ) async {
    final entry = AgendaEntry(
      id: 'event-custom-color',
      title: '社团活动',
      kind: AgendaKind.event,
      startsAt: DateTime.utc(2020, 10, 27, 18),
      endsAt: DateTime.utc(2020, 10, 27, 20),
    );
    final controller = await open(tester, entry);
    await tester.tap(find.widgetWithText(TextButton, '编辑'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('agenda-color-field')));
    await tester.pumpAndSettle();

    expect(find.text('选择颜色'), findsOneWidget);
    await tester.tap(find.text('自定义颜色'));
    await tester.pumpAndSettle();
    expect(find.byType(ColorWheelPicker), findsOneWidget);
    final codeField = find.descendant(
      of: find.byType(ColorCodeField),
      matching: find.byType(TextField),
    );
    expect(codeField, findsOneWidget);
    await tester.enterText(codeField, '3366CC');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '应用'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    final color = controller.agenda.entries.single.color;
    expect(color, isNotNull);
    expect(color!.id, isNull);
    expect(color.value, 0xFF3366CC);
    expect(tester.takeException(), isNull);
  });
}
