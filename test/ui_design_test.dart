import 'package:bitree/agenda/controller.dart';
import 'package:bitree/agenda/model.dart';
import 'package:bitree/agenda/ui/calendar_screen.dart';
import 'package:bitree/agenda/view_mode.dart';
import 'package:bitree/core/time.dart';
import 'package:bitree/ui/app_menu_trigger.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

class _Store extends MemoryAgendaStore {
  @override
  Future<List<AgendaEntry>> readAndMigrate() async => [
    AgendaEntry(
      id: 'ddl',
      title: '第五章作业',
      kind: AgendaKind.deadline,
      startsAt: DateTime.utc(2099, 1, 1, 23, 59),
    ),
    AgendaEntry(
      id: 'event',
      title: '小组讨论',
      kind: AgendaKind.event,
      startsAt: DateTime.utc(2099, 1, 2, 17),
      endsAt: DateTime.utc(2099, 1, 2, 18),
    ),
  ];
}

RoundedRectangleBorder _shape(WidgetTester tester, Finder control) => tester
    .widgetList<Material>(
      find.descendant(of: control, matching: find.byType(Material)),
    )
    .map((material) => material.shape)
    .whereType<RoundedRectangleBorder>()
    .first;

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'Native controls share the same rendered corners in $brightness',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: bitreeTheme(brightness),
            home: Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextButton(onPressed: () {}, child: const Text('文字操作')),
                  FilledButton(onPressed: () {}, child: const Text('主要操作')),
                  OutlinedButton(onPressed: () {}, child: const Text('次要操作')),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
                  ActionChip(label: const Text('课程快捷入口'), onPressed: () {}),
                  const SearchBar(hintText: '搜索'),
                ],
              ),
            ),
          ),
        );
        final controls = [
          find.byType(TextButton),
          find.byType(FilledButton),
          find.byType(OutlinedButton),
          find.byType(IconButton),
          find.byType(ActionChip),
          find.byType(SearchBar),
        ];
        final expected = _shape(tester, controls.first).borderRadius;
        expect(expected, const BorderRadius.all(Radius.circular(10)));
        for (final control in controls.skip(1)) {
          expect(
            _shape(tester, control).borderRadius,
            expected,
            reason: '$control',
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final (size, scale) in [
    (const Size(320, 640), 1.0),
    (const Size(390, 844), 1.8),
    (const Size(1200, 800), 1.0),
  ]) {
    testWidgets(
      'Agenda menu stays compact and filtering works at $size, $scale',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final agenda = AgendaController(_Store());
        await agenda.load();
        final controller = TestAppController(agenda: agenda);
        await controller.settings.setAgendaViewMode(AgendaViewMode.list);

        await tester.pumpWidget(
          MaterialApp(
            theme: bitreeTheme(Brightness.light),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: CalendarScreen(controller: controller, now: campusNow()),
            ),
          ),
        );
        final trigger = find.byType(AppMenuTrigger);
        expect(tester.getSize(trigger).width, lessThan(150));
        expect(
          _shape(tester, trigger).borderRadius,
          const BorderRadius.all(Radius.circular(10)),
        );
        await tester.tap(trigger);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<AppMenuArrow>(
                find.descendant(
                  of: trigger,
                  matching: find.byType(AppMenuArrow),
                ),
              )
              .isOpen,
          isTrue,
        );
        await tester.tap(find.text('DDL').last);
        await tester.pumpAndSettle();
        expect(find.text('小组讨论'), findsNothing);
        expect(find.text('第五章作业'), findsWidgets);
        expect(
          tester
              .widget<AppMenuArrow>(
                find.descendant(
                  of: trigger,
                  matching: find.byType(AppMenuArrow),
                ),
              )
              .isOpen,
          isFalse,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
