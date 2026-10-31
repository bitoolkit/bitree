import 'dart:math' as math;

import 'package:bitree/classrooms/ui/classroom_time_field.dart';
import 'package:bitree/schedule/ui/week_range_sheet.dart';
import 'package:bitree/school/ui/school_verification_sheet.dart';
import 'package:bitree/school/verification.dart';
import 'package:bitree/ui/dialog_layout.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _surface = find.byWidgetPredicate(
  (widget) => widget is Material && widget.type == MaterialType.card,
);

Future<void> _host(
  WidgetTester tester,
  Size size,
  Widget Function(BuildContext context) child, {
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetViewInsets);
  await tester.pumpWidget(
    MaterialApp(
      theme: bitreeTheme(Brightness.light),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(body: Builder(builder: child)),
    ),
  );
}

void _expectWidth(WidgetTester tester, Size size) {
  expect(tester.getSize(_surface).width, math.min(360, size.width - 48));
  expect(tester.takeException(), isNull);
}

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(1440, 900),
  ]) {
    for (final picker in ['date', 'time']) {
      testWidgets('$picker picker uses shared width at $size', (tester) async {
        Object? picked;
        await _host(
          tester,
          size,
          (context) => TextButton(
            onPressed: () async {
              if (picker == 'date') {
                picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime(2026, 10, 27),
                  firstDate: DateTime(2026),
                  lastDate: DateTime(2027),
                  builder: appPickerDialogBuilder,
                );
              } else {
                picked = await showTimePicker(
                  context: context,
                  initialTime: const TimeOfDay(hour: 18, minute: 30),
                  builder: appPickerDialogBuilder,
                );
              }
            },
            child: const Text('打开'),
          ),
        );
        await tester.tap(find.text('打开'));
        await tester.pumpAndSettle();
        _expectWidth(tester, size);
        if (picker == 'time') {
          for (final element in find.byType(Scrollable).evaluate()) {
            final state = (element as StatefulElement).state as ScrollableState;
            if (axisDirectionToAxis(state.widget.axisDirection) ==
                Axis.horizontal) {
              expect(state.position.maxScrollExtent, 0);
            }
          }
        } else {
          await tester.tap(find.text('28').hitTestable());
        }
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        expect(
          picked,
          picker == 'date'
              ? DateTime(2026, 10, 28)
              : const TimeOfDay(hour: 18, minute: 30),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Week management uses the shared sheet at $size', (
      tester,
    ) async {
      ({int first, int last})? saved;
      await _host(
        tester,
        size,
        (context) => TextButton(
          onPressed: () async =>
              saved = await showWeekRangeSheet(context, first: -3, last: 25),
          child: const Text('打开'),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.tap(find.byTooltip('增加一周').first);
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      expect(saved, (first: -2, last: 25));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Custom classroom times use the shared sheet at $size', (
      tester,
    ) async {
      ({int start, int end})? selected;
      await _host(
        tester,
        size,
        (context) => Padding(
          padding: const EdgeInsets.all(24),
          child: ClassroomTimeField(
            value: null,
            date: DateTime.utc(2026, 10, 27),
            now: DateTime.utc(2026, 10, 27, 10),
            onChanged: (period) => selected = period,
          ),
        ),
      );
      await tester.tap(find.byType(ClassroomTimeField));
      await tester.pumpAndSettle();
      final custom = find.text('自选课次');
      await tester.ensureVisible(custom);
      await tester.tap(custom);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.tap(find.text('第3节'));
      await tester.tap(find.text('第4节'));
      await tester.tap(find.text('应用'));
      await tester.pumpAndSettle();
      expect(selected, (start: 3, end: 4));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Short alerts and choice dialogs share the same width', (
    tester,
  ) async {
    const size = Size(390, 844);
    await _host(
      tester,
      size,
      (context) => Column(
        children: [
          TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) =>
                  const AlertDialog(title: Text('确认'), content: Text('内容')),
            ),
            child: const Text('提示'),
          ),
          TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const SimpleDialog(
                title: Text('选择课程'),
                children: [SimpleDialogOption(child: Text('课程'))],
              ),
            ),
            child: const Text('选择'),
          ),
        ],
      ),
    );
    for (final label in ['提示', '选择']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      _expectWidth(tester, size);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('School verification uses the shared sheet with large text', (
    tester,
  ) async {
    var sends = 0;
    String? checkedCode;
    String? result;
    await _host(
      tester,
      const Size(320, 640),
      (context) => TextButton(
        onPressed: () async {
          result = await verifySchoolLogin(
            context,
            SchoolSmsVerification(
              phone: '138****0000',
              sendCode: () async {
                sends++;
              },
              checkCode: (code) async {
                checkedCode = code;
              },
            ),
          );
        },
        child: const Text('开始验证'),
      ),
      textScale: 1.8,
    );
    await tester.tap(find.text('开始验证'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(sends, 1);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('短信验证'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(TextFormField), '1234');
    await tester.tap(find.text('确定'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(checkedCode, '1234');
    expect(result, '1234');
    expect(tester.takeException(), isNull);
  });
}
