import 'package:bitree/agenda/model.dart';
import 'package:bitree/app/ui/settings_screen.dart';
import 'package:bitree/sync/controller.dart';
import 'package:bitree/sync/ui/sync_button.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  testWidgets('The shared menu only offers remote sync actions', (
    tester,
  ) async {
    final app = TestAppController();
    await app.initialize();
    await tester.pumpWidget(
      MaterialApp(
        theme: bitreeTheme(Brightness.light),
        home: Scaffold(body: SyncButton(controller: app)),
      ),
    );
    await tester.tap(find.byTooltip('同步'));
    await tester.pumpAndSettle();
    final labels = find.descendant(
      of: find.byType(MenuItemButton),
      matching: find.byType(Text),
    );
    expect(tester.widgetList<Text>(labels).map((text) => text.data), [
      '同步全部',
      '自定义同步',
    ]);
    expect(find.byType(Divider), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Custom sync excludes academic records', (tester) async {
    final app = TestAppController();
    await app.initialize();
    expect(app.sync.bulkTargets, isNot(contains(SyncTarget.grades)));
    expect(app.sync.bulkTargets, isNot(contains(SyncTarget.studyPlan)));
    await tester.pumpWidget(
      MaterialApp(
        theme: bitreeTheme(Brightness.light),
        home: Scaffold(body: SyncButton(controller: app)),
      ),
    );
    await tester.tap(find.byTooltip('同步'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('自定义同步'));
    await tester.pumpAndSettle();

    expect(find.text('成绩'), findsNothing);
    expect(find.text('学分进度'), findsNothing);
    expect(find.text('课表'), findsOneWidget);
    expect(find.text('大物实验 DDL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Deleted deadlines are managed from local agenda settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = TestAppController(
      entries: [
        AgendaEntry(
          id: 'deleted',
          title: '已删除作业',
          kind: AgendaKind.deadline,
          startsAt: DateTime.utc(2026, 12, 30, 23, 59),
          deleted: true,
        ),
      ],
    );
    await app.initialize();
    await tester.pumpWidget(
      MaterialApp(
        theme: bitreeTheme(Brightness.light),
        home: Scaffold(
          body: SettingsScreen(
            controller: app,
            checkingForUpdates: false,
            onCheckForUpdates: () {},
          ),
        ),
      ),
    );

    await tester.scrollUntilVisible(find.text('本地日程'), 300);
    expect(find.text('已删除的 DDL'), findsOneWidget);
    await tester.tap(find.text('已删除的 DDL'));
    await tester.pumpAndSettle();

    expect(find.text('全部恢复'), findsOneWidget);
    expect(find.text('恢复'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
