import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

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

Future<void> _expectSummary(
  WidgetTester tester,
  String Function(AppLocalizations l10n, MaterialLocalizations material)
  expected,
) async {
  final summary = find.byKey(const ValueKey('deadline-cutoff-summary'));
  await tester.ensureVisible(summary);
  await tester.pumpAndSettle();
  final context = tester.element(summary);
  expect(
    tester.widget<Text>(summary).data,
    expected(AppLocalizations.of(context), MaterialLocalizations.of(context)),
  );
}

String _formattedTime(MaterialLocalizations material, int hour, int minute) =>
    material.formatTimeOfDay(
      TimeOfDay(hour: hour, minute: minute),
      alwaysUse24HourFormat: true,
    );

Future<void> _selectEndpoint(WidgetTester tester, {required bool start}) async {
  final target = find.byKey(
    ValueKey(start ? 'deadline-cutoff-start' : 'deadline-cutoff-end'),
  );
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _chooseTime(WidgetTester tester, int hour, int minute) async {
  final dial = find.descendant(
    of: find.byType(TimePickerDialog),
    matching: find.byWidgetPredicate(
      (widget) => widget is GestureDetector && widget.onPanUpdate != null,
    ),
  );
  final rect = tester.getRect(dial);
  Offset position(int value, int divisions, double radius) {
    final angle = 2 * math.pi * value / divisions - math.pi / 2;
    return rect.center + Offset(math.cos(angle), math.sin(angle)) * radius;
  }

  await tester.tapAt(
    position(hour % 12, 12, rect.width * (hour >= 12 ? .27 : .4)),
  );
  await tester.pumpAndSettle();
  await tester.tapAt(position(minute, 60, rect.width * .4));
  await tester.pumpAndSettle();
}

Future<void> _pickerAction(WidgetTester tester, {required bool confirm}) async {
  final context = tester.element(find.byType(TimePickerDialog));
  final material = MaterialLocalizations.of(context);
  final button = find.descendant(
    of: find.byType(TimePickerDialog),
    matching: find.text(
      confirm ? material.okButtonLabel : material.cancelButtonLabel,
    ),
  );
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Cutoff defaults to disabled and retains the overnight preset',
    () async {
      final preferences = MemoryPreferences();
      final settings = _settings(preferences);
      addTearDown(settings.dispose);
      expect(settings.deadlineCutoff.value, const DeadlineCutoffWindow());
      await settings.initialize();
      expect(settings.deadlineCutoff.value.enabled, isFalse);
      expect(settings.deadlineCutoff.value.startMinute, 22 * 60);
      expect(settings.deadlineCutoff.value.endMinute, 8 * 60);
      expect(preferences.value(_key), isNull);
    },
  );

  test(
    'A saved cutoff is restored and a disabled choice survives restart',
    () async {
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
    },
  );

  test(
    'Rapid cutoff changes save in order with the newest value last',
    () async {
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
      expect(preferences.writes.map(jsonDecode).toList(), [
        enabled.toJson(),
        changed.toJson(),
        disabled.toJson(),
      ]);
      expect(jsonDecode(preferences.value(_key)!), disabled.toJson());
    },
  );

  test('A late initialize read cannot replace a newer cutoff choice', () async {
    final preferences = _DelayedReadPreferences();
    final settings = _settings(preferences);
    addTearDown(settings.dispose);
    final loading = settings.initialize();
    await preferences.started.future;
    const chosen = DeadlineCutoffWindow(enabled: true, startMinute: 600);
    await settings.setDeadlineCutoff(chosen);
    preferences.result.complete(
      jsonEncode(const DeadlineCutoffWindow().toJson()),
    );
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
    testWidgets(
      'Cutoff settings explain every interval mode in ${locale.languageCode}',
      (tester) async {
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
          tester
              .widget<SwitchListTile>(
                find.byKey(const ValueKey('deadline-cutoff-enabled')),
              )
              .value,
          isFalse,
        );
        expect(find.byType(TimePickerDialog), findsNothing);
        expect(find.byType(TextField), findsNothing);
        expect(
          find.byKey(const ValueKey('deadline-cutoff-start')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('deadline-cutoff-end')),
          findsOneWidget,
        );
        await _expectSummary(
          tester,
          (l10n, material) => l10n.deadlineCutoffOvernight(
            _formattedTime(material, 22, 0),
            _formattedTime(material, 8, 0),
          ),
        );
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
        await _expectSummary(
          tester,
          (l10n, material) => l10n.deadlineCutoffSameDay(
            _formattedTime(material, 10, 0),
            _formattedTime(material, 12, 0),
          ),
        );
        await settings.setDeadlineCutoff(
          const DeadlineCutoffWindow(startMinute: 600, endMinute: 600),
        );
        await tester.pumpAndSettle();
        await _expectSummary(
          tester,
          (l10n, material) =>
              l10n.deadlineCutoffInstant(_formattedTime(material, 10, 0)),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'Time dials open on tap and cancel either endpoint without saving',
    (tester) async {
      final preferences = MemoryPreferences();
      final settings = _settings(preferences);
      addTearDown(settings.dispose);
      await settings.initialize();
      await _showCutoff(tester, settings);
      expect(find.byType(TimePickerDialog), findsNothing);
      expect(find.byType(TextField), findsNothing);
      for (final start in [true, false]) {
        await _selectEndpoint(tester, start: start);
        final picker = tester.widget<TimePickerDialog>(
          find.byType(TimePickerDialog),
        );
        final l10n = AppLocalizations.of(
          tester.element(find.byType(DeadlineCutoffScreen)),
        );
        expect(
          picker.helpText,
          start ? l10n.deadlineCutoffStart : l10n.deadlineCutoffEnd,
        );
        expect(picker.initialEntryMode, TimePickerEntryMode.dial);
        expect(
          find.byTooltip(
            MaterialLocalizations.of(
              tester.element(find.byType(TimePickerDialog)),
            ).inputTimeModeButtonLabel,
          ),
          findsOneWidget,
        );
        expect(picker.initialTime, TimeOfDay(hour: start ? 22 : 8, minute: 0));
        expect(find.byType(TextField), findsNothing);
        await _chooseTime(tester, 3, 45);
        expect(preferences.value(_key), isNull);
        await _pickerAction(tester, confirm: false);
        expect(find.byType(DeadlineCutoffScreen), findsOneWidget);
        expect(find.byType(TimePickerDialog), findsNothing);
        expect(settings.deadlineCutoff.value, const DeadlineCutoffWindow());
        expect(preferences.value(_key), isNull);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('A dial confirms only its endpoint using the latest settings', (
    tester,
  ) async {
    final preferences = MemoryPreferences();
    final settings = _settings(preferences);
    addTearDown(settings.dispose);
    await settings.initialize();
    await _showCutoff(tester, settings);
    await _selectEndpoint(tester, start: true);
    await _chooseTime(tester, 21, 15);
    final pickerElement = tester.element(find.byType(TimePickerDialog));
    await settings.setDeadlineCutoff(
      const DeadlineCutoffWindow(enabled: true, endMinute: 600),
    );
    await tester.pump();
    expect(tester.element(find.byType(TimePickerDialog)), same(pickerElement));
    await _pickerAction(tester, confirm: true);
    expect(settings.deadlineCutoff.value.startMinute, 21 * 60 + 15);
    expect(settings.deadlineCutoff.value.endMinute, 600);
    expect(settings.deadlineCutoff.value.enabled, isTrue);
    expect(
      jsonDecode(preferences.value(_key)!),
      settings.deadlineCutoff.value.toJson(),
    );
    expect(find.byType(DeadlineCutoffScreen), findsOneWidget);
    expect(find.byType(TimePickerDialog), findsNothing);
    expect(find.text('21:15'), findsOneWidget);

    await _selectEndpoint(tester, start: false);
    await _chooseTime(tester, 3, 45);
    await _pickerAction(tester, confirm: true);
    expect(settings.deadlineCutoff.value.startMinute, 21 * 60 + 15);
    expect(settings.deadlineCutoff.value.endMinute, 3 * 60 + 45);
    expect(settings.deadlineCutoff.value.enabled, isTrue);
    expect(
      jsonDecode(preferences.value(_key)!),
      settings.deadlineCutoff.value.toJson(),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final locale in [const Locale('zh'), const Locale('en')]) {
    testWidgets(
      'The dial fits a narrow screen with large text in ${locale.languageCode}',
      (tester) async {
        final settings = _settings(MemoryPreferences());
        addTearDown(settings.dispose);
        await settings.initialize();
        await _showCutoff(
          tester,
          settings,
          locale: locale,
          size: const Size(320, 640),
          scale: 1.8,
        );
        await _selectEndpoint(tester, start: false);
        expect(find.byType(TimePickerDialog), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        await _pickerAction(tester, confirm: false);
        expect(find.byType(DeadlineCutoffScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'Native picker actions never pop the surrounding settings route',
    (tester) async {
      final settings = _settings(MemoryPreferences());
      addTearDown(settings.dispose);
      await settings.initialize();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          theme: bitreeTheme(Brightness.light),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => DeadlineCutoffScreen(settings: settings),
                    ),
                  ),
                  child: const Text('打开设置'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开设置'));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsNothing);
      await _selectEndpoint(tester, start: true);
      await _pickerAction(tester, confirm: false);
      expect(find.byType(DeadlineCutoffScreen), findsOneWidget);
      expect(find.byType(TimePickerDialog), findsNothing);
      await _selectEndpoint(tester, start: false);
      await _pickerAction(tester, confirm: true);
      expect(find.byType(DeadlineCutoffScreen), findsOneWidget);
      expect(find.byType(TimePickerDialog), findsNothing);
      final back = find.byType(BackButton);
      await tester.ensureVisible(back);
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(find.byType(DeadlineCutoffScreen), findsNothing);
      expect(find.text('打开设置'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

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
