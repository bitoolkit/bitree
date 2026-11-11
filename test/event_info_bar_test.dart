import 'package:bitree/agenda/model.dart';
import 'package:bitree/agenda/timeline_layout.dart';
import 'package:bitree/agenda/ui/agenda_timeline.dart';
import 'package:bitree/agenda/ui/event_timeline_entry.dart';
import 'package:bitree/app/settings_controller.dart';
import 'package:bitree/app/ui/settings_screen.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

const _key = 'agendaEventInfoBar';
final _date = DateTime.utc(2026, 11, 17);

AppSettingsController _settings(MemoryPreferences preferences) =>
    AppSettingsController(preferences, coursePaletteLoader: () async => {});

AgendaEntry _timed(String id, int startHour, int endHour) => AgendaEntry(
  id: id,
  title: id,
  kind: AgendaKind.event,
  startsAt: _date.add(Duration(hours: startHour)),
  endsAt: _date.add(Duration(hours: endHour)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Information bar defaults to visible without writing preferences', () async {
    final preferences = MemoryPreferences();
    final settings = _settings(preferences);
    addTearDown(settings.dispose);
    await settings.initialize();
    expect(settings.agendaEventInfoBar.value, isTrue);
    expect(preferences.value(_key), isNull);
  });

  test('Hidden bar restores, publishes immediately and survives restart', () async {
    final preferences = MemoryPreferences({_key: 'false'});
    final first = _settings(preferences);
    addTearDown(first.dispose);
    await first.initialize();
    expect(first.agendaEventInfoBar.value, isFalse);
    final writing = first.setAgendaEventInfoBar(true);
    expect(first.agendaEventInfoBar.value, isTrue);
    await writing;
    expect(preferences.value(_key), 'true');
    final restarted = _settings(preferences);
    addTearDown(restarted.dispose);
    await restarted.initialize();
    expect(restarted.agendaEventInfoBar.value, isTrue);
  });

  for (final invalid in ['', 'yes', 'TRUE', '1']) {
    test('Invalid saved visibility falls back to visible: $invalid', () async {
      final settings = _settings(MemoryPreferences({_key: invalid}));
      addTearDown(settings.dispose);
      await settings.initialize();
      expect(settings.agendaEventInfoBar.value, isTrue);
    });
  }

  test('Hidden information releases the lane lead and the painted lead', () {
    final event = _timed('event', 11, 13);
    final deadline = AgendaEntry(
      id: 'ddl',
      title: 'ddl',
      kind: AgendaKind.deadline,
      startsAt: _date.add(const Duration(days: 1, hours: 12)),
    );
    final fixedCardSpan = Duration(
      microseconds: (Duration.microsecondsPerDay * 3.75).round(),
    );
    for (final reserve in [true, false]) {
      final placements = layoutAgendaTimeline(
        [event, deadline],
        minimumEventSpan: const Duration(minutes: 1),
        reserveEventInformation: reserve,
      );
      final byId = {for (final p in placements) p.entry.id: p};
      final painted = byId['event']!;
      expect(
        painted.start,
        reserve
            ? event.startsAt.subtract(const Duration(days: 4))
            : event.startsAt,
      );
      expect(
        painted.paintStart,
        reserve ? lessThan(event.startsAt) : event.startsAt,
      );
      expect(painted.end, event.endsAt);
      expect(painted.paintEnd, event.endsAt);
      // Deadlines keep their information lead regardless of this setting.
      expect(byId['ddl']!.start, deadline.dueAt.subtract(const Duration(days: 4)));
      expect(byId['ddl']!.paintStart, deadline.dueAt.subtract(fixedCardSpan));
    }
  });

  testWidgets('The switch hides event text, releases its lane lead, and restores', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final entries = [
      _timed('morning', 11, 13),
      _timed('afternoon', 13, 15),
      AgendaEntry(
        id: 'ddl',
        title: 'ddl',
        kind: AgendaKind.deadline,
        startsAt: _date.add(const Duration(days: 1, hours: 12)),
      ),
    ];
    final app = TestAppController(entries: entries);
    await app.initialize();
    await tester.pumpWidget(MaterialApp(
      theme: bitreeTheme(Brightness.light),
      home: Scaffold(body: AgendaTimeline(
        controller: app,
        entries: entries,
        now: _date.add(const Duration(hours: 10)),
      )),
    ));
    await tester.pumpAndSettle();
    Finder card(String id) => find.byKey(ValueKey(('agenda-timeline-entry', id)));
    Finder event(String id) => find.byWidgetPredicate(
      (widget) => widget is EventTimelineEntry && widget.entry.id == id,
    );
    Finder bar(String id) => find.byKey(ValueKey(('agenda-timeline-bar', id)));
    expect(bar('morning'), findsOneWidget);
    final shown = tester.widget<EventTimelineEntry>(event('morning'));
    expect(shown.showInformation, isTrue);
    expect(
      shown.geometry.startX - shown.geometry.informationLeft,
      closeTo(48 * 3.75, .001),
    );
    // The information lead makes back-to-back intervals overlap in layout.
    expect(
      tester.getRect(card('morning')).top,
      isNot(closeTo(tester.getRect(card('afternoon')).top, .001)),
    );

    await app.settings.setAgendaEventInfoBar(false);
    await tester.pumpAndSettle();
    expect(bar('morning'), findsNothing);
    expect(bar('afternoon'), findsNothing);
    final hidden = tester.widget<EventTimelineEntry>(event('morning'));
    expect(hidden.showInformation, isFalse);
    // The painted surface still keeps exactly one line width left of the
    // real start so the start indicator stays visible.
    expect(hidden.geometry.informationLeft, closeTo(0, .001));
    expect(hidden.geometry.startX, closeTo(3, .001));
    // Without the lead the adjacent intervals share one lane.
    expect(
      tester.getRect(card('morning')).top,
      closeTo(tester.getRect(card('afternoon')).top, .001),
    );
    // Deadlines keep their own information cards.
    expect(bar('ddl'), findsOneWidget);

    await app.settings.setAgendaEventInfoBar(true);
    await tester.pumpAndSettle();
    expect(bar('morning'), findsOneWidget);
    final restored = tester.widget<EventTimelineEntry>(event('morning'));
    expect(
      restored.geometry.startX - restored.geometry.informationLeft,
      closeTo(48 * 3.75, .001),
    );
    expect(
      tester.getRect(card('morning')).top,
      isNot(closeTo(tester.getRect(card('afternoon')).top, .001)),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Settings switches the event information bar for events and exams', (
    tester,
  ) async {
    final preferences = MemoryPreferences();
    final controller = TestAppController(preferences: preferences);
    await controller.initialize();
    await tester.pumpWidget(MaterialApp(
      theme: bitreeTheme(Brightness.light),
      home: Scaffold(body: SettingsScreen(
        controller: controller,
        checkingForUpdates: false,
        onCheckForUpdates: () {},
      )),
    ));
    await tester.pump();
    final switcher = find.byKey(const ValueKey('agenda-event-info-bar-settings'));
    // The settings list builds lazily, so scroll until the row exists.
    await tester.scrollUntilVisible(
      switcher,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(switcher).value, isTrue);
    await tester.tap(switcher);
    await tester.pumpAndSettle();
    expect(controller.settings.agendaEventInfoBar.value, isFalse);
    expect(preferences.value(_key), 'false');
    await tester.tap(switcher);
    await tester.pumpAndSettle();
    expect(controller.settings.agendaEventInfoBar.value, isTrue);
    expect(preferences.value(_key), 'true');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
