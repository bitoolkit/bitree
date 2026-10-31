import 'package:bitree/l10n/l10n.dart';
import 'package:bitree/ui/selection_controls.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'The shared selection bar exposes one all/clear interaction at large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var selected = 1;
      var selectAllCalls = 0;
      var clearCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: bitreeTheme(Brightness.light),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Padding(
                padding: const EdgeInsets.all(16),
                child: AppSelectionBar(
                  selectedCount: selected,
                  totalCount: 3,
                  summary: context.l10n.selectedItems(selected),
                  onSelectAll: () {
                    selectAllCalls++;
                    setState(() => selected = 3);
                  },
                  onClear: () {
                    clearCalls++;
                    setState(() => selected = 0);
                  },
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isNull);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(selectAllCalls, 1);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
      expect(find.text('已选 3 项'), findsOneWidget);

      await tester.tap(find.text('清空'));
      await tester.pump();
      expect(clearCalls, 1);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
      expect(find.text('已选 0 项'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('The shared selection row stays compact and toggles once', (
    tester,
  ) async {
    var value = false;
    var changes = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: bitreeTheme(Brightness.light),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => AppSelectionTile(
              title: const Text('包含本地课表'),
              subtitle: const Text('检查与本地课程的冲突'),
              value: value,
              onChanged: (next) {
                changes++;
                setState(() => value = next!);
              },
            ),
          ),
        ),
      ),
    );

    final tile = find.byType(AppSelectionTile);
    expect(tester.getSize(tile).height, lessThanOrEqualTo(64));
    await tester.tap(find.text('包含本地课表'));
    await tester.pump();
    expect(changes, 1);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    expect(tester.takeException(), isNull);
  });
}
