import 'dart:async';

import 'package:bitree/app/ui/settings_screen.dart';
import 'package:bitree/l10n/app_localizations.dart';
import 'package:bitree/schedule/height_mode.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

const _heightKey = 'timetableHeightMode';

class _DelayedHeightReadPreferences extends MemoryPreferences {
  final started = Completer<void>();
  final result = Completer<String?>();

  @override
  Future<String?> getString(String key) {
    if (key != _heightKey) return super.getString(key);
    if (!started.isCompleted) started.complete();
    return result.future;
  }
}

class _DelayedHeightWritePreferences extends MemoryPreferences {
  final started = Completer<void>();
  final release = Completer<void>();
  final writes = <String>[];

  @override
  Future<void> setString(String key, String value) async {
    if (key != _heightKey) return super.setString(key, value);
    writes.add(value);
    if (writes.length == 1) {
      started.complete();
      await release.future;
    }
    await super.setString(key, value);
  }
}

void main() {
  test('Timetable height defaults to normal without a saved preference', () async {
    final preferences = MemoryPreferences();
    final app = TestAppController(preferences: preferences);
    expect(app.settings.timetableHeightMode.value, TimetableHeightMode.normal);

    await app.initialize();

    expect(app.settings.timetableHeightMode.value, TimetableHeightMode.normal);
    expect(preferences.value(_heightKey), isNull);
  });

  test('A saved fit-to-screen preference is restored on initialization', () async {
    final preferences = MemoryPreferences({_heightKey: 'fit'});
    final app = TestAppController(preferences: preferences);
    await app.initialize();

    expect(app.settings.timetableHeightMode.value, TimetableHeightMode.fit);
  });

  test('Choosing normal publishes immediately, persists and survives restart', () async {
    final preferences = MemoryPreferences({_heightKey: 'fit'});
    final first = TestAppController(preferences: preferences);
    await first.initialize();
    expect(first.settings.timetableHeightMode.value, TimetableHeightMode.fit);

    final saved = first.settings.setTimetableHeightMode(
      TimetableHeightMode.normal,
    );
    expect(first.settings.timetableHeightMode.value, TimetableHeightMode.normal);
    await saved;
    expect(preferences.value(_heightKey), 'normal');

    final restarted = TestAppController(preferences: preferences);
    await restarted.initialize();
    expect(
      restarted.settings.timetableHeightMode.value,
      TimetableHeightMode.normal,
    );
  });

  for (final invalid in ['', 'unknown-height', 'Fit']) {
    test('An invalid saved timetable height "$invalid" falls back to normal', () async {
      final app = TestAppController(
        preferences: MemoryPreferences({_heightKey: invalid}),
      );
      await app.initialize();

      expect(app.settings.timetableHeightMode.value, TimetableHeightMode.normal);
    });
  }

  test('Rapid height changes serialize writes and keep the latest choice', () async {
    final preferences = _DelayedHeightWritePreferences();
    final app = TestAppController(preferences: preferences);
    await app.initialize();

    final first = app.settings.setTimetableHeightMode(TimetableHeightMode.fit);
    await preferences.started.future;
    final second = app.settings.setTimetableHeightMode(
      TimetableHeightMode.normal,
    );
    final last = app.settings.setTimetableHeightMode(TimetableHeightMode.fit);
    expect(app.settings.timetableHeightMode.value, TimetableHeightMode.fit);
    expect(preferences.writes, ['fit']);

    preferences.release.complete();
    await Future.wait([first, second, last]);
    expect(preferences.writes, ['fit', 'normal', 'fit']);
    expect(preferences.value(_heightKey), 'fit');

    final restarted = TestAppController(preferences: preferences);
    await restarted.initialize();
    expect(restarted.settings.timetableHeightMode.value, TimetableHeightMode.fit);
  });

  test('A delayed startup read cannot replace a newer height choice', () async {
    final preferences = _DelayedHeightReadPreferences();
    final app = TestAppController(preferences: preferences);
    final loading = app.initialize();
    await preferences.started.future;

    await app.settings.setTimetableHeightMode(TimetableHeightMode.fit);
    expect(app.settings.timetableHeightMode.value, TimetableHeightMode.fit);
    preferences.result.complete('normal');
    await loading;

    expect(app.settings.timetableHeightMode.value, TimetableHeightMode.fit);
    expect(preferences.value(_heightKey), 'fit');
  });

  for (final (locale, heading, fitLabel, normalLabel) in [
    (const Locale('zh'), '课表高度', '适应屏幕', '正常高度'),
    (const Locale('en'), 'Timetable height', 'Fit to screen', 'Normal height'),
  ]) {
    testWidgets('Height choices work without a timetable in ${locale.languageCode}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final preferences = MemoryPreferences();
      final app = TestAppController(preferences: preferences);
      await app.initialize();
      expect(app.timetable.schedule, isNull);
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: bitreeTheme(Brightness.light),
          home: Scaffold(
            body: SettingsScreen(
              controller: app,
              checkingForUpdates: false,
              onCheckForUpdates: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final selector = find.byType(SegmentedButton<TimetableHeightMode>);
      await tester.ensureVisible(selector);
      await tester.pumpAndSettle();
      expect(find.text(heading), findsOneWidget);
      expect(
        find.descendant(of: selector, matching: find.text(fitLabel)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: selector, matching: find.text(normalLabel)),
        findsOneWidget,
      );
      expect(
        tester.widget<SegmentedButton<TimetableHeightMode>>(selector).selected,
        {TimetableHeightMode.normal},
      );

      await tester.tap(
        find.descendant(of: selector, matching: find.text(fitLabel)),
      );
      await tester.pumpAndSettle();
      expect(app.settings.timetableHeightMode.value, TimetableHeightMode.fit);
      expect(preferences.value(_heightKey), 'fit');
      expect(
        tester.widget<SegmentedButton<TimetableHeightMode>>(selector).selected,
        {TimetableHeightMode.fit},
      );

      await tester.tap(
        find.descendant(of: selector, matching: find.text(normalLabel)),
      );
      await tester.pumpAndSettle();
      expect(app.settings.timetableHeightMode.value, TimetableHeightMode.normal);
      expect(preferences.value(_heightKey), 'normal');

      // This setter only notifies its ValueNotifier, not the parent controller.
      await app.settings.setTimetableHeightMode(TimetableHeightMode.fit);
      await tester.pumpAndSettle();
      expect(
        tester.widget<SegmentedButton<TimetableHeightMode>>(selector).selected,
        {TimetableHeightMode.fit},
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}
