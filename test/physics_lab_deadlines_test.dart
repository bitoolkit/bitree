import 'package:bitree/agenda/controller.dart';
import 'package:bitree/agenda/physics_lab_deadlines.dart';
import 'package:bitree/l10n/app_localizations_en.dart';
import 'package:bitree/l10n/app_localizations_zh.dart';
import 'package:bitree/schedule/model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

SemesterSchedule _schedule() => SemesterSchedule(
  term: '2026-2027-1',
  firstMonday: DateTime.utc(2026, 10, 26),
  firstWeek: 1,
  lastWeek: 2,
  courses: [
    Course(
      id: 'physics-lab-course',
      name: '干涉 实验课程',
      room: '物理实验中心201',
      weekday: 2,
      startSection: 1,
      endSection: 2,
      weeks: [1, 2],
    ),
  ],
);

void main() {
  final zh = AppLocalizationsZh();

  test(
    'Only newly imported past-due physics deadlines start completed',
    () async {
      final schedule = _schedule();
      final generated = physicsLabDeadlines(schedule, zh);
      final now = generated.first.dueAt.add(const Duration(minutes: 1));
      final store = MemoryAgendaStore();
      final agenda = AgendaController(store);
      addTearDown(agenda.dispose);
      await agenda.load();

      expect(
        await agenda.updatePhysicsLabDeadlines(schedule, l10n: zh, now: now),
        4,
      );
      expect(agenda.entries.where((entry) => entry.done), hasLength(1));
      expect(agenda.entries.where((entry) => !entry.done), hasLength(3));
      expect(agenda.entries.first.id, generated.first.id);
      expect(agenda.entries.first.done, isTrue);
      expect(store.entries.first.done, isTrue);
    },
  );

  test('A new deadline exactly at its due time is not yet past due', () async {
    final schedule = _schedule();
    final now = physicsLabDeadlines(schedule, zh).first.dueAt;
    final agenda = AgendaController(MemoryAgendaStore());
    addTearDown(agenda.dispose);
    await agenda.load();

    expect(
      await agenda.updatePhysicsLabDeadlines(schedule, l10n: zh, now: now),
      4,
    );
    expect(agenda.entries.every((entry) => !entry.done), isTrue);
  });

  test(
    'Existing completion states never change during repeated imports',
    () async {
      final schedule = _schedule();
      final generated = physicsLabDeadlines(schedule, zh);
      final store = MemoryAgendaStore([
        generated[0].copyWith(done: false),
        generated[1].copyWith(done: true),
      ]);
      final agenda = AgendaController(store);
      addTearDown(agenda.dispose);
      await agenda.load();
      final now = generated.first.dueAt.add(const Duration(days: 1));

      expect(
        await agenda.updatePhysicsLabDeadlines(schedule, l10n: zh, now: now),
        4,
      );
      final flags = {for (final entry in agenda.entries) entry.id: entry.done};
      expect(flags[generated[0].id], isFalse);
      expect(flags[generated[1].id], isTrue);

      final later = generated.last.dueAt.add(const Duration(days: 1));
      expect(
        await agenda.updatePhysicsLabDeadlines(schedule, l10n: zh, now: later),
        4,
      );
      expect({for (final entry in agenda.entries) entry.id: entry.done}, flags);
      expect({for (final entry in store.entries) entry.id: entry.done}, flags);
      expect(agenda.entries, hasLength(4));
    },
  );

  test(
    'An existing deleted deadline keeps its completion and deletion flags',
    () async {
      final schedule = _schedule();
      final generated = physicsLabDeadlines(schedule, zh);
      final agenda = AgendaController(
        MemoryAgendaStore([
          generated.first.copyWith(done: false, deleted: true),
        ]),
      );
      addTearDown(agenda.dispose);
      await agenda.load();

      final now = generated.last.dueAt.add(const Duration(days: 1));
      expect(
        await agenda.updatePhysicsLabDeadlines(schedule, l10n: zh, now: now),
        4,
      );
      expect(agenda.deletedDeadlines.single.id, generated.first.id);
      expect(agenda.deletedDeadlines.single.done, isFalse);
      expect(agenda.entries, hasLength(3));
      expect(agenda.entries.every((entry) => entry.done), isTrue);
    },
  );

  test('Generated copy follows the selected language', () {
    final entries = physicsLabDeadlines(_schedule(), AppLocalizationsEn());

    expect(entries.first.title, 'Pre-lab report 干涉');
    expect(
      entries.first.notes,
      'Generated from the Fall 2026–2027 schedule\nClass: 2026-10-27 08:00–09:35',
    );
  });
}
