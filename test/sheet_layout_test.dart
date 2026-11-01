import 'package:bitree/ui/sheet_layout.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> host(
    WidgetTester tester,
    Widget actions, {
    Size size = const Size(320, 640),
    double textScale = 1.8,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: bitreeTheme(Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(padding: const EdgeInsets.all(16), child: actions),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  }

  testWidgets('A primary sheet action fills the available width', (
    tester,
  ) async {
    await host(
      tester,
      SheetActionBar.primary(
        primary: FilledButton(
          onPressed: () {},
          child: const Text('恢复已选择的两条 DDL'),
        ),
      ),
    );

    final button = find.byType(FilledButton);
    expect(button.hitTestable(), findsOneWidget);
    expect(tester.getSize(button).width, 288);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A split action bar keeps both actions reachable at large text', (
    tester,
  ) async {
    await host(
      tester,
      SheetActionBar.split(
        leading: TextButton(onPressed: () {}, child: const Text('全部课次')),
        primary: FilledButton(onPressed: () {}, child: const Text('应用当前选择')),
      ),
    );

    expect(find.text('全部课次').hitTestable(), findsOneWidget);
    expect(find.text('应用当前选择').hitTestable(), findsOneWidget);
    expect(tester.getSize(find.byType(FilledButton)).width, greaterThan(120));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Multiple sheet actions wrap without hiding actions', (
    tester,
  ) async {
    await host(
      tester,
      SheetActionBar.actions(
        children: [
          TextButton(onPressed: () {}, child: const Text('稍后')),
          TextButton(onPressed: () {}, child: const Text('查看发布页')),
          FilledButton(onPressed: () {}, child: const Text('下载开发版本')),
        ],
      ),
    );

    for (final label in ['稍后', '查看发布页', '下载开发版本']) {
      expect(find.text(label).hitTestable(), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}
