import 'package:bitree/agenda/deadline_source.dart';
import 'package:bitree/agenda/model.dart';
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
    });
  }
}
