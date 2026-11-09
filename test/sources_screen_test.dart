import 'package:bitree/l10n/l10n.dart';
import 'package:bitree/sources/ui/sources_screen.dart';
import 'package:bitree/sync/controller.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  testWidgets('source details lead with sync and disabling skips sync all', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = TestAppController();
    await controller.initialize();
    expect(controller.sources.instances, isNotEmpty);
    await tester.pumpWidget(
      MaterialApp(
        theme: bitreeTheme(Brightness.light),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SourcesScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('乐学'), findsOneWidget);
    expect(find.text('教学中心'), findsNothing);
    expect(find.text('物理实验报告'), findsNothing);
    expect(find.text('从文件夹安装扩展'), findsOneWidget);
    expect(find.text('从链接安装扩展'), findsOneWidget);

    await tester.tap(find.text('从链接安装扩展'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('扩展包链接'), findsOneWidget);
    expect(find.text('SHA-256'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('乐学'));
    await tester.pumpAndSettle();

    expect(find.text('立即同步'), findsOneWidget);
    expect(find.byTooltip('刷新课程列表'), findsOneWidget);
    expect(find.text('同步后会列出平台上的课程。'), findsOneWidget);
    expect(find.text('内置实现'), findsOneWidget);
    expect(find.textContaining('courses.list'), findsNothing);

    expect(controller.sync.bulkTargets, contains(SyncTarget.lexue));
    await tester.tap(find.text('启用'));
    await tester.pumpAndSettle();
    expect(find.text('同步时会跳过它，已同步的内容保留。'), findsOneWidget);
    expect(controller.sync.bulkTargets, isNot(contains(SyncTarget.lexue)));

    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('已停用'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
