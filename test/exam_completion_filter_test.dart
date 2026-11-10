import 'package:bitree/academics/ui/exams_screen.dart';
import 'package:bitree/agenda/model.dart';
import 'package:bitree/l10n/app_localizations_zh.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

AgendaEntry _exam(
  String id,
  DateTime start, {
  bool done = false,
  bool handled = false,
}) => AgendaEntry(
  id: id,
  title: id,
  kind: AgendaKind.exam,
  startsAt: start,
  endsAt: start.add(const Duration(hours: 2)),
  done: done,
  examAutoCompletionHandled: handled,
);

Future<void> _show(WidgetTester tester, List<AgendaEntry> entries) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final app = TestAppController(entries: entries);
  await app.initialize();
  await tester.pumpWidget(MaterialApp(
    theme: bitreeTheme(Brightness.light),
    home: ExamsScreen(controller: app),
  ));
  await tester.pumpAndSettle();
}

void main() {
  final l10n = AppLocalizationsZh();

  testWidgets('Manual completion cannot hide a future exam or its conflicts', (
    tester,
  ) async {
    await _show(tester, [
      _exam('未来已完成考试', DateTime.utc(2099, 1, 2, 9),
        done: true, handled: true),
      _exam('未来待考考试', DateTime.utc(2099, 1, 2, 10)),
    ]);
    expect(find.text('未来已完成考试'), findsOneWidget);
    expect(find.text('未来待考考试'), findsOneWidget);
    expect(find.text(l10n.showFinishedExams), findsNothing);
    final conflicts = find.text(l10n.timeConflictsFound(1));
    await tester.scrollUntilVisible(
      conflicts, 160, scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(conflicts);
    await tester.pumpAndSettle();
    expect(find.text(l10n.noTimeConflict), findsNothing);
    expect(find.textContaining('未来已完成考试'), findsWidgets);
    expect(find.textContaining('未来待考考试'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('A reopened past exam remains accessible through the past filter', (
    tester,
  ) async {
    await _show(tester, [
      _exam('已撤销完成的过去考试', DateTime.utc(2020, 1, 2, 9), handled: true),
    ]);
    expect(find.text('已撤销完成的过去考试'), findsNothing);
    final showPast = find.text(l10n.showFinishedExams);
    await tester.scrollUntilVisible(
      showPast, 160, scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(showPast);
    await tester.pumpAndSettle();
    expect(find.text('已撤销完成的过去考试'), findsOneWidget);
    expect(find.text(l10n.hideFinishedExams), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
