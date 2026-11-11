import 'package:bitree/schedule/timetable_axis.dart';
import 'package:bitree/schedule/ui/timetable_time_gutter.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _show(
  WidgetTester tester, {
  required bool expanded,
  required double rowHeight,
  Brightness brightness = Brightness.light,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: bitreeTheme(brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Builder(
            builder: (context) => SizedBox(
              width: TimetableTimeGutter.preferredWidth(context),
              child: TimetableTimeGutter(
                axis: TimetableAxis(expanded: expanded),
                rowHeight: rowHeight,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Text _text(WidgetTester tester, String kind, int section) {
  final finder = find.byKey(ValueKey((kind, section)));
  final widget = tester.widget(finder);
  return widget is Text
      ? widget
      : tester.widget<Text>(
          find.descendant(of: finder, matching: find.byType(Text)),
        );
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'Both modes share course and hourly typography in $brightness',
      (tester) async {
        await _show(
          tester,
          expanded: false,
          rowHeight: 64,
          brightness: brightness,
        );
        final number = _text(tester, 'timetable-period-number', 1).style;
        final start = _text(tester, 'timetable-period-start', 1).style;
        final end = _text(tester, 'timetable-period-end', 1).style;
        expect(start, end);
        final scheme = bitreeTheme(brightness).colorScheme;
        expect(number!.color, scheme.onSurface);
        expect(start!.color, scheme.onSurfaceVariant);
        await _show(
          tester,
          expanded: true,
          rowHeight: 64,
          brightness: brightness,
        );
        expect(find.byType(TimetableTimeGutter), findsOneWidget);
        expect(_text(tester, 'timetable-period-number', 1).style, number);
        expect(_text(tester, 'timetable-period-start', 1).style, start);
        expect(_text(tester, 'timetable-period-end', 1).style, end);
        expect(_text(tester, 'timetable-hour', 0).style, start);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final scale in [1.0, 1.8]) {
    testWidgets(
      'Rendered font sizes stay fixed across full and compact rows at scale $scale',
      (tester) async {
        await _show(tester, expanded: false, rowHeight: 64, scale: scale);
        final number = tester
            .getRect(find.byKey(const ValueKey(('timetable-period-number', 1))))
            .height;
        final clock = tester
            .getRect(find.byKey(const ValueKey(('timetable-period-start', 1))))
            .height;
        for (final rowHeight in [64.0, 32.0, 24.0]) {
          await _show(
            tester,
            expanded: true,
            rowHeight: rowHeight,
            scale: scale,
          );
          expect(
            find.descendant(
              of: find.byType(TimetableTimeGutter),
              matching: find.byType(FittedBox),
            ),
            findsNothing,
          );
          final numberFinder = find.byKey(
            const ValueKey(('timetable-period-number', 1)),
          );
          final clockFinder = find.byKey(
            const ValueKey(('timetable-period-start', 1)),
          );
          if (numberFinder.evaluate().isNotEmpty) {
            final numberRect = tester.getRect(numberFinder);
            expect(numberRect.height, closeTo(number, 0.001));
            expect(
              numberRect.bottom,
              lessThanOrEqualTo(tester.getRect(clockFinder).top),
            );
          }
          if (rowHeight == 24) expect(numberFinder, findsNothing);
          expect(
            tester
                .getRect(
                  find.byKey(const ValueKey(('timetable-period-start', 1))),
                )
                .height,
            closeTo(clock, 0.001),
          );
          expect(
            tester
                .getRect(find.byKey(const ValueKey(('timetable-hour', 0))))
                .height,
            closeTo(clock, 0.001),
          );
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  testWidgets(
    'Rows keep vertical labels and omit end time then period number as space runs short',
    (tester) async {
      await _show(tester, expanded: false, rowHeight: 64);
      final numberStyle = _text(tester, 'timetable-period-number', 1).style;
      final startStyle = _text(tester, 'timetable-period-start', 1).style;
      for (final expanded in [false, true]) {
        for (final (height, showNumber, showEnd) in [
          (64.0, true, true),
          (32.0, true, false),
          (24.0, false, false),
        ]) {
          await _show(tester, expanded: expanded, rowHeight: height);
          expect(
            find.byKey(const ValueKey(('timetable-period-number', 1))),
            showNumber ? findsOneWidget : findsNothing,
          );
          expect(
            find.byKey(const ValueKey(('timetable-period-end', 1))),
            showEnd ? findsOneWidget : findsNothing,
          );
          if (showNumber) {
            expect(
              _text(tester, 'timetable-period-number', 1).style,
              numberStyle,
            );
          }
          expect(_text(tester, 'timetable-period-start', 1).style, startStyle);
          expect(
            find.descendant(
              of: find.byType(TimetableTimeGutter),
              matching: find.byType(Row),
            ),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets('Hourly ticks stay outside the teaching day with large text', (
    tester,
  ) async {
    const axis = TimetableAxis(expanded: true);
    const rowHeight = 18.0;
    await _show(tester, expanded: true, rowHeight: rowHeight, scale: 2.5);
    final gutter = tester.getRect(find.byType(TimetableTimeGutter));
    final hour = find.byKey(const ValueKey(('timetable-hour', 420)));
    expect(
      tester.getCenter(hour).dy - gutter.top,
      closeTo(axis.offsetForMinute(420) * rowHeight, 0.001),
    );
    for (var hour = 8; hour < 21; hour++) {
      expect(find.byKey(ValueKey(('timetable-hour', hour * 60))), findsNothing);
    }
    expect(
      find.byKey(const ValueKey(('timetable-hour', 1260))),
      findsOneWidget,
    );
    final course = find.byKey(const ValueKey(('timetable-period-label', 2)));
    expect(
      tester.getRect(course).top - gutter.top,
      closeTo(axis.sectionStart(2) * rowHeight, 0.001),
    );
    expect(
      tester.getRect(course).height,
      closeTo((axis.sectionEnd(2) - axis.sectionStart(2)) * rowHeight, 0.001),
    );
    expect(
      find.byKey(const ValueKey(('timetable-period-start', 2))),
      findsOneWidget,
    );
    expect(tester.getRect(course).height, greaterThan(0));
    expect(tester.takeException(), isNull);
  });
}
