import 'package:bitree/agenda/agenda_color.dart';
import 'package:bitree/agenda/deadline_source.dart';
import 'package:bitree/agenda/model.dart';
import 'package:bitree/agenda/ui/agenda_color_palette.dart';
import 'package:bitree/agenda/ui/timeline_colors.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime.utc(2026, 11, 17, 18);
  final now = start.subtract(const Duration(hours: 1));

  AgendaEntry deadline(String id, DeadlineSource? source) => AgendaEntry(
    id: id,
    title: id,
    kind: AgendaKind.deadline,
    startsAt: start,
    source: source,
  );

  final entries = [
    AgendaEntry(
      id: 'event',
      title: '日程',
      kind: AgendaKind.event,
      startsAt: start,
      endsAt: start.add(const Duration(hours: 1)),
    ),
    AgendaEntry(
      id: 'exam',
      title: '考试',
      kind: AgendaKind.exam,
      startsAt: start,
      endsAt: start.add(const Duration(hours: 1)),
    ),
    deadline('physics-lab:color-test', null),
    deadline('lexue', DeadlineSource.lexue),
    deadline('eclass', DeadlineSource.eclass),
    deadline('mooc', DeadlineSource.mooc),
    deadline('manual', null),
  ];

  for (final brightness in Brightness.values) {
    testWidgets('Timeline tones stay distinct in $brightness', (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          theme: bitreeTheme(brightness),
          home: Builder(
            builder: (value) {
              context = value;
              return const SizedBox();
            },
          ),
        ),
      );

      final fills = [
        for (final entry in entries)
          agendaTimelineColors(context, entry, now).fill.toARGB32(),
      ];
      expect(fills.toSet(), hasLength(entries.length));

      for (final color in AgendaColor.presets) {
        final custom = AgendaEntry(
          id: color.id!,
          title: color.id!,
          kind: AgendaKind.deadline,
          startsAt: start,
          source: DeadlineSource.lexue,
          color: color,
        );
        final values = agendaColorValues(Theme.of(context).colorScheme, color);
        expect(agendaTimelineColors(context, custom, now), (
          fill: values.fill,
          text: values.text,
          accent: values.accent,
        ));
      }
    });

    testWidgets('Overdue DDLs use error semantic colors in $brightness', (
      tester,
    ) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          theme: bitreeTheme(brightness),
          home: Builder(
            builder: (value) {
              context = value;
              return const SizedBox();
            },
          ),
        ),
      );
      final scheme = Theme.of(context).colorScheme;
      final pastDue = start.add(const Duration(minutes: 1));
      for (final entry in entries.where((entry) => entry.isDeadline)) {
        final colors = agendaTimelineColors(context, entry, pastDue);
        expect(colors.fill, scheme.errorContainer);
        expect(colors.text, scheme.onErrorContainer);
        expect(colors.accent, scheme.error);

        final completed = entry.copyWith(done: true);
        final finishedColors = agendaTimelineColors(
          context,
          completed,
          pastDue,
        );
        expect(finishedColors, agendaTimelineColors(context, completed, now));
        expect(finishedColors.fill.a, closeTo(0.5, 0.01));
        expect(finishedColors.text.a, closeTo(0.5, 0.01));
        expect(finishedColors.accent.a, closeTo(0.5, 0.01));
      }
    });
  }
}
