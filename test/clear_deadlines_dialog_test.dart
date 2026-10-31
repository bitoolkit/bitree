import 'package:bitree/agenda/deadline_clear_scope.dart';
import 'package:bitree/agenda/deadline_source.dart';
import 'package:bitree/agenda/model.dart';
import 'package:bitree/agenda/ui/clear_deadlines_dialog.dart';
import 'package:bitree/ui/selection_controls.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  testWidgets(
    'Clear deadlines shares all, clear, and partial selection behavior',
    (tester) async {
      final app = TestAppController(
        entries: [
          AgendaEntry(
            id: 'manual',
            title: '手动 DDL',
            kind: AgendaKind.deadline,
            startsAt: DateTime.utc(2026, 12, 30, 23, 59),
          ),
          AgendaEntry(
            id: 'eclass',
            title: '课堂 DDL',
            kind: AgendaKind.deadline,
            startsAt: DateTime.utc(2026, 12, 31, 23, 59),
            source: DeadlineSource.eclass,
          ),
        ],
      );
      await app.initialize();
      await tester.pumpWidget(
        MaterialApp(
          theme: bitreeTheme(Brightness.light),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showClearDeadlines(context, app.agenda),
                child: const Text('打开删除对话框'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('打开删除对话框'));
      await tester.pumpAndSettle();
      expect(find.byType(AppSelectionBar), findsOneWidget);
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox).first).value,
        isFalse,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, '删除 0 条 DDL'),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      expect(
        tester
            .widgetList<Checkbox>(find.byType(Checkbox))
            .skip(1)
            .every((checkbox) => checkbox.value == true),
        isTrue,
      );
      expect(find.text('已选择 5 类，共 2 条 DDL。'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, '删除 2 条 DDL'),
            )
            .onPressed,
        isNotNull,
      );

      await tester.tap(find.text('清空'));
      await tester.pump();
      expect(
        tester
            .widgetList<Checkbox>(find.byType(Checkbox))
            .skip(1)
            .every((checkbox) => checkbox.value == false),
        isTrue,
      );

      await tester.tap(find.text('新延河课堂 DDL（1 条）'));
      await tester.pump();
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox).first).value,
        isNull,
      );
      expect(app.agenda.deadlineIdsIn({DeadlineClearScope.eclass}), {'eclass'});
      expect(tester.takeException(), isNull);
    },
  );
}
