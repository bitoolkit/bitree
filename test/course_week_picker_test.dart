import 'package:bitree/schedule/ui/course_week_picker.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Course weeks share all, clear, and summer/regular presets on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var selected = <int>{1};
      await tester.pumpWidget(
        MaterialApp(
          theme: bitreeTheme(Brightness.light),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: StatefulBuilder(
                builder: (context, setState) => CourseWeekPicker(
                  weeks: const [-2, -1, 1, 2, 3],
                  selectedWeeks: selected,
                  enabled: true,
                  onChanged: (weeks) => setState(() => selected = weeks),
                  onManageRange: () {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isNull);
      expect(find.text('已选 1 项'), findsOneWidget);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(selected, {-2, -1, 1, 2, 3});
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);

      await tester.tap(find.text('清空'));
      await tester.pump();
      expect(selected, isEmpty);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);

      await tester.tap(find.text('小学期'));
      await tester.pump();
      expect(selected, {-2, -1});
      await tester.tap(find.text('非小学期'));
      await tester.pump();
      expect(selected, {1, 2, 3});
      expect(tester.takeException(), isNull);
    },
  );
}
