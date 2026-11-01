import 'package:bitree/app/controller.dart';
import 'package:bitree/app/ui/app_screen.dart';
import 'package:bitree/l10n/app_localizations.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

Widget _app(AppController controller) => ListenableBuilder(
  listenable: controller,
  builder: (context, _) => MaterialApp(
    theme: bitreeTheme(Brightness.light),
    locale: controller.language.locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: AppScreen(controller: controller),
  ),
);

List<String> _navigationLabels(WidgetTester tester) => tester
    .widget<NavigationBar>(find.byType(NavigationBar))
    .destinations
    .cast<NavigationDestination>()
    .map((destination) => destination.label)
    .toList();

void main() {
  testWidgets('Language selection updates the UI and persists', (tester) async {
    final preferences = MemoryPreferences();
    final controller = TestAppController(preferences: preferences);
    await controller.setLanguage(AppLanguage.chinese);
    await tester.pumpWidget(_app(controller));

    expect(_navigationLabels(tester), ['首页', '日程', '工具', '设置']);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('设置'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('语言'), findsOneWidget);

    await tester.tap(find.text('English'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(_navigationLabels(tester), ['Home', 'Agenda', 'Tools', 'Settings']);
    expect(find.text('Language'), findsOneWidget);
    expect(preferences.value('language'), AppLanguage.english.name);
  });

  test('Saved language preference is restored on startup', () async {
    final controller = TestAppController(
      preferences: MemoryPreferences({'language': AppLanguage.english.name}),
    );

    await controller.initialize();

    expect(controller.language, AppLanguage.english);
  });
}
