import 'dart:async';

import 'package:bitree/agenda/model.dart';
import 'package:bitree/agenda/timeline_layout.dart';
import 'package:bitree/agenda/ui/agenda_timeline.dart';
import 'package:bitree/app/settings_controller.dart';
import 'package:bitree/app/ui/agenda_layout_days_settings.dart';
import 'package:bitree/l10n/l10n.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

const _key = 'agendaLayoutDays';
final _date = DateTime.utc(2026, 11, 17, 12);

class _DelayedReadPreferences extends MemoryPreferences {
  final started = Completer<void>();
  final result = Completer<String?>();

  @override
  Future<String?> getString(String key) {
    if (key != _key) return super.getString(key);
    if (!started.isCompleted) started.complete();
    return result.future;
  }
}

class _DelayedWritePreferences extends MemoryPreferences {
  final started = Completer<void>();
  final release = Completer<void>();
  final writes = <String>[];

  @override
  Future<void> setString(String key, String value) async {
    if (key != _key) return super.setString(key, value);
    writes.add(value);
    if (writes.length == 1) {
      started.complete();
      await release.future;
    }
    await super.setString(key, value);
  }
}

AppSettingsController _settings(MemoryPreferences preferences) =>
    AppSettingsController(preferences, coursePaletteLoader: () async => {});

AgendaEntry _entry(
  String id, {
  bool startOnly = false,
  DeadlineCutoffWindow cutoff = const DeadlineCutoffWindow(),
  int? tailDays,
}) => AgendaEntry(
  id: id,
  title: id,
  kind: AgendaKind.deadline,
  startsAt: _date,
  startOnly: startOnly,
  tailDays: tailDays,
  deadlineCutoffWindow: cutoff,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Layout days default to four without writing preferences', () async {
    final preferences = MemoryPreferences();
    final settings = _settings(preferences);
    addTearDown(settings.dispose);
    await settings.initialize();
    expect(settings.agendaLayoutDays.value, 4);
    expect(preferences.value(_key), isNull);
  });

  test(
    'Layout days restore, publish immediately and survive restart',
    () async {
      final preferences = MemoryPreferences({_key: '7'});
      final first = _settings(preferences);
      addTearDown(first.dispose);
      await first.initialize();
      expect(first.agendaLayoutDays.value, 7);
      final writing = first.setAgendaLayoutDays(12);
      expect(first.agendaLayoutDays.value, 12);
      await writing;
      expect(preferences.value(_key), '12');
      final restarted = _settings(preferences);
      addTearDown(restarted.dispose);
      await restarted.initialize();
      expect(restarted.agendaLayoutDays.value, 12);
    },
  );

  for (final invalid in ['', '0', '31', '-2', '2.5', 'unknown']) {
    test('Invalid saved width falls back to four: $invalid', () async {
      final settings = _settings(MemoryPreferences({_key: invalid}));
      addTearDown(settings.dispose);
      await settings.initialize();
      expect(settings.agendaLayoutDays.value, 4);
    });
  }

  test('Invalid setter values cannot change the selected width', () async {
    final settings = _settings(MemoryPreferences());
    addTearDown(settings.dispose);
    expect(() => settings.setAgendaLayoutDays(0), throwsRangeError);
    expect(() => settings.setAgendaLayoutDays(31), throwsRangeError);
    expect(settings.agendaLayoutDays.value, 4);
  });

  test('Rapid width changes persist in order with the latest last', () async {
    final preferences = _DelayedWritePreferences();
    final settings = _settings(preferences);
    addTearDown(settings.dispose);
    await settings.initialize();
    final first = settings.setAgendaLayoutDays(1);
    await preferences.started.future;
    final middle = settings.setAgendaLayoutDays(30);
    final last = settings.setAgendaLayoutDays(8);
    expect(settings.agendaLayoutDays.value, 8);
    preferences.release.complete();
    await Future.wait([first, middle, last]);
    expect(preferences.writes, ['1', '30', '8']);
    expect(preferences.value(_key), '8');
  });

  test('A late read does not replace a newer user width', () async {
    final preferences = _DelayedReadPreferences();
    final settings = _settings(preferences);
    addTearDown(settings.dispose);
    final loading = settings.initialize();
    await preferences.started.future;
    await settings.setAgendaLayoutDays(9);
    preferences.result.complete('14');
    await loading;
    expect(settings.agendaLayoutDays.value, 9);
    expect(preferences.value(_key), '9');
  });

  test('A pending read and setter cannot publish after disposal', () async {
    final preferences = _DelayedReadPreferences();
    final settings = _settings(preferences);
    final loading = settings.initialize();
    await preferences.started.future;
    settings.dispose();
    preferences.result.complete('14');
    await expectLater(loading, completes);
    await expectLater(settings.setAgendaLayoutDays(8), completes);
    expect(preferences.value(_key), isNull);
  });

  test(
    'Sync preserves a saved per-item tail on an imported deadline',
    () async {
      final saved = AgendaEntry(
        id: 'imported',
        title: 'original',
        kind: AgendaKind.deadline,
        startsAt: _date,
        local: false,
        tailDays: 14,
      );
      final app = TestAppController(entries: [saved]);
      await app.initialize();
      expect(
        await app.agenda.mergeDeadlines([
          AgendaEntry(
            id: saved.id,
            title: 'updated',
            kind: saved.kind,
            startsAt: _date,
            local: false,
          ),
        ]),
        isTrue,
      );
      final updated = app.agenda.entries.single;
      expect(updated.title, 'updated');
      expect(updated.tailDays, 14);
      expect(updated.effectiveLayoutDays(8), 14);
    },
  );

  for (final days in [1, 4, 30]) {
    test('DDL reservations without overrides follow the global $days days', () {
      const cutoff = DeadlineCutoffWindow(
        enabled: true,
        startMinute: 10 * 60,
        endMinute: 18 * 60,
      );
      final entries = [
        _entry('plain'),
        _entry('open', startOnly: true),
        _entry('adjusted', cutoff: cutoff),
      ];
      final placements = layoutAgendaTimeline(
        entries,
        minimumEventSpan: const Duration(minutes: 1),
        layoutDays: days,
      );
      for (final placement in placements) {
        final entry = placement.entry;
        if (entry.startOnly) {
          expect(placement.start, entry.startsAt);
          expect(placement.end, entry.startsAt.add(Duration(days: days)));
        } else {
          expect(placement.start, entry.dueAt.subtract(Duration(days: days)));
          expect(placement.end, entry.realDueAt);
        }
      }
      expect(entries.map((e) => e.tailDays), [null, null, null]);
      expect(entries.every((e) => e.startsAt == _date), isTrue);
      expect(entries.every((e) => e.toJson()['tailDays'] == null), isTrue);
    });
  }

  test('Per-item tails override the global width for every DDL type', () {
    const cutoff = DeadlineCutoffWindow(
      enabled: true,
      startMinute: 10 * 60,
      endMinute: 18 * 60,
    );
    final entries = [
      _entry('plain', tailDays: 1),
      _entry('open', startOnly: true, tailDays: 30),
      _entry('adjusted', cutoff: cutoff, tailDays: 14),
    ];
    for (final days in [4, 8]) {
      final placements = layoutAgendaTimeline(
        entries,
        minimumEventSpan: const Duration(minutes: 1),
        layoutDays: days,
      );
      for (final p in placements) {
        final entry = p.entry;
        final span = Duration(days: entry.tailDays!);
        final cardSpan = Duration(
          microseconds: (Duration.microsecondsPerDay * (entry.tailDays! - .25))
              .round(),
        );
        expect(
          p.start,
          entry.startOnly ? entry.startsAt : entry.dueAt.subtract(span),
        );
        expect(
          p.end,
          entry.startOnly ? entry.startsAt.add(span) : entry.realDueAt,
        );
        expect(
          p.paintStart,
          entry.startOnly ? entry.startsAt : entry.dueAt.subtract(cardSpan),
        );
        expect(
          p.paintEnd,
          entry.startOnly ? entry.startsAt.add(cardSpan) : entry.realDueAt,
        );
      }
    }
  });

  testWidgets(
    'Live global changes respect plain, open and adjusted DDL overrides',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final entries = [
        _entry('plain', tailDays: 1),
        _entry('open', startOnly: true),
        _entry('custom-open', startOnly: true, tailDays: 6),
        _entry('inherited'),
      ];
      final app = TestAppController(entries: entries);
      await app.initialize();
      // Plain and adjusted use different clock times so only the latter matches.
      final adjusted = AgendaEntry(
        id: 'adjusted',
        title: 'adjusted',
        kind: AgendaKind.deadline,
        startsAt: _date.add(const Duration(hours: 2)),
        tailDays: 2,
      );
      final shown = [...entries, adjusted];
      await app.settings.setDeadlineCutoff(
        const DeadlineCutoffWindow(
          enabled: true,
          startMinute: 13 * 60,
          endMinute: 15 * 60,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: bitreeTheme(Brightness.light),
          home: Scaffold(
            body: AgendaTimeline(controller: app, entries: shown, now: _date),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state = tester.state(find.byType(AgendaTimeline));
      for (final days in [4, 8]) {
        await app.settings.setAgendaLayoutDays(days);
        await tester.pumpAndSettle();
        for (final entry in shown) {
          final bar = find.byKey(ValueKey(('agenda-timeline-bar', entry.id)));
          expect(bar, findsOneWidget);
          expect(
            tester.getSize(bar).width,
            closeTo(48 * (entry.effectiveLayoutDays(days) - .25), .001),
          );
        }
        expect(tester.state(find.byType(AgendaTimeline)), same(state));
      }
      tester.widget<Slider>(find.byType(Slider)).onChanged!(24);
      await tester.pumpAndSettle();
      for (final entry in shown) {
        final bar = find.byKey(ValueKey(('agenda-timeline-bar', entry.id)));
        expect(
          tester.getSize(bar).width,
          closeTo(48 * (entry.effectiveLayoutDays(8) - .25), .001),
        );
      }
      expect(entries.map((e) => e.tailDays), [1, null, 6, null]);
      expect(adjusted.tailDays, 2);
      expect(adjusted.startsAt, _date.add(const Duration(hours: 2)));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final locale in [const Locale('zh'), const Locale('en')]) {
    testWidgets(
      'Width settings work on a narrow large-text screen in $locale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final preferences = MemoryPreferences();
        final settings = _settings(preferences);
        addTearDown(settings.dispose);
        await settings.initialize();
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: bitreeTheme(Brightness.light),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(1.8)),
              child: child!,
            ),
            home: AgendaLayoutDaysScreen(settings: settings),
          ),
        );
        await tester.pumpAndSettle();
        final field = find.byKey(const ValueKey('agenda-layout-days-input'));
        await tester.scrollUntilVisible(
          field,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.enterText(field, '7');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(settings.agendaLayoutDays.value, 7);
        expect(preferences.value(_key), '7');
        await tester.enterText(field, '31');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(settings.agendaLayoutDays.value, 7);
        final context = tester.element(find.byType(AgendaLayoutDaysScreen));
        expect(find.text(context.l10n.agendaLayoutDaysRange), findsWidgets);
        await settings.setAgendaLayoutDays(12);
        await tester.pumpAndSettle();
        final textField = tester.widget<TextFormField>(field);
        expect(textField.controller!.text, '12');
        final slider = find.byKey(const ValueKey('agenda-layout-days-slider'));
        await tester.scrollUntilVisible(
          slider,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        tester.widget<Slider>(slider).onChanged!(30);
        await tester.pumpAndSettle();
        expect(settings.agendaLayoutDays.value, 30);
        expect(preferences.value(_key), '30');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
