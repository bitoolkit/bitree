import 'package:bitree/app/ui/app_screen.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  testWidgets('The four navigation destinations open their matching pages', (
    tester,
  ) async {
    final controller = TestAppController();
    await tester.pumpWidget(
      MaterialApp(
        theme: bitreeTheme(Brightness.light),
        home: AppScreen(controller: controller),
      ),
    );
    final bar = find.byType(NavigationBar);
    const labels = ['首页', '日程', '工具', '设置'];
    expect(
      tester
          .widget<NavigationBar>(bar)
          .destinations
          .cast<NavigationDestination>()
          .map((destination) => destination.label),
      labels,
    );
    const content = ['同步全部', '今天', '成绩与学业', '外观'];
    for (var index = 0; index < labels.length; index++) {
      await tester.tap(
        find.descendant(of: bar, matching: find.text(labels[index])),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.widget<NavigationBar>(bar).selectedIndex, index);
      expect(find.text(content[index]).hitTestable(), findsOneWidget);
      expect(find.text('学习服务'), findsNothing);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
