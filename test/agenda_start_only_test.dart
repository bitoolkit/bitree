import 'dart:convert';

import 'package:bitree/agenda/model.dart';
import 'package:bitree/agenda/timeline_layout.dart';
import 'package:bitree/agenda/ui/agenda_timeline.dart';
import 'package:bitree/agenda/ui/timeline_entry.dart';
import 'package:bitree/l10n/app_localizations.dart';
import 'package:bitree/l10n/app_localizations_en.dart';
import 'package:bitree/l10n/app_localizations_zh.dart';
import 'package:bitree/l10n/formats.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

final _date = DateTime.utc(2026, 11, 17);
final _opens = DateTime.utc(2026, 11, 17, 8);

AgendaEntry _openEnded({
  String id = 'open',
  DateTime? startsAt,
  int tailDays = AgendaEntry.defaultTailDays,
  bool done = false,
}) => AgendaEntry(
  id: id,
  title: '第三章测验',
  kind: AgendaKind.deadline,
  startsAt: startsAt ?? _opens,
  tailDays: tailDays,
  done: done,
  startOnly: true,
);

AgendaEntry _due({
  String id = 'due',
  DateTime? startsAt,
  int tailDays = AgendaEntry.defaultTailDays,
}) => AgendaEntry(
  id: id,
  title: '第五章作业',
  kind: AgendaKind.deadline,
  startsAt: startsAt ?? _opens,
  tailDays: tailDays,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('storage', () {
    test('The open-ended flag round-trips through storage', () {
      final restored = AgendaEntry.fromJson(
        jsonDecode(jsonEncode(_openEnded().toJson())) as Map<String, dynamic>,
      );

      expect(_openEnded().toJson()['startOnly'], isTrue);
      expect(restored.startOnly, isTrue);
      expect(restored.kind, AgendaKind.deadline);
      expect(restored.startsAt, _opens);
    });

    test('Records written before the flag exist stay ordinary deadlines', () {
      final legacy = _openEnded().toJson()..remove('startOnly');

      expect(AgendaEntry.fromJson(legacy).startOnly, isFalse);
      expect(AgendaEntry.fromJson(_due().toJson()).startOnly, isFalse);
    });

    test('copyWith preserves the flag', () {
      expect(_openEnded().copyWith(done: true).startOnly, isTrue);
      expect(_due().copyWith(done: true).startOnly, isFalse);
    });

    test('Only a deadline can be open-ended', () {
      expect(
            () => AgendaEntry(
              id: 'exam',
              title: '期中考试',
              kind: AgendaKind.exam,
              startsAt: _opens,
              endsAt: _opens.add(const Duration(hours: 2)),
              startOnly: true,
            ),
            throwsA(isA<FormatException>()),
          );
    });
  });

  group('status', () {
    test('An open-ended deadline is never overdue', () {
      final now = DateTime.utc(2026, 11, 17);

      expect(
        _openEnded(startsAt: DateTime.utc(2020, 5, 1, 8)).overdue(now),
        isFalse,
      );
      expect(
        _due(startsAt: DateTime.utc(2020, 5, 1, 8)).overdue(now),
        isTrue,
      );
    });

    test('An open-ended deadline stays unfinished until it is ticked off', () {
      final now = DateTime.utc(2030, 1, 1);

      expect(_openEnded().isFinished(now), isFalse);
      expect(_openEnded(done: true).isFinished(now), isTrue);
    });
  });

  group('layout', () {
    test('The reservation grows right from the opening time', () {
      final placement = layoutAgendaTimeline(
        [_openEnded(tailDays: 6)],
        minimumEventSpan: const Duration(hours: 1),
        layoutDays: 6,
      ).single;

      expect(placement.start, _opens);
      expect(placement.end, _opens.add(const Duration(days: 6)));
      expect(placement.layoutEnd, _opens.add(const Duration(days: 6)));
    });

    test('A deadline with a due date still reserves its tail on the left', () {
      final placement = layoutAgendaTimeline(
        [_due(tailDays: 6)],
        minimumEventSpan: const Duration(hours: 1),
        layoutDays: 6,
      ).single;

      expect(placement.start, _opens.subtract(const Duration(days: 6)));
      expect(placement.end, _opens);
    });
  });

  group('labels', () {
    final localized = <AppLocalizations>[AppLocalizationsZh(), AppLocalizationsEn()];

    test('An open-ended deadline is never presented as due', () {
      for (final l10n in localized) {
        final time = localizedAgendaTime(l10n, _openEnded());

        expect(time, contains(l10n.start));
        expect(time, isNot(contains(l10n.due)));
        expect(
          localizedAgendaTimeCaption(l10n, _openEnded(), _date),
          l10n.start,
        );
      }
    });

    test('A deadline with a due date keeps its due wording', () {
      for (final l10n in localized) {
        expect(localizedAgendaTime(l10n, _due()), contains(l10n.due));
        expect(localizedAgendaTimeCaption(l10n, _due(), _date), l10n.due);
      }
    });
  });

  group('card', () {
    Future<void> showCard(WidgetTester tester, AgendaEntry entry) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: bitreeTheme(Brightness.light),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 240,
                height: 120,
                child: AgendaTimelineEntry(
                  entry: entry,
                  now: _date,
                  barWidth: 240,
                  deadlineWidth: 240,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder bar(AgendaEntry entry) =>
        find.byKey(ValueKey(('agenda-timeline-bar', entry.id)));

    LinearGradient fill(WidgetTester tester, AgendaEntry entry) {
      final ink = tester.widget<Ink>(
        find.descendant(of: bar(entry), matching: find.byType(Ink)),
      );
      return (ink.decoration! as BoxDecoration).gradient! as LinearGradient;
    }

    Border outline(WidgetTester tester, AgendaEntry entry) {
      final foreground = tester.widget<DecoratedBox>(
        find.descendant(
          of: bar(entry),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is DecoratedBox &&
                widget.position == DecorationPosition.foreground,
          ),
        ),
      );
      return (foreground.decoration as BoxDecoration).border! as Border;
    }

    testWidgets('The accent line moves to the left edge', (tester) async {
      final open = _openEnded();
      await showCard(tester, open);
      final border = outline(tester, open);

      expect(border.left.width, 3);
      expect(border.right, BorderSide.none);
      expect(border.top, BorderSide.none);
      expect(border.bottom, BorderSide.none);

      final due = _due();
      await showCard(tester, due);
      expect(outline(tester, due).right.width, 3);
      expect(outline(tester, due).left, BorderSide.none);
      expect(tester.takeException(), isNull);
    });

    testWidgets('The fill fades out towards the right', (tester) async {
      final open = _openEnded();
      await showCard(tester, open);
      final gradient = fill(tester, open);

      expect(gradient.colors.first.a, 1);
      expect(gradient.colors[1].a, 1);
      expect(gradient.colors.last.a, 0);
      expect(gradient.stops, [0.0, 0.82, 1.0]);

      final due = _due();
      await showCard(tester, due);
      final standard = fill(tester, due);
      expect(standard.colors.first.a, 0);
      expect(standard.colors.last.a, 1);
      expect(standard.stops, [0.0, 0.18, 1.0]);
    });

    testWidgets('Text hugs the line on the left', (tester) async {
      final open = _openEnded();
      await showCard(tester, open);
      expect(
        tester.widget<Text>(find.text(open.title)).textAlign,
        TextAlign.left,
      );

      final due = _due();
      await showCard(tester, due);
      expect(
        tester.widget<Text>(find.text(due.title)).textAlign,
        TextAlign.right,
      );
    });
  });

  group('timeline', () {
    Future<void> showTimeline(
      WidgetTester tester,
      List<AgendaEntry> entries, {
      int layoutDays = 4,
    }) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final app = TestAppController(entries: entries);
      await app.initialize();
      await app.settings.setAgendaLayoutDays(layoutDays);
      await tester.pumpWidget(
        MaterialApp(
          theme: bitreeTheme(Brightness.light),
          home: Scaffold(
            body: AgendaTimeline(
              controller: app,
              entries: entries,
              now: _date.add(const Duration(hours: 12)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Rect bar(WidgetTester tester, AgendaEntry entry) => tester.getRect(
      find.byKey(ValueKey(('agenda-timeline-bar', entry.id))),
    );

    testWidgets('The card keeps the deadline width and grows rightwards', (
      tester,
    ) async {
      final due = _due(tailDays: 6);
      final open = _openEnded(tailDays: 6);
      await showTimeline(tester, [due, open], layoutDays: 6);
      final dueRect = bar(tester, due);
      final openRect = bar(tester, open);

      // Same painted width, anchored at the opening time instead: the two
      // cards meet exactly where the due one ends.
      expect(openRect.width, greaterThan(0));
      expect(openRect.width, closeTo(dueRect.width, .001));
      expect(openRect.left, closeTo(dueRect.right, .001));
      expect(openRect.right, greaterThan(dueRect.right));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('The card stays painted as the view zooms in', (tester) async {
      final open = _openEnded(tailDays: 12);
      await showTimeline(tester, [open], layoutDays: 12);
      final before = bar(tester, open);
      expect(before.width, closeTo(48 * (12 - .25), .001));
      tester.widget<Slider>(find.byType(Slider)).onChanged!(24);
      await tester.pumpAndSettle();
      final after = bar(tester, open);

      // The painted width is set by the minimum zoom, so the card keeps its
      // screen width while the lane reservation behind it stretches.
      expect(
        find.byKey(ValueKey(('agenda-timeline-bar', open.id))),
        findsOneWidget,
      );
      expect(after.width, closeTo(before.width, .001));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
