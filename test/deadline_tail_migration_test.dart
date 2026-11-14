import 'dart:async';

import 'package:bitree/agenda/controller.dart';
import 'package:bitree/agenda/model.dart';
import 'package:bitree/app/ui/settings_screen.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

final _date = DateTime.utc(2030, 1, 2, 12);

AgendaEntry _deadline(
  String id,
  int? tailDays, {
  bool deleted = false,
  bool startOnly = false,
}) => AgendaEntry(
  id: id,
  title: id,
  kind: AgendaKind.deadline,
  startsAt: _date,
  notes: 'keep notes',
  done: true,
  deleted: deleted,
  startOnly: startOnly,
  tailDays: tailDays,
);

class _MigrationStore extends MemoryAgendaStore {
  _MigrationStore(super.entries);

  int writes = 0;
  bool fail = false;
  Completer<void>? release;

  @override
  Future<void> write(List<AgendaEntry> entries) async {
    writes++;
    if (release case final pending?) await pending.future;
    if (fail) throw Exception('simulated write failure');
    await super.write(entries);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Manual migration only resets four-day DDL tails in one serialized write',
    () async {
      final original = [
        _deadline('plain', 4),
        _deadline('open', 4, startOnly: true),
        _deadline('recycled', 4, deleted: true),
        _deadline('custom', 14),
        _deadline('inherited', null),
        AgendaEntry(
          id: 'event',
          title: 'event',
          kind: AgendaKind.event,
          startsAt: _date,
          endsAt: _date.add(const Duration(hours: 1)),
          tailDays: 4,
        ),
      ];
      final store = _MigrationStore(original);
      final controller = AgendaController(store);
      addTearDown(controller.dispose);
      await controller.load();
      // Merely loading never migrates an existing four-day value.
      expect(controller.entries.first.tailDays, 4);
      expect(store.writes, 0);

      expect(
        await Future.wait([
          controller.resetDefaultDeadlineTails(),
          controller.resetDefaultDeadlineTails(),
        ]),
        [3, 0],
      );
      expect(store.writes, 1);
      for (var i = 0; i < original.length; i++) {
        final before = original[i];
        final expected = before.toJson();
        if (before.isDeadline && before.tailDays == 4) {
          expected['tailDays'] = null;
        }
        expect(store.entries[i].toJson(), expected);
      }
      expect(controller.deletedDeadlines.single.tailDays, isNull);
      expect(controller.deletedDeadlines.single.deleted, isTrue);

      final restarted = AgendaController(store);
      addTearDown(restarted.dispose);
      await restarted.load();
      expect(
        restarted.entries.singleWhere((e) => e.id == 'plain').tailDays,
        isNull,
      );
      expect(
        restarted.entries.singleWhere((e) => e.id == 'custom').tailDays,
        14,
      );
      expect(await restarted.resetDefaultDeadlineTails(), 0);
      expect(store.writes, 1);
    },
  );

  test(
    'A failed migration keeps the original state and can be retried',
    () async {
      final store = _MigrationStore([_deadline('plain', 4)]);
      final errors = <Object>[];
      final controller = AgendaController(
        store,
        reportError: (_, error, _) => errors.add(error),
      );
      addTearDown(controller.dispose);
      await controller.load();
      store.fail = true;
      expect(await controller.resetDefaultDeadlineTails(), isNull);
      expect(errors, hasLength(1));
      expect(controller.entries.single.tailDays, 4);
      expect(store.entries.single.tailDays, 4);
      expect(controller.busy, isFalse);
      store.fail = false;
      expect(await controller.resetDefaultDeadlineTails(), 1);
      expect(controller.entries.single.tailDays, isNull);
      expect(store.entries.single.tailDays, isNull);
    },
  );

  testWidgets(
    'The migration button appears only in developer mode and reports the saved count',
    (tester) async {
      final store = _MigrationStore([
        _deadline('plain', 4),
        _deadline('custom', 14),
      ]);
      final agenda = AgendaController(store);
      final app = TestAppController(agenda: agenda);
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
      final button = find.byKey(const ValueKey('reset-default-deadline-tails'));
      expect(button, findsNothing);
      app.settings.unlockDeveloperMode();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        button,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('开发者选项'), findsOneWidget);
      expect(tester.widget<ListTile>(button).onTap, isNotNull);

      final release = Completer<void>();
      store.release = release;
      await tester.tap(button);
      await tester.pump();
      expect(tester.widget<ListTile>(button).onTap, isNull);
      release.complete();
      await tester.pumpAndSettle();
      expect(store.entries.first.tailDays, isNull);
      expect(store.entries.last.tailDays, 14);
      expect(find.text('已将 1 个 DDL 改为跟随全局设置。'), findsOneWidget);
      expect(tester.widget<ListTile>(button).onTap, isNotNull);

      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('已将 0 个 DDL 改为跟随全局设置。'), findsOneWidget);
      expect(store.writes, 1);
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
