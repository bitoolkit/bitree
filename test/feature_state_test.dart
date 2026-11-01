import 'dart:async';

import 'package:bitree/academics/controller.dart';
import 'package:bitree/academics/model.dart';
import 'package:bitree/agenda/controller.dart';
import 'package:bitree/agenda/model.dart';
import 'package:bitree/schedule/controller.dart';
import 'package:bitree/schedule/model.dart';
import 'package:bitree/schedule/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

class _DelayedAcademicStore extends MemoryAcademicStore {
  final started = Completer<void>();
  final old = Completer<AcademicRecord>();
  @override
  Future<AcademicRecord> read(String account) {
    if (account != 'old') return super.read(account);
    started.complete();
    return old.future;
  }
}

class _SlowScheduleStore extends MemoryScheduleStore {
  _SlowScheduleStore({required super.selected});

  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> write(ScheduleLibrary library) async {
    if (!started.isCompleted) {
      started.complete();
      await release.future;
    }
    await super.write(library);
  }
}

AgendaEntry deadline(
  String id, {
  String title = '作业',
  bool local = false,
  bool done = false,
}) => AgendaEntry(
  id: id,
  title: title,
  kind: AgendaKind.deadline,
  startsAt: DateTime.utc(2026, 11, 1),
  local: local,
  done: done,
);

void main() {
  test('Switching academic accounts cannot publish or save the previous account record', () async {
    final store = _DelayedAcademicStore();
    store.accounts['new'] = const AcademicRecord(targetCredits: 150);
    final controller = AcademicController(store);
    addTearDown(controller.dispose);
    final old = controller.load('old');
    await store.started.future;
    final latest = controller.load('new');
    store.old.complete(const AcademicRecord(targetCredits: 100));
    await Future.wait([old, latest]);
    expect(controller.record.targetCredits, 150);
    expect(
      await controller.save(
        controller.record.withCreditTargets(total: 160, categories: const {}),
      ),
      isTrue,
    );
    expect(store.accounts['new']!.targetCredits, 160);
    expect(store.accounts.containsKey('old'), isFalse);
  });

  final semester = SemesterSchedule(
    term: '2026-2027-1',
    firstMonday: DateTime.utc(2026, 9, 21),
    firstWeek: -3,
    courses: const [],
  );

  test(
    'Feature changes do not fan out through app appearance and startup state',
    () async {
      final app = TestAppController(schedule: semester);
      await app.initialize();
      var notifications = 0;
      app.addListener(() => notifications++);
      app.timetable.selectWeek(8);
      await app.agenda.save(deadline('one'));
      await app.school.loadAccount();
      expect(app.timetable.week, 8);
      expect(app.agenda.entries.single.id, 'one');
      expect(notifications, 0);
      await app.setTheme(ThemeMode.dark);
      expect(app.themeMode, ThemeMode.dark);
      expect(notifications, 1);
    },
  );

  test(
    'Week range changes clamp selection and persist through reloading',
    () async {
      final store = MemoryScheduleStore(selected: semester);
      final controller = TimetableController(store);
      addTearDown(controller.dispose);
      await controller.load();
      controller.selectWeek(25);
      expect(await controller.setWeekRange(first: -2, last: 20), isTrue);
      expect(controller.week, 20);
      final reloaded = TimetableController(store);
      addTearDown(reloaded.dispose);
      await reloaded.load();
      expect(reloaded.weeks.first, -2);
      expect(reloaded.weeks.last, 20);
      await controller.clear();
      expect(controller.schedule, isNull);
      expect((await store.read()).schedules, isEmpty);
    },
  );

  test('Import preserves locally edited and added courses', () async {
    final edited = Course(
      id: 'school',
      name: '本地修改',
      weekday: 1,
      startSection: 1,
      endSection: 2,
      weeks: [1],
      local: true,
    );
    final manual = Course(
      id: 'manual',
      name: '手动课程',
      weekday: 2,
      startSection: 3,
      endSection: 4,
      weeks: [1],
      local: true,
    );
    final remote = Course(
      id: 'school',
      name: '学校课程',
      weekday: 1,
      startSection: 1,
      endSection: 2,
      weeks: [1],
    );
    final store = MemoryScheduleStore(
      selected: semester.copyWith(courses: [edited, manual]),
    );
    final controller = TimetableController(store);
    addTearDown(controller.dispose);
    await controller.load();
    expect(
      await controller.importSchedule(semester.copyWith(courses: [remote]), [
        semester.term,
      ]),
      isTrue,
    );
    expect(
      controller.schedule!.courses.map((course) => course.name),
      containsAll(['本地修改', '手动课程']),
    );
    expect(controller.schedule!.courses, hasLength(2));
    expect(
      (await store.read()).schedules[semester.term]!.courses,
      hasLength(2),
    );
  });

  test(
    'A course edit queues behind an import instead of being dropped',
    () async {
      final store = _SlowScheduleStore(selected: semester);
      final controller = TimetableController(store);
      addTearDown(controller.dispose);
      await controller.load();
      final remote = Course(
        id: 'remote',
        name: '学校课程',
        weekday: 1,
        startSection: 1,
        endSection: 2,
        weeks: [1],
      );
      final local = Course(
        id: 'local',
        name: '手动课程',
        weekday: 2,
        startSection: 3,
        endSection: 4,
        weeks: [1],
        local: true,
      );

      final imported = controller.importSchedule(
        semester.copyWith(courses: [remote]),
        [semester.term],
      );
      await store.started.future;
      final saved = controller.saveCourse(local);
      store.release.complete();

      expect(await imported, isTrue);
      expect(await saved, isTrue);
      expect(
        controller.schedule!.courses.map((course) => course.id),
        containsAll(['remote', 'local']),
      );
    },
  );

  test('Changing week during a save keeps the newer selection', () async {
    final store = _SlowScheduleStore(selected: semester);
    final controller = TimetableController(store);
    addTearDown(controller.dispose);
    await controller.load();
    controller.selectWeek(8);

    final saving = controller.saveCourse(
      Course(
        id: 'local',
        name: '手动课程',
        weekday: 2,
        startSection: 3,
        endSection: 4,
        weeks: [1],
        local: true,
      ),
    );
    await store.started.future;
    controller.selectWeek(9);
    store.release.complete();

    expect(await saving, isTrue);
    expect(controller.week, 9);
  });

  test(
    'Selecting a term reuses saved data or imports it without deadlock',
    () async {
      final spring = SemesterSchedule(
        term: '2025-2026-2',
        firstMonday: DateTime.utc(2026, 2, 23),
        courses: const [],
      );
      final store = MemoryScheduleStore(
        schedules: [semester, spring],
        selected: semester,
      );
      final controller = TimetableController(store);
      addTearDown(controller.dispose);
      await controller.load();

      var imports = 0;
      expect(
        await controller.selectTerm(
          spring.term,
          importTerm: (_) async {
            imports++;
            return false;
          },
        ),
        isTrue,
      );
      expect(imports, 0);
      expect(controller.schedule?.term, spring.term);

      final summer = SemesterSchedule(
        term: '2025-2026-3',
        firstMonday: DateTime.utc(2026, 7, 6),
        courses: const [],
      );
      expect(
        await controller.selectTerm(
          summer.term,
          importTerm: (term) {
            imports++;
            return controller.importSchedule(summer, [term]);
          },
        ),
        isTrue,
      );
      expect(imports, 1);
      expect(controller.schedule?.term, summer.term);
      expect(store.schedules.keys, containsAll([spring.term, summer.term]));
    },
  );

  test('DDL sync preserves deletions and local edits while following remote completion', () async {
    final store = MemoryAgendaStore([
      deadline('deleted'),
      deadline('edited', title: '本地标题', local: true),
      deadline('finished', done: true),
    ]);
    final agenda = AgendaController(store);
    addTearDown(agenda.dispose);
    await agenda.load();
    await agenda.delete(agenda.entries.first);
    await agenda.mergeDeadlines([
      deadline('deleted'),
      deadline('edited', done: true),
      deadline('finished'),
      deadline('new'),
    ]);
    expect(agenda.entries.map((entry) => entry.id), [
      'edited',
      'finished',
      'new',
    ]);
    expect(agenda.entries.first.title, '本地标题');
    expect(agenda.entries.first.done, isTrue);
    expect(agenda.entries.elementAt(1).done, isFalse);
    expect(agenda.deletedDeadlines.single.id, 'deleted');
    final restarted = AgendaController(store);
    addTearDown(restarted.dispose);
    await restarted.load();
    expect(restarted.deletedDeadlines.single.id, 'deleted');
    await restarted.restoreDeletedDeadlines();
    expect(restarted.entries, hasLength(4));
  });
}
