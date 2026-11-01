import 'dart:convert';
import 'dart:io';

import 'package:bitree/academics/model.dart';
import 'package:bitree/academics/store.dart';
import 'package:bitree/agenda/model.dart';
import 'package:bitree/agenda/store.dart';
import 'package:bitree/schedule/model.dart';
import 'package:bitree/schedule/store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Feature modules retain existing filenames and JSON formats across restarts', () async {
    final directory = await Directory.systemTemp.createTemp('bitree-storage-');
    addTearDown(() => directory.delete(recursive: true));
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => directory.path);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final semester = SemesterSchedule(
      term: '2026-2027-1',
      firstMonday: DateTime.utc(2026, 9, 21),
      firstWeek: -3,
      courses: const [],
    );
    final spring = SemesterSchedule(
      term: '2025-2026-2',
      firstMonday: DateTime.utc(2026, 2, 23),
      firstWeek: 1,
      lastWeek: 20,
      courses: const [],
    );
    await ScheduleStore().write((
      selectedTerm: semester.term,
      schedules: {semester.term: semester, spring.term: spring},
    ));
    final saved = await ScheduleStore().read();
    expect(saved.selectedTerm, semester.term);
    expect(saved.schedules[semester.term]!.firstWeek, -3);
    expect(saved.schedules[spring.term]!.lastWeek, 20);
    final scheduleJson = jsonDecode(
      await File('${directory.path}/schedule.json').readAsString(),
    ) as Map;
    expect(scheduleJson.keys, containsAll(['selectedTerm', 'semesters']));

    final deadline = AgendaEntry(
      id: 'lexue:one',
      title: '作业',
      kind: AgendaKind.deadline,
      startsAt: DateTime.utc(2026, 11, 1),
      done: true,
      deleted: true,
    );
    await AgendaStore().write([deadline]);
    final restored = (await AgendaStore().read()).single;
    expect(restored.id, deadline.id);
    expect(restored.done, isTrue);
    expect(restored.deleted, isTrue);

    final record = const AcademicRecord().withCreditTargets(
      total: 150,
      categories: {'必修': 90},
    );
    await AcademicStore().write('student', record);
    await AcademicStore().write(
      'another-student',
      const AcademicRecord(targetCredits: 120),
    );
    final academic = await AcademicStore().read('student');
    expect(academic.targetCredits, 150);
    expect(academic.categoryTargets, {'必修': 90});
    expect((await AcademicStore().read('another-student')).targetCredits, 120);
    expect(
      academic
          .withCreditTargets(total: null, categories: const {})
          .targetCredits,
      isNull,
    );
  });
}
