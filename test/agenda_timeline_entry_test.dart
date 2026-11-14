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
        'Overdue DDLs keep source colours under a light error mask in $brightness, system=$system',
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

          BoxDecoration fillDecoration() {
            final ink = tester.widget<Ink>(
              find.descendant(of: bar, matching: find.byType(Ink)),
            );
            return ink.decoration! as BoxDecoration;
          }

          List<Color> fill() =>
              (fillDecoration().gradient! as LinearGradient).colors;

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
          Color captionColor(String text) =>
              tester.widget<Text>(find.text(text)).style!.color!;
          Color warningColor() => tester
              .widget<Icon>(
                find.byKey(
                  const ValueKey((
                    'agenda-timeline-overdue-watermark',
                    'eclass',
                  )),
                ),
              )
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
          final originalCaption = captionColor('13:00 截止');
          final originalBorder = border().right;
          expect(
            find.byKey(
              const ValueKey(('agenda-timeline-overdue-status', 'eclass')),
            ),
            findsNothing,
          );

          await show(entry, due.add(const Duration(minutes: 1)));
          final warningBackground = theme.colorScheme.errorContainer;
          final warningForeground = theme.colorScheme.onErrorContainer;
          expect(fillDecoration().color, isNull);
          expect((fillDecoration().gradient! as LinearGradient).stops, const [
            0,
            0.18,
            1,
          ]);
          expect(fill().first.a, 0);
          expect(fill().last, warningBackground);
          expect(titleColor(), warningForeground);
          expect(
            border().right,
            BorderSide(color: theme.colorScheme.error, width: 3),
          );
          expect(border().left, BorderSide.none);
          expect(border().top, BorderSide.none);
          expect(border().bottom, BorderSide.none);
          expect(find.byIcon(Icons.warning_amber_rounded), findsNWidgets(2));
          expect(
            find.byKey(
              const ValueKey(('agenda-timeline-overdue-watermark', 'eclass')),
            ),
            findsOneWidget,
          );
          expect(warningColor(), warningForeground.withValues(alpha: 0.2));
          expect(overdueStatusDecoration().color, theme.colorScheme.error);
          expect(
            tester.widget<Text>(find.text('13:00 已逾期')).style!.color,
            theme.colorScheme.onError,
          );
          expect(find.text('13:00 截止'), findsNothing);

          await show(
            entry.copyWith(done: true),
            due.add(const Duration(minutes: 1)),
          );
          expect(fill().last, originalFill.last.withValues(alpha: 0.5));
          expect(titleColor(), originalText.withValues(alpha: 0.5));
          expect(
            captionColor('13:00 截止'),
            originalCaption.withValues(alpha: 0.5),
          );
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
