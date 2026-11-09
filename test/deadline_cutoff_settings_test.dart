import 'dart:async';
import 'dart:convert';

import 'package:bitree/agenda/deadline_cutoff.dart';
import 'package:bitree/app/settings_controller.dart';
import 'package:bitree/app/ui/deadline_cutoff_settings.dart';
import 'package:bitree/app/ui/settings_screen.dart';
import 'package:bitree/l10n/app_localizations.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

const _key = 'deadlineCutoff';

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

class _FailOncePreferences extends MemoryPreferences {
  final _failedWrites = <String>{};

  @override
  Future<void> setString(String key, String value) async {
    if (key == _key && _failedWrites.add(key)) {
      throw Exception('simulated preference write failure');
    }
    await super.setString(key, value);
  }
}

class _FailReadPreferences extends MemoryPreferences {
  @override
  Future<String?> getString(String key) async {
    if (key == _key) throw Exception('simulated preference read failure');
    return super.getString(key);
  }
}

AppSettingsController _settings(MemoryPreferences preferences) =>
    AppSettingsController(preferences, coursePaletteLoader: () async => {});

Future<void> _showCutoff(
  WidgetTester tester,
  AppSettingsController settings, {
  Locale locale = const Locale('zh'),
  double scale = 1,
  Size size = const Size(390, 844),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: bitreeTheme(Brightness.light),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          alwaysUse24HourFormat: true,
        ),
        child: child!,
      ),
      home: DeadlineCutoffScreen(settings: settings),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Cutoff defaults to disabled and retains the overnight preset', () async {
    final preferences = MemoryPreferences();
    final settings = _settings(preferences);
    addTearDown(settings.dispose);
    expect(settings.deadlineCutoff.value, const DeadlineCutoffWindow());
    await settings.initialize();
    expect(settings.deadlineCutoff.value.enabled, isFalse);
    expect(settings.deadlineCutoff.value.startMinute, 22 * 60);
    expect(settings.deadlineCutoff.value.endMinute, 8 * 60);
    expect(preferences.value(_key), isNull);
  });

  test('A saved cutoff is restored and a disabled choice survives restart', () async {
    const saved = DeadlineCutoffWindow(
      enabled: true,
      startMinute: 21 * 60 + 30,
      endMinute: 7 * 60 + 15,
    );
    final preferences = MemoryPreferences({_key: jsonEncode(saved.toJson())});
    final first = _settings(preferences);
    addTearDown(first.dispose);
    await first.initialize();
    expect(first.deadlineCutoff.value, saved);
    var settingNotifications = 0;
    var valueNotifications = 0;
    first.addListener(() => settingNotifications++);
    first.deadlineCutoff.addListener(() => valueNotifications++);

    final disabled = saved.copyWith(enabled: false);
    final writing = first.setDeadlineCutoff(disabled);
    expect(first.deadlineCutoff.value, disabled);
    expect(settingNotifications, 1);
    expect(valueNotifications, 1);
    await writing;
    expect(jsonDecode(preferences.value(_key)!), disabled.toJson());

    final restarted = _settings(preferences);
    addTearDown(restarted.dispose);
    await restarted.initialize();
    expect(restarted.deadlineCutoff.value, disabled);
    expect(restarted.deadlineCutoff.value.startMinute, saved.startMinute);
    expect(restarted.deadlineCutoff.value.endMinute, saved.endMinute);
  });

  test('Rapid cutoff changes save in order with the newest value last', () async {
    final preferences = _DelayedWritePreferences();
    final settings = _settings(preferences);
    addTearDown(settings.dispose);
    await settings.initialize();
    const enabled = DeadlineCutoffWindow(enabled: true);
    final first = settings.setDeadlineCutoff(enabled);
    await preferences.started.future;
    final changed = enabled.copyWith(startMinute: 20 * 60);
    final second = settings.setDeadlineCutoff(changed);
    final disabled = changed.copyWith(enabled: false);
    final last = settings.setDeadlineCutoff(disabled);
    expect(settings.deadlineCutoff.value, disabled);
    expect(preferences.writes, hasLength(1));
    preferences.release.complete();
    await Future.wait([first, second, last]);
    expect(
      preferences.writes.map(jsonDecode).toList(),
      [enabled.toJson(), changed.toJson(), disabled.toJson()],
    );
    expect(jsonDecode(preferences.value(_key)!), disabled.toJson());
  });

  test('A late initialize read cannot replace a newer cutoff choice', () async {
    final preferences = _DelayedReadPreferences();
    final settings = _settings(preferences);
    addTearDown(settings.dispose);
    final loading = settings.initialize();
    await preferences.started.future;
    const chosen = DeadlineCutoffWindow(enabled: true, startMinute: 600);
    await settings.setDeadlineCutoff(chosen);
    preferences.result.complete(jsonEncode(const DeadlineCutoffWindow().toJson()));
    await loading;
    expect(settings.deadlineCutoff.value, chosen);
    expect(jsonDecode(preferences.value(_key)!), chosen.toJson());
  });

  test('A pending cutoff read does not publish after disposal', () async {
    final preferences = _DelayedReadPreferences();
    final settings = _settings(preferences);
    final loading = settings.initialize();
    await preferences.started.future;
    settings.dispose();
    preferences.result.complete(
      jsonEncode(const DeadlineCutoffWindow(enabled: true).toJson()),
    );
    await expectLater(loading, completes);
    await expectLater(
      settings.setDeadlineCutoff(const DeadlineCutoffWindow(enabled: true)),
      completes,
    );
    expect(preferences.value(_key), isNull);
  });

  for (final invalid in [
    'not-json',
    '[]',
    '{"enabled":true,"startMinute":1440,"endMinute":480}',
    '{"enabled":"yes","startMinute":1320,"endMinute":480}',
  ]) {
    test('Invalid cutoff data falls back to disabled: $invalid', () async {
      final settings = _settings(MemoryPreferences({_key: invalid}));
      addTearDown(settings.dispose);
      await settings.initialize();
      expect(settings.deadlineCutoff.value, const DeadlineCutoffWindow());
    });
  }

  test('A cutoff read failure leaves the disabled preset usable', () async {
    final settings = _settings(_FailReadPreferences());
    addTearDown(settings.dispose);
    await settings.initialize();
    expect(settings.deadlineCutoff.value, const DeadlineCutoffWindow());
    await settings.setDeadlineCutoff(const DeadlineCutoffWindow(enabled: true));
    expect(settings.deadlineCutoff.value.enabled, isTrue);
  });

  test('A failed cutoff write does not poison later queued saves', () async {
    final preferences = _FailOncePreferences();
    final settings = _settings(preferences);
    addTearDown(settings.dispose);
    await settings.initialize();
    const enabled = DeadlineCutoffWindow(enabled: true);
    await expectLater(settings.setDeadlineCutoff(enabled), completes);
    expect(settings.deadlineCutoff.value, enabled);
    final latest = enabled.copyWith(endMinute: 600);
    await settings.setDeadlineCutoff(latest);
    expect(jsonDecode(preferences.value(_key)!), latest.toJson());
  });

  for (final locale in [const Locale('zh'), const Locale('en')]) {
    testWidgets('Cutoff settings explain every interval mode in ${locale.languageCode}', (
      tester,
    ) async {
      final preferences = MemoryPreferences();
      final settings = _settings(preferences);
      addTearDown(settings.dispose);
      await settings.initialize();
      await _showCutoff(
        tester,
        settings,
        locale: locale,
        size: const Size(320, 640),
        scale: 1.8,
      );
      final context = tester.element(find.byType(DeadlineCutoffScreen));
      final l10n = AppLocalizations.of(context);
      expect(find.text(l10n.settingsDeadlineCutoff), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(
          find.byKey(const ValueKey('deadline-cutoff-enabled')),
        ).value,
        isFalse,
      );
      expect(find.text(l10n.deadlineCutoffOvernight('22:00', '08:00')), findsOneWidget);
      final switcher = find.byKey(const ValueKey('deadline-cutoff-enabled'));
      await tester.ensureVisible(switcher);
      await tester.tap(switcher);
      await tester.pumpAndSettle();
      expect(settings.deadlineCutoff.value.enabled, isTrue);
      await tester.tap(switcher);
      await tester.pumpAndSettle();
      expect(settings.deadlineCutoff.value.enabled, isFalse);
      expect(settings.deadlineCutoff.value.startMinute, 22 * 60);
      expect(settings.deadlineCutoff.value.endMinute, 8 * 60);

      await settings.setDeadlineCutoff(
        const DeadlineCutoffWindow(startMinute: 600, endMinute: 720),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.deadlineCutoffSameDay('10:00', '12:00')), findsOneWidget);
      await settings.setDeadlineCutoff(
        const DeadlineCutoffWindow(startMinute: 600, endMinute: 600),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.deadlineCutoffInstant('10:00')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('Canceling either time picker does not persist a cutoff', (
    tester,
  ) async {
    final preferences = MemoryPreferences();
    final settings = _settings(preferences);
    addTearDown(settings.dispose);
    await settings.initialize();
    await _showCutoff(tester, settings);
    for (final name in ['deadline-cutoff-start', 'deadline-cutoff-end']) {
      final tile = find.byKey(ValueKey(name));
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      final pickerContext = tester.element(find.byType(TimePickerDialog));
      await tester.tap(find.text(MaterialLocalizations.of(pickerContext).cancelButtonLabel));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsNothing);
      expect(settings.deadlineCutoff.value, const DeadlineCutoffWindow());
      expect(preferences.value(_key), isNull);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Time picker changes only the selected endpoint and saves it', (
    tester,
  ) async {
    final preferences = MemoryPreferences();
    final settings = _settings(preferences);
    addTearDown(settings.dispose);
    await settings.initialize();
    await _showCutoff(tester, settings);
    final tile = find.byKey(const ValueKey('deadline-cutoff-start'));
    await tester.tap(tile);
    await tester.pumpAndSettle();
    final inputs = find.descendant(
      of: find.byType(TimePickerDialog),
      matching: find.byType(TextField),
    );
    expect(inputs, findsNWidgets(2));
    // Preserve changes made while the picker is open, not its old snapshot.
    await settings.setDeadlineCutoff(
      const DeadlineCutoffWindow(enabled: true, endMinute: 600),
    );
    await tester.pump();
    await tester.enterText(inputs.first, '21');
    await tester.enterText(inputs.last, '15');
    final pickerContext = tester.element(find.byType(TimePickerDialog));
    await tester.tap(find.text(MaterialLocalizations.of(pickerContext).okButtonLabel));
    await tester.pumpAndSettle();
    expect(settings.deadlineCutoff.value.startMinute, 21 * 60 + 15);
    expect(settings.deadlineCutoff.value.endMinute, 600);
    expect(settings.deadlineCutoff.value.enabled, isTrue);
    expect(jsonDecode(preferences.value(_key)!), settings.deadlineCutoff.value.toJson());
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Settings expose cutoff without a timetable or school account', (
    tester,
  ) async {
    final app = TestAppController();
    await app.initialize();
    await tester.pumpWidget(
      MaterialApp(
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
    final entry = find.byKey(const ValueKey('deadline-cutoff-settings'));
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byType(DeadlineCutoffScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
