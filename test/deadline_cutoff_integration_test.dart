import 'dart:convert';

import 'package:bitree/agenda/calendar.dart';
import 'package:bitree/agenda/controller.dart';
import 'package:bitree/agenda/model.dart';
import 'package:bitree/agenda/ui/agenda_detail.dart';
import 'package:bitree/l10n/app_localizations_zh.dart';
import 'package:bitree/l10n/formats.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

const _window = DeadlineCutoffWindow(enabled: true);
final _real = DateTime.utc(2026, 11, 11, 7);
final _effective = DateTime.utc(2026, 11, 10, 22);
final _previousDay = DateTime.utc(2026, 11, 10);
final _realDay = DateTime.utc(2026, 11, 11);

AgendaEntry _deadline({
  String id = 'deadline',
  DateTime? startsAt,
  bool allDay = false,
  bool deleted = false,
}) => AgendaEntry(
  id: id,
  title: '测试作业 $id',
  kind: AgendaKind.deadline,
  startsAt: startsAt ?? _real,
  allDay: allDay,
  deleted: deleted,
);

class _RecordingAgendaStore extends MemoryAgendaStore {
  _RecordingAgendaStore(super.entries);

  int writes = 0;

  @override
  Future<void> write(List<AgendaEntry> entries) async {
    writes++;
    await super.write(entries);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('App settings immediately update projection without rewriting deadlines', () async {
    final raw = _deadline();
    final store = _RecordingAgendaStore([raw]);
    final agenda = AgendaController(store);
    final app = TestAppController(agenda: agenda);
    await app.initialize();
    var notifications = 0;
    agenda.addListener(() => notifications++);

    final writing = app.settings.setDeadlineCutoff(_window);
    // The ValueNotifier listener runs before asynchronous preference persistence.
    expect(agenda.entries.single.dueAt, _effective);
    expect(agenda.entries.single.realDueAt, _real);
    expect(agenda.entries.single.startsAt, _real);
    expect(notifications, 1);
    expect(store.writes, 0);
    expect(store.entries.single.startsAt, raw.startsAt);
    await writing;

    await app.settings.setDeadlineCutoff(_window);
    expect(notifications, 1);
    expect(store.writes, 0);
    await app.settings.setDeadlineCutoff(_window.copyWith(enabled: false));
    expect(agenda.entries.single.dueAt, _real);
    expect(agenda.entries.single.hasDeadlineCutoff, isFalse);
    expect(notifications, 2);
    expect(store.writes, 0);
  });

  test('Pending dates, ordering and calendar items use effective campus time', () async {
    final earlier = _deadline(
      id: 'earlier',
      startsAt: DateTime.utc(2026, 11, 10, 21),
    );
    final event = AgendaEntry(
      id: 'event',
      title: '晚间日程',
      kind: AgendaKind.event,
      startsAt: DateTime.utc(2026, 11, 10, 23),
      endsAt: DateTime.utc(2026, 11, 11),
    );
    final app = TestAppController(entries: [_deadline(), event, earlier]);
    await app.initialize();
    final now = DateTime.utc(2026, 11, 10, 20);
    expect(app.agenda.pendingOn(_realDay, now: now).map((e) => e.id), ['deadline']);
    await app.settings.setDeadlineCutoff(_window);

    final pending = app.agenda.pendingOn(_previousDay, now: now);
    expect(pending.map((entry) => entry.id), ['earlier', 'deadline', 'event']);
    expect(app.agenda.pendingOn(_realDay, now: now), isEmpty);
    final projected = pending.singleWhere((entry) => entry.id == 'deadline');
    expect(projected.occursOn(_previousDay), isTrue);
    expect(projected.occursOn(_realDay), isFalse);
    expect(projected.overdue(_effective), isFalse);
    expect(projected.overdue(_effective.add(const Duration(seconds: 1))), isTrue);
    expect(projected.realDueAt.isAfter(_effective), isTrue);

    final calendar = calendarItemsOn(_previousDay, null, app.agenda.entries);
    expect(calendar.map((item) => item.entry!.id), ['earlier', 'deadline', 'event']);
    expect(
      calendar.singleWhere((item) => item.entry!.id == 'deadline').startsAt,
      _effective,
    );
    expect(calendarItemsOn(_realDay, null, app.agenda.entries), isEmpty);
    await app.settings.setDeadlineCutoff(_window.copyWith(enabled: false));
    expect(app.agenda.entries.first.dueAt, _real);
    expect(
      calendarItemsOn(_realDay, null, app.agenda.entries).single.startsAt,
      _real,
    );
  });

  test('Changing and disabling settings reprojects entries and tombstones from raw data', () async {
    final store = _RecordingAgendaStore([
      _deadline(),
      _deadline(id: 'deleted', deleted: true),
    ]);
    final app = TestAppController(agenda: AgendaController(store));
    await app.initialize();
    await app.settings.setDeadlineCutoff(_window);
    expect(app.agenda.entries.single.dueAt, _effective);
    expect(app.agenda.deletedDeadlines.single.dueAt, _effective);
    const morning = DeadlineCutoffWindow(
      enabled: true,
      startMinute: 6 * 60,
      endMinute: 8 * 60,
    );
    await app.settings.setDeadlineCutoff(morning);
    final morningDue = DateTime.utc(2026, 11, 11, 6);
    expect(app.agenda.entries.single.dueAt, morningDue);
    expect(app.agenda.deletedDeadlines.single.dueAt, morningDue);
    await app.settings.setDeadlineCutoff(_window);
    expect(app.agenda.entries.single.dueAt, _effective);
    await app.settings.setDeadlineCutoff(_window.copyWith(enabled: false));
    expect(app.agenda.entries.single.dueAt, _real);
    expect(app.agenda.deletedDeadlines.single.dueAt, _real);
    expect(store.writes, 0);
    expect(store.entries.every((entry) => entry.startsAt == _real), isTrue);
  });

  test('Completion, deletion and restoration persist actual timestamps only', () async {
    final store = _RecordingAgendaStore([_deadline()]);
    final app = TestAppController(agenda: AgendaController(store));
    await app.initialize();
    await app.settings.setDeadlineCutoff(_window);

    final shown = app.agenda.entries.single;
    expect(await app.agenda.save(shown.copyWith(done: true)), isTrue);
    expect(app.agenda.entries.single.done, isTrue);
    expect(app.agenda.entries.single.dueAt, _effective);
    expect(app.agenda.entries.single.overdue(DateTime.utc(2030)), isFalse);
    expect(store.entries.single.startsAt, _real);
    expect(await app.agenda.delete(app.agenda.entries.single), isTrue);
    expect(app.agenda.entries, isEmpty);
    final deleted = app.agenda.deletedDeadlines.single;
    expect(deleted.dueAt, _effective);
    expect(deleted.deleted, isTrue);

    final savedJson = jsonDecode(jsonEncode(store.entries.single.toJson()))
        as Map<String, dynamic>;
    expect(savedJson['startsAt'], _real.toIso8601String());
    expect(savedJson['allDay'], isFalse);
    expect(savedJson['done'], isTrue);
    expect(savedJson['deleted'], isTrue);
    expect(savedJson.containsKey('deadlineCutoffWindow'), isFalse);
    expect(savedJson.containsKey('dueAt'), isFalse);
    final restoredFromDisk = AgendaEntry.fromJson(savedJson);
    expect(restoredFromDisk.dueAt, _real);
    expect(restoredFromDisk.deadlineCutoffWindow.enabled, isFalse);

    expect(await app.agenda.restore(deleted), isTrue);
    expect(app.agenda.deletedDeadlines, isEmpty);
    expect(app.agenda.entries.single.startsAt, _real);
    expect(app.agenda.entries.single.done, isTrue);
    await app.settings.setDeadlineCutoff(_window.copyWith(enabled: false));
    expect(app.agenda.entries.single.dueAt, _real);
  });

  test('All-day persistence retains the selected date and raw allDay flag', () async {
    final raw = _deadline(startsAt: _previousDay, allDay: true);
    final store = _RecordingAgendaStore([raw]);
    final app = TestAppController(agenda: AgendaController(store));
    await app.initialize();
    await app.settings.setDeadlineCutoff(_window);
    final shown = app.agenda.entries.single;
    expect(shown.realDueAt, _realDay);
    expect(shown.dueAt, _effective);
    expect(shown.scheduledAt, _effective);
    expect(shown.effectiveAllDay, isFalse);
    expect(shown.allDay, isTrue);
    expect(await app.agenda.save(shown.copyWith(done: true)), isTrue);
    final json = store.entries.single.toJson();
    expect(json['startsAt'], _previousDay.toIso8601String());
    expect(json['allDay'], isTrue);
    final disk = AgendaEntry.fromJson(json);
    expect(disk.scheduledAt, _previousDay);
    expect(disk.realDueAt, _realDay);
    expect(disk.effectiveAllDay, isTrue);
    await app.settings.setDeadlineCutoff(_window.copyWith(enabled: false));
    expect(app.agenda.entries.single.scheduledAt, _previousDay);
    expect(app.agenda.entries.single.dueAt, _realDay);
    expect(app.agenda.entries.single.effectiveAllDay, isTrue);
  });

  test('Saved settings project raw entries on initialization and reload', () async {
    final preferences = MemoryPreferences({
      'deadlineCutoff': jsonEncode(_window.toJson()),
    });
    final store = _RecordingAgendaStore([_deadline()]);
    final agenda = AgendaController(store);
    final app = TestAppController(agenda: agenda, preferences: preferences);
    await app.initialize();
    expect(agenda.entries.single.dueAt, _effective);
    expect(store.writes, 0);
    await agenda.load();
    expect(agenda.entries.single.dueAt, _effective);
    expect(agenda.entries.single.realDueAt, _real);
    expect(store.writes, 0);
    await app.settings.setDeadlineCutoff(_window.copyWith(enabled: false));

    final reopened = TestAppController(
      agenda: AgendaController(store),
      preferences: preferences,
    );
    await reopened.initialize();
    expect(reopened.settings.deadlineCutoff.value.enabled, isFalse);
    expect(reopened.agenda.entries.single.dueAt, _real);
    expect(reopened.agenda.entries.single.startsAt, _real);
  });

  testWidgets('The open detail sheet shows both effective and original deadlines', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = TestAppController(entries: [_deadline()]);
    await app.initialize();
    await app.settings.setDeadlineCutoff(_window);
    await tester.pumpWidget(MaterialApp(
      theme: bitreeTheme(Brightness.light),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showAgendaEntry(
                context,
                app,
                app.agenda.entries.single,
              ),
              child: const Text('打开详情'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('打开详情'));
    await tester.pumpAndSettle();
    final l10n = AppLocalizationsZh();
    expect(l10n.agendaAdjustedDeadline, '伪截止');
    expect(find.textContaining('伪截止时间', findRichText: true), findsNothing);
    expect(
      find.text('22:00  伪截止', findRichText: true),
      findsOneWidget,
    );
    final originalLabel = l10n.agendaCutoffOriginal(
      localizedAgendaDateTime(l10n, _real),
    );
    expect(find.text(originalLabel), findsOneWidget);
    await app.settings.setDeadlineCutoff(_window.copyWith(enabled: false));
    await tester.pumpAndSettle();
    expect(find.text(originalLabel), findsNothing);
    expect(
      find.text('07:00  ${l10n.due}', findRichText: true),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
