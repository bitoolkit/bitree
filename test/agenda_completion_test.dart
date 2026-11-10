import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bitree/academics/controller.dart';
import 'package:bitree/agenda/controller.dart';
import 'package:bitree/agenda/deadline_source.dart';
import 'package:bitree/agenda/model.dart';
import 'package:bitree/agenda/ui/agenda_list_tile.dart';
import 'package:bitree/agenda/ui/agenda_operations.dart';
import 'package:bitree/app/controller.dart';
import 'package:bitree/core/diagnostics.dart';
import 'package:bitree/l10n/app_localizations_zh.dart';
import 'package:bitree/l10n/formats.dart';
import 'package:bitree/school/service.dart';
import 'package:bitree/ui/swipe_action_tile.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_diagnostics_io.dart';
import 'support/test_app.dart';

final _now = DateTime.utc(2030, 1, 2, 12);

AgendaEntry _item({
  String id = 'item',
  AgendaKind kind = AgendaKind.event,
  DateTime? startsAt,
  DateTime? endsAt,
  bool done = false,
  bool handled = false,
  bool local = true,
  String title = '日程',
  String location = '原地点',
}) => AgendaEntry(
  id: id,
  title: title,
  kind: kind,
  startsAt: startsAt ?? _now.subtract(const Duration(hours: 2)),
  endsAt: kind == AgendaKind.deadline
      ? null
      : endsAt ?? _now.subtract(const Duration(hours: 1)),
  done: done,
  examAutoCompletionHandled: handled,
  local: local,
  term: 'term',
  location: location,
);

AgendaEntry _legacy(AgendaEntry entry) {
  final json = entry.toJson()
    ..remove('completionSchemaVersion')
    ..remove('examAutoCompletionHandled');
  return AgendaEntry.fromJson(json);
}

class _Store extends MemoryAgendaStore {
  _Store(super.entries);

  int writes = 0;
  bool fail = false;
  Completer<void>? started;
  Completer<void>? release;

  @override
  Future<void> write(List<AgendaEntry> entries) async {
    writes++;
    final waiting = release;
    if (waiting != null) {
      if (started?.isCompleted == false) started!.complete();
      await waiting.future;
    }
    if (fail) throw Exception('simulated agenda write failure');
    await super.write(entries);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  IOOverrides? previousIo;
  setUpAll(() async {
    final support = '${Directory.systemTemp.path}/bitree-completion-memory';
    previousIo = IOOverrides.current;
    // Install before priming the singleton: its cached Directory must also be
    // in memory, not a real Directory with IO tied to a retired FakeAsync zone.
    IOOverrides.global = MemoryDiagnosticsIo();
    messenger.setMockMethodCallHandler(pathProvider, (_) async => support);
    await AppDiagnostics.instance.recentLines();
  });
  tearDownAll(() async {
    try {
      await AppDiagnostics.instance.recentLines();
    } finally {
      messenger.setMockMethodCallHandler(pathProvider, null);
      IOOverrides.global = previousIo;
    }
  });

  test('Elapsed time and completion are independent for all kinds', () {
    for (final kind in AgendaKind.values) {
      final entry = _item(kind: kind, handled: kind == AgendaKind.exam);
      expect(entry.done, isFalse);
      expect(entry.isFinished(_now), isFalse);
      expect(entry.hasEnded(_now), isTrue);
      expect(entry.overdue(_now), isTrue);
      final complete = entry.copyWith(done: true);
      expect(complete.isFinished(_now), isTrue);
      expect(complete.overdue(_now), isFalse);
    }
    final awaitingAutomatic = _item(kind: AgendaKind.exam);
    expect(awaitingAutomatic.hasEnded(_now), isTrue);
    expect(awaitingAutomatic.overdue(_now), isFalse);
    final future = _item(endsAt: _now.add(const Duration(hours: 1)));
    expect(future.hasEnded(_now), isFalse);
    expect(future.overdue(_now), isFalse);
    expect(future.copyWith(done: true).isFinished(_now), isTrue);
    expect(future.copyWith(done: true).hasEnded(_now), isFalse);
    final open = AgendaEntry(
      id: 'open', title: '开放测验', kind: AgendaKind.deadline,
      startsAt: _now.subtract(const Duration(days: 30)), startOnly: true,
    );
    expect(open.hasEnded(_now), isFalse);
    expect(open.overdue(_now), isFalse);
  });

  test('Non-DDL overdue uses the end and never the cutoff window or start', () {
    const cutoff = DeadlineCutoffWindow(enabled: true);
    for (final kind in [AgendaKind.event, AgendaKind.exam]) {
      final entry = _item(
        kind: kind,
        handled: kind == AgendaKind.exam,
        startsAt: _now.subtract(const Duration(hours: 1)),
        endsAt: _now.add(const Duration(hours: 1)),
      ).withDeadlineCutoff(cutoff);
      expect(entry.hasDeadlineCutoff, isFalse);
      expect(entry.overdue(_now), isFalse);
      expect(entry.overdue(entry.endsAt!), isTrue);
    }
    final ddl = _item(kind: AgendaKind.deadline);
    expect(ddl.overdue(ddl.dueAt), isFalse);
  });

  test('Completion metadata round-trips and missing schema means legacy only', () {
    final entry = _item(kind: AgendaKind.exam).copyWith(
      done: false, examAutoCompletionHandled: true,
    );
    final restored = AgendaEntry.fromJson(
      jsonDecode(jsonEncode(entry.toJson())) as Map<String, dynamic>,
    );
    expect(restored.examAutoCompletionHandled, isTrue);
    expect(restored.completionSchemaVersion, AgendaEntry.currentCompletionSchemaVersion);
    expect(restored.done, isFalse);
    expect(restored.copyWith(deleted: true).examAutoCompletionHandled, isTrue);
    final legacy = _legacy(entry);
    expect(legacy.done, isFalse);
    expect(legacy.completionSchemaVersion, 0);
    expect(legacy.examAutoCompletionHandled, isFalse);
    expect(_item().completionSchemaVersion, AgendaEntry.currentCompletionSchemaVersion);
  });

  test('Old ended events migrate once, while new past events remain overdue', () async {
    final store = _Store([
      _legacy(_item(id: 'legacy')),
      _item(id: 'new'),
      _legacy(_item(id: 'future', endsAt: _now.add(const Duration(hours: 1)))),
    ]);
    final controller = AgendaController(store, now: () => _now);
    addTearDown(controller.dispose);
    await controller.load();
    expect(controller.entries.singleWhere((e) => e.id == 'legacy').done, isTrue);
    expect(controller.entries.singleWhere((e) => e.id == 'new').done, isFalse);
    expect(controller.entries.singleWhere((e) => e.id == 'future').done, isFalse);
    expect(store.writes, 1);
    expect(await controller.setDone('legacy', false), isTrue);
    expect(controller.entries.singleWhere((e) => e.id == 'legacy').overdue(_now), isTrue);
    await controller.reconcileExamCompletion(now: _now.add(const Duration(days: 1)));
    expect(controller.entries.every((e) => !e.done), isTrue);
    final reopened = AgendaController(store, now: () => _now.add(const Duration(days: 2)));
    addTearDown(reopened.dispose);
    await reopened.load();
    expect(reopened.entries.every((e) => !e.done), isTrue);
    expect(store.entries.every((e) => e.completionSchemaVersion == 1), isTrue);
  });

  test('Legacy exam completion is retained and ended exams get one opportunity', () async {
    final store = _Store([
      _legacy(_item(id: 'past', kind: AgendaKind.exam)),
      _legacy(_item(
        id: 'manual', kind: AgendaKind.exam, done: true,
        endsAt: _now.add(const Duration(hours: 1)),
      )),
    ]);
    final controller = AgendaController(store, now: () => _now);
    addTearDown(controller.dispose);
    await controller.load();
    expect(controller.entries.every((e) => e.done && e.examAutoCompletionHandled), isTrue);
    expect(store.writes, 1);
    await controller.reconcileExamCompletion();
    await controller.reconcileExamCompletion();
    expect(store.writes, 1);
    expect(await controller.setDone('past', false), isTrue);
    await controller.reconcileExamCompletion();
    final restarted = AgendaController(store, now: () => _now.add(const Duration(days: 2)));
    addTearDown(restarted.dispose);
    await restarted.load();
    final past = restarted.entries.singleWhere((e) => e.id == 'past');
    expect(past.done, isFalse);
    expect(past.examAutoCompletionHandled, isTrue);
    expect(past.overdue(_now), isTrue);
  });

  test('Manual choices before the end consume the future automatic opportunity', () async {
    var clock = _now;
    final store = _Store([_item(
      kind: AgendaKind.exam,
      endsAt: _now.add(const Duration(hours: 1)),
    )]);
    final controller = AgendaController(store, now: () => clock);
    addTearDown(controller.dispose);
    await controller.load();
    expect(await controller.setDone('item', true), isTrue);
    expect(await controller.setDone('item', false), isTrue);
    clock = _now.add(const Duration(hours: 2));
    await controller.reconcileExamCompletion();
    expect(controller.entries.single.done, isFalse);
    expect(controller.entries.single.examAutoCompletionHandled, isTrue);
    expect(controller.entries.single.overdue(clock), isTrue);
    expect(store.writes, 2);
  });

  test('Failed migration or auto-completion does not consume state', () async {
    final store = _Store([_legacy(_item(kind: AgendaKind.exam))])..fail = true;
    final controller = AgendaController(store, now: () => _now);
    addTearDown(controller.dispose);
    await controller.load();
    expect(controller.ready, isTrue);
    expect(controller.entries.single.done, isFalse);
    expect(controller.entries.single.examAutoCompletionHandled, isFalse);
    expect(controller.entries.single.completionSchemaVersion, 0);
    expect(store.entries.single.done, isFalse);
    expect(controller.entries.single.overdue(_now), isFalse);
    expect(
      await AppDiagnostics.instance.recentLines(),
      contains('simulated agenda write failure'),
    );
    expect(await controller.reconcileExamCompletion(), isFalse);
    store.fail = false;
    expect(await controller.reconcileExamCompletion(), isTrue);
    expect(controller.entries.single.done, isTrue);
    expect(controller.entries.single.examAutoCompletionHandled, isTrue);
    final writes = store.writes;
    await controller.reconcileExamCompletion();
    expect(store.writes, writes);
  });

  test('Manual write failure leaves completion untouched and can be retried', () async {
    final store = _Store([_item(kind: AgendaKind.exam)]);
    final controller = AgendaController(store, now: () => _now);
    addTearDown(controller.dispose);
    await controller.load();
    store.fail = true;
    expect(await controller.setDone('item', false), isFalse);
    expect(controller.entries.single.done, isTrue);
    store.fail = false;
    expect(await controller.setDone('item', false), isTrue);
    expect(controller.entries.single.done, isFalse);
    expect(controller.entries.single.examAutoCompletionHandled, isTrue);
  });

  test('A queued completion intent cannot be reversed by an automatic transition', () async {
    var clock = _now;
    final store = _Store([_item(
      kind: AgendaKind.exam,
      endsAt: _now.add(const Duration(hours: 1)),
    )]);
    final controller = AgendaController(store, now: () => clock);
    addTearDown(controller.dispose);
    await controller.load();
    final snapshot = controller.entries.single;
    store.started = Completer<void>();
    store.release = Completer<void>();
    clock = _now.add(const Duration(hours: 2));
    final automatic = controller.reconcileExamCompletion();
    await store.started!.future;
    final manual = toggleAgendaDone(controller, snapshot, haptic: false);
    store.release!.complete();
    expect(await automatic, isTrue);
    expect(await manual, isTrue);
    expect(controller.entries.single.done, isTrue);
    expect(store.writes, 1);
  });

  test('Completion actions resolve current metadata rather than stale snapshots', () async {
    final store = _Store([_item(kind: AgendaKind.exam, endsAt: _now.add(const Duration(hours: 1)))]);
    final controller = AgendaController(store, now: () => _now);
    addTearDown(controller.dispose);
    await controller.load();
    final snapshot = controller.entries.single;
    await controller.save(_item(
      kind: AgendaKind.exam, endsAt: _now.add(const Duration(hours: 2)),
      title: '更新的标题', location: '新地点',
    ));
    await toggleAgendaDone(controller, snapshot, haptic: false);
    expect(controller.entries.single.title, '更新的标题');
    expect(controller.entries.single.location, '新地点');
    expect(controller.entries.single.endsAt, _now.add(const Duration(hours: 2)));
    expect(controller.entries.single.done, isTrue);
    expect(controller.entries.single.local, isTrue);
  });

  for (final kind in [AgendaKind.event, AgendaKind.exam]) {
    test('Metadata edits retain newer completion choices for $kind', () async {
      for (final target in [false, true]) {
        final store = _Store([_item(
          kind: kind, done: !target, handled: true,
        )]);
        final controller = AgendaController(store, now: () => _now);
        addTearDown(controller.dispose);
        await controller.load();
        final snapshot = controller.entries.single;
        expect(snapshot.examAutoCompletionHandled, isTrue);
        await controller.setDone('item', target);
        final edited = _item(
          kind: kind, done: snapshot.done, handled: true,
          title: '编辑后的标题', location: '编辑后的地点',
        );
        expect(await controller.save(edited, preserveCompletion: true), isTrue);
        final saved = controller.entries.single;
        expect(saved.done, target);
        expect(saved.examAutoCompletionHandled, isTrue);
        expect(saved.completionSchemaVersion,
            AgendaEntry.currentCompletionSchemaVersion);
        expect(saved.title, '编辑后的标题');
        expect(saved.location, '编辑后的地点');
      }
    });

    test('Queued metadata edits read completion at execution time for $kind', () async {
      final store = _Store([_item(kind: kind, handled: true)]);
      final controller = AgendaController(store, now: () => _now);
      addTearDown(controller.dispose);
      await controller.load();
      final snapshot = controller.entries.single;
      store.started = Completer<void>();
      store.release = Completer<void>();
      final completing = controller.setDone('item', true);
      await store.started!.future;
      final editing = controller.save(_item(
        kind: kind, done: snapshot.done, handled: true,
        title: '排队中的编辑', location: '最新编辑地点',
      ), preserveCompletion: true);
      store.release!.complete();
      expect(await completing, isTrue);
      expect(await editing, isTrue);
      expect(controller.entries.single.done, isTrue);
      expect(controller.entries.single.examAutoCompletionHandled, isTrue);
      expect(controller.entries.single.title, '排队中的编辑');
      expect(controller.entries.single.location, '最新编辑地点');
    });

    test('Default save can still explicitly change completion for $kind', () async {
      final store = _Store([_item(kind: kind, handled: true)]);
      final controller = AgendaController(store, now: () => _now);
      addTearDown(controller.dispose);
      await controller.load();
      expect(await controller.save(controller.entries.single.copyWith(done: true)), isTrue);
      expect(controller.entries.single.done, isTrue);
    });
  }

  test('Metadata edits cannot restore legacy migration over a newer undo', () async {
    final store = _Store([_item(done: true)]);
    final controller = AgendaController(store, now: () => _now);
    addTearDown(controller.dispose);
    await controller.load();
    final snapshot = controller.entries.single;
    await controller.setDone('item', false);
    final oldEditor = snapshot.copyWith(completionSchemaVersion: 0);
    expect(await controller.save(oldEditor, preserveCompletion: true), isTrue);
    expect(controller.entries.single.done, isFalse);
    expect(controller.entries.single.completionSchemaVersion,
        AgendaEntry.currentCompletionSchemaVersion);
    await controller.load();
    expect(controller.entries.single.done, isFalse);
  });

  test('Same-id sync preserves completion but refreshes remote exam content', () async {
    var clock = _now;
    final store = _Store([_item(
      kind: AgendaKind.exam, local: false,
      endsAt: _now.add(const Duration(hours: 1)),
    )]);
    final controller = AgendaController(store, now: () => clock);
    addTearDown(controller.dispose);
    await controller.load();
    await controller.setDone('item', true);
    await controller.setDone('item', false);
    await controller.replaceExams('term', [_item(
      kind: AgendaKind.exam, local: false, title: '远端新标题', location: '新考场',
      endsAt: _now.add(const Duration(hours: 2)),
    )]);
    final current = controller.entries.single;
    expect(current.done, isFalse);
    expect(current.examAutoCompletionHandled, isTrue);
    expect(current.local, isFalse);
    expect(current.title, '远端新标题');
    expect(current.location, '新考场');
    clock = _now.add(const Duration(hours: 3));
    await controller.reconcileExamCompletion();
    expect(controller.entries.single.done, isFalse);
    // Saving an older editor snapshot without the marker cannot reset it.
    await controller.save(_item(kind: AgendaKind.exam, local: false));
    expect(controller.entries.single.done, isFalse);
    expect(controller.entries.single.examAutoCompletionHandled, isTrue);
    await controller.load();
    expect(controller.entries.single.done, isFalse);
  });

  test('Local content protection and distinct exam identities are not conflated', () async {
    final store = _Store([_item(kind: AgendaKind.exam, handled: true)]);
    final controller = AgendaController(store, now: () => _now);
    addTearDown(controller.dispose);
    await controller.load();
    await controller.replaceExams('term', [_item(
      kind: AgendaKind.exam, local: false, title: '应被本地内容保护挡住',
    )]);
    expect(controller.entries.single.title, '日程');
    expect(controller.entries.single.local, isTrue);
    final remoteStore = _Store([_item(kind: AgendaKind.exam, local: false, handled: true)]);
    final remote = AgendaController(remoteStore, now: () => _now);
    addTearDown(remote.dispose);
    await remote.load();
    await remote.replaceExams('term', [_item(
      id: 'new-id', kind: AgendaKind.exam, local: false,
      endsAt: _now.add(const Duration(hours: 1)),
    )]);
    expect(remote.entries.single.id, 'new-id');
    expect(remote.entries.single.examAutoCompletionHandled, isFalse);
  });

  test('Immediate deletion undo preserves a reopened exam opportunity marker', () async {
    final store = _Store([_item(kind: AgendaKind.exam)]);
    final controller = AgendaController(store, now: () => _now);
    addTearDown(controller.dispose);
    await controller.load();
    await controller.setDone('item', false);
    final reopened = controller.entries.single;
    expect(await controller.delete(reopened), isTrue);
    expect(controller.entries, isEmpty);
    expect(controller.deletedDeadlines, isEmpty);
    expect(await controller.restore(reopened), isTrue);
    await controller.reconcileExamCompletion();
    expect(controller.entries.single.done, isFalse);
    expect(controller.entries.single.examAutoCompletionHandled, isTrue);
    expect(controller.entries.single.overdue(_now), isTrue);
  });

  test('DDL synchronization still owns remote submission completion', () async {
    final raw = AgendaEntry(
      id: 'ddl', title: '平台作业', kind: AgendaKind.deadline,
      startsAt: _now, source: DeadlineSource.eclass, local: false,
    );
    final store = _Store([raw]);
    final controller = AgendaController(store, now: () => _now);
    addTearDown(controller.dispose);
    await controller.load();
    await controller.setDone('ddl', true);
    expect(controller.entries.single.done, isTrue);
    await controller.mergeDeadlines([raw]);
    expect(controller.entries.single.done, isFalse);
    expect(controller.entries.single.examAutoCompletionHandled, isFalse);
  });

  testWidgets('The foreground clock completes once at the nearest exam end', (tester) async {
    var clock = _now;
    final end = _now.add(const Duration(minutes: 1));
    final store = _Store([_item(kind: AgendaKind.exam, endsAt: end)]);
    final controller = AgendaController(store, now: () => clock);
    try {
      await controller.load();
      controller.setCompletionClockActive(true);
      await tester.pump();
      expect(controller.entries.single.done, isFalse);
      clock = end;
      await tester.pump(const Duration(minutes: 1));
      expect(controller.entries.single.done, isTrue);
      expect(controller.entries.single.examAutoCompletionHandled, isTrue);
      expect(store.writes, 1);
      await controller.setDone('item', false);
      clock = end.add(const Duration(days: 1));
      await tester.pump(const Duration(days: 1));
      expect(controller.entries.single.done, isFalse);
      expect(store.writes, 2);
    } finally {
      controller.dispose();
    }
  });

  testWidgets('Failed automatic writes retry with backoff, never a busy loop', (tester) async {
    var clock = _now;
    final end = _now.add(const Duration(minutes: 1));
    final store = _Store([_item(kind: AgendaKind.exam, endsAt: end)]);
    final controller = AgendaController(store, now: () => clock);
    try {
      await controller.load();
      controller.setCompletionClockActive(true);
      await tester.pump();
      store.fail = true;
      clock = end;
      await tester.pump(const Duration(minutes: 1));
      expect(store.writes, 1);
      expect(controller.entries.single.examAutoCompletionHandled, isFalse);
      expect(controller.entries.single.overdue(clock), isFalse);
      clock = end.add(const Duration(seconds: 29));
      await tester.pump(const Duration(seconds: 29));
      expect(store.writes, 1);
      store.fail = false;
      clock = end.add(const Duration(seconds: 30));
      await tester.pump(const Duration(seconds: 1));
      expect(store.writes, 2);
      expect(controller.entries.single.done, isTrue);
      expect(controller.entries.single.examAutoCompletionHandled, isTrue);
    } finally {
      controller.dispose();
    }
  });

  testWidgets('Production app lifecycle pauses, resumes and disposes its clock', (tester) async {
    var clock = _now;
    final store = _Store([_item(
      kind: AgendaKind.exam, endsAt: _now.add(const Duration(minutes: 1)),
    )]);
    final agenda = AgendaController(store, now: () => clock);
    final app = AppController(
      store: MemoryScheduleStore(), school: SchoolService(),
      schoolStorage: MemorySchoolStorage(), preferences: MemoryPreferences(),
      agenda: agenda, academics: AcademicController(MemoryAcademicStore()),
      moocStorage: MemoryMoocStorage(), coursePaletteLoader: () async => {},
    );
    try {
      expect(app.manageAgendaCompletionClock, isTrue);
      await app.initialize();
      await tester.pump();
      app.didChangeAppLifecycleState(AppLifecycleState.paused);
      clock = _now.add(const Duration(minutes: 2));
      await tester.pump(const Duration(minutes: 2));
      expect(agenda.entries.single.done, isFalse);
      app.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      expect(agenda.entries.single.done, isTrue);
      await agenda.setDone('item', false);
      app.didChangeAppLifecycleState(AppLifecycleState.paused);
      app.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      expect(agenda.entries.single.done, isFalse);
    } finally {
      app.dispose();
    }
    await tester.pump(const Duration(days: 1));
    expect(store.writes, 2);
    expect(tester.takeException(), isNull);
  });

  for (final kind in [AgendaKind.event, AgendaKind.exam]) {
    testWidgets('$kind list and detail both expose reversible completion', (tester) async {
      final raw = _item(kind: kind, handled: true);
      final agenda = AgendaController(_Store([raw]), now: () => _now);
      final app = TestAppController(agenda: agenda);
      await app.initialize();
      await tester.pumpWidget(MaterialApp(
        theme: bitreeTheme(Brightness.light),
        home: Scaffold(body: ListenableBuilder(
          listenable: agenda,
          builder: (context, _) => AgendaListTile(
            controller: app, entry: agenda.entries.single, now: _now,
          ),
        )),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(Checkbox), findsOneWidget);
      final tile = tester.widget<SwipeActionTile>(find.byType(SwipeActionTile));
      expect(tile.rightAction, isNotNull);
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(agenda.entries.single.done, isTrue);
      final l10n = AppLocalizationsZh();
      expect(localizedAgendaTimeCaption(l10n, agenda.entries.single, _now), l10n.completed);
      // CompletionText paints separate normal/strike-through text layers.
      // Activate the row rather than ambiguously matching both title widgets.
      await tester.tap(find.byType(AgendaListTile));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, l10n.agendaMarkUndone), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, l10n.agendaMarkUndone));
      await tester.pumpAndSettle();
      expect(agenda.entries.single.done, isFalse);
      expect(agenda.entries.single.overdue(_now), isTrue);
      expect(find.widgetWithText(FilledButton, l10n.agendaMarkDone), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
