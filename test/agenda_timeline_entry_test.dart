import 'package:bitree/agenda/deadline_source.dart';
import 'package:bitree/agenda/model.dart';
import 'package:bitree/agenda/ui/timeline_entry.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/system_palette.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final system in [false, true]) {
      testWidgets(
        'Overdue DDLs show an error badge without changing source colours in $brightness, system=$system',
        (tester) async {
          final theme = bitreeTheme(
            brightness,
            systemPalette: system ? testSystemPalette() : null,
          );
          final due = DateTime.utc(2026, 11, 17, 13);
          final entry = AgendaEntry(
            id: 'eclass',
            title: '第五章作业',
            kind: AgendaKind.deadline,
            startsAt: due,
            source: DeadlineSource.eclass,
          );
          Future<void> show(AgendaEntry value, DateTime now) async {
            await tester.pumpWidget(
              MaterialApp(
                theme: theme,
                home: Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: 180,
                      height: 120,
                      child: AgendaTimelineEntry(
                        entry: value,
                        now: now,
                        barWidth: 180,
                        deadlineWidth: 180,
                        onTap: () {},
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
          }

          final bar = find.byKey(
            const ValueKey(('agenda-timeline-bar', 'eclass')),
          );

          List<Color> fill() {
            final ink = tester.widget<Ink>(
              find.descendant(of: bar, matching: find.byType(Ink)),
            );
            final decoration = ink.decoration! as BoxDecoration;
            return (decoration.gradient! as LinearGradient).colors;
          }

          Border border() {
            final foreground = find.descendant(
              of: bar,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is DecoratedBox &&
                    widget.position == DecorationPosition.foreground,
              ),
            );
            final box = tester.widget<DecoratedBox>(foreground);
            return (box.decoration as BoxDecoration).border! as Border;
          }

          Color titleColor() =>
              tester.widget<Text>(find.text(entry.title)).style!.color!;
          Color captionColor() =>
              tester.widget<Text>(find.text('13:00 截止')).style!.color!;
          Color warningColor() => tester
              .widget<Icon>(find.byIcon(Icons.warning_amber_rounded))
              .color!;
          BoxDecoration overdueStatusDecoration() {
            final status = find.byKey(
              const ValueKey(('agenda-timeline-overdue-status', 'eclass')),
            );
            final box = find.descendant(
              of: status,
              matching: find.byType(DecoratedBox),
            );
            return tester.widget<DecoratedBox>(box).decoration as BoxDecoration;
          }

          await show(entry, due.subtract(const Duration(minutes: 1)));
          final originalFill = fill();
          final originalText = titleColor();
          final originalCaption = captionColor();
          final originalBorder = border().right;
          expect(
            find.byKey(
              const ValueKey(('agenda-timeline-overdue-status', 'eclass')),
            ),
            findsNothing,
          );

          await show(entry, due.add(const Duration(minutes: 1)));
          expect(fill(), originalFill);
          expect(titleColor(), originalText);
          expect(
            border().right,
            BorderSide(color: theme.colorScheme.error, width: 3),
          );
          expect(border().left, BorderSide.none);
          expect(border().top, BorderSide.none);
          expect(border().bottom, BorderSide.none);
          expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
          expect(warningColor(), theme.colorScheme.onError);
          expect(find.text('13:00 已逾期'), findsOneWidget);
          expect(overdueStatusDecoration().color, theme.colorScheme.error);
          expect(
            tester.widget<Text>(find.text('13:00 已逾期')).style!.color,
            theme.colorScheme.onError,
          );

          await show(
            entry.copyWith(done: true),
            due.add(const Duration(minutes: 1)),
          );
          expect(fill().last, originalFill.last.withValues(alpha: 0.5));
          expect(titleColor(), originalText.withValues(alpha: 0.5));
          expect(captionColor(), originalCaption.withValues(alpha: 0.5));
          expect(
            border().right.color,
            originalBorder.color.withValues(alpha: 0.5),
          );
          expect(border().right.width, originalBorder.width);
          expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
          expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
          expect(
            find.byKey(
              const ValueKey(('agenda-timeline-overdue-status', 'eclass')),
            ),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
