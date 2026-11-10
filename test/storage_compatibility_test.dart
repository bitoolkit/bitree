import 'dart:convert';
import 'dart:io';

import 'package:bitree/academics/model.dart';
import 'package:bitree/academics/store.dart';
import 'package:bitree/agenda/agenda_color.dart';
import 'package:bitree/agenda/deadline_source.dart';
import 'package:bitree/agenda/model.dart';
import 'package:bitree/agenda/store.dart';
import 'package:bitree/core/storage/schema.dart';
import 'package:bitree/schedule/model.dart';
import 'package:bitree/schedule/store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Agenda details round-trip and older entries remain readable', () {
    final entries = [
      AgendaEntry(
        id: 'physics-lab:one',
        title: '干涉',
        kind: AgendaKind.deadline,
        startsAt: DateTime.utc(2026, 11, 2),
        term: '2026-2027-1',
        local: false,
        color: AgendaColor.blue,
        details: PhysicsLabDeadlineDetails(
          kind: PhysicsLabDeadlineKind.preview,
          courseLabel: '干涉',
          classStartsAt: DateTime.utc(2026, 10, 27, 8),
          classEndsAt: DateTime.utc(2026, 10, 27, 9, 35),
        ),
      ),
      AgendaEntry(
        id: 'mooc:review',
        title: '期末考试',
        kind: AgendaKind.deadline,
        startsAt: DateTime.utc(2026, 11, 5),
        source: DeadlineSource.mooc,
        local: false,
        details: MoocDeadlineDetails(
          kind: MoocDeadlineKind.peerReview,
          spoc: true,
          releaseAt: DateTime.utc(2026, 11, 3),
          submissionDueAt: DateTime.utc(2026, 11, 2),
        ),
      ),
      AgendaEntry(
        id: 'exam:math',
        title: '高等数学',
        kind: AgendaKind.exam,
        startsAt: DateTime.utc(2026, 12, 28, 9),
        endsAt: DateTime.utc(2026, 12, 28, 11),
        local: false,
        details: const ExamAgendaDetails(
          seat: '12',
          mode: '闭卷',
          teacher: '张老师',
        ),
      ),
    ];

    final restored = [
      for (final entry in entries)
        AgendaEntry.fromJson(
          jsonDecode(jsonEncode(entry.toJson())) as Map<String, dynamic>,
        ),
    ];
    expect(
      restored[0].details,
      isA<PhysicsLabDeadlineDetails>()
          .having(
            (details) => details.kind,
            'kind',
            PhysicsLabDeadlineKind.preview,
          )
          .having((details) => details.courseLabel, 'courseLabel', '干涉'),
    );
    expect(restored[0].color, AgendaColor.blue);
    expect(restored[0].color!.id, 'blue');
    expect(restored[0].copyWith(done: true).color, AgendaColor.blue);
    final customColor = AgendaEntry(
      id: 'custom-color',
      title: '自定义颜色',
      kind: AgendaKind.event,
      startsAt: DateTime.utc(2026, 11, 2, 9),
      endsAt: DateTime.utc(2026, 11, 2, 10),
      color: const AgendaColor(0xFF3366CC),
    );
    final restoredCustom = AgendaEntry.fromJson(customColor.toJson());
    expect(restoredCustom.color, const AgendaColor(0xFF3366CC));
    expect(restoredCustom.color!.id, isNull);
    final presetValue = AgendaEntry.fromJson(
      Map<String, dynamic>.from(entries[0].toJson())..['color'] = 0xFF1A5998,
    );
    expect(presetValue.color, AgendaColor.blue);
    expect(presetValue.color!.id, 'blue');
    final legacyColor = Map<String, dynamic>.from(entries[0].toJson())
      ..['color'] = 'blue';
    expect(AgendaEntry.fromJson(legacyColor).color, AgendaColor.blue);
    expect(
      restored[1].details,
      isA<MoocDeadlineDetails>()
          .having(
            (details) => details.kind,
            'kind',
            MoocDeadlineKind.peerReview,
          )
          .having((details) => details.spoc, 'spoc', isTrue),
    );
    expect(
      restored[2].details,
      isA<ExamAgendaDetails>()
          .having((details) => details.seat, 'seat', '12')
          .having((details) => details.teacher, 'teacher', '张老师'),
    );

    final legacy = Map<String, dynamic>.from(entries[2].toJson())
      ..remove('details');
    expect(AgendaEntry.fromJson(legacy).details, isNull);
  });

  test('Feature modules retain filenames and migrate storage formats across restarts', () async {
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
    expect(scheduleJson['schemaVersion'], currentStorageSchemaVersion);
    expect(scheduleJson.keys, containsAll(['selectedTerm', 'semesters']));

    final deadline = AgendaEntry(
      id: 'lexue:one',
      title: '作业',
      kind: AgendaKind.deadline,
      startsAt: DateTime.utc(2026, 11, 1),
      done: true,
      deleted: true,
      tailDays: 14,
    );
    await AgendaStore().write([deadline]);
    final agendaJson = jsonDecode(
      await File('${directory.path}/agenda.json').readAsString(),
    ) as Map;
    expect(agendaJson['schemaVersion'], currentStorageSchemaVersion);
    expect(agendaJson['entries'], isA<List>());
    final restored = (await AgendaStore().readAndMigrate()).single;
    expect(restored.id, deadline.id);
    expect(restored.done, isTrue);
    expect(restored.deleted, isTrue);
    expect(restored.tailDays, 14);
    expect(restored.copyWith(done: false, deleted: false).tailDays, 14);
    final legacy = deadline.toJson()..remove('tailDays');
    expect(AgendaEntry.fromJson(legacy).tailDays, AgendaEntry.defaultTailDays);
    for (final invalid in [0, -1, 31, 1.5, '7']) {
      expect(
        () => AgendaEntry.fromJson({...legacy, 'tailDays': invalid}),
        throwsFormatException,
      );
    }

    final record = const AcademicRecord().withCreditTargets(
      total: 150,
      categories: {'必修': 90},
    );
    await AcademicStore().write('student', record);
    await AcademicStore().write(
      'another-student',
      const AcademicRecord(targetCredits: 120),
    );
    final academicsJson = jsonDecode(
      await File('${directory.path}/academics.json').readAsString(),
    ) as Map;
    expect(academicsJson['schemaVersion'], currentStorageSchemaVersion);
    expect(academicsJson['accounts'], isA<Map>());
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
    final plan = StudyPlan(
      major: '计算机科学与技术',
      year: '2024',
      requiredCredits: 150,
      completedCredits: 30,
    );
    final withPlan = academic.copyWith(
      plan: plan,
      planUpdatedAt: DateTime.utc(2026, 11, 9),
    );
    expect(withPlan.plan, plan);
    expect(withPlan.copyWith(plan: null).plan, isNull);
    expect(withPlan.copyWith(planUpdatedAt: null).planUpdatedAt, isNull);
    expect(withPlan.copyWith(targetCredits: null).targetCredits, isNull);

    await File('${directory.path}/schedule.json').writeAsString(
      await File('test/fixtures/legacy/v0.2.0/schedule.json').readAsString(),
    );
    final legacySchedule = await ScheduleStore().read();
    expect(legacySchedule.selectedTerm, '2026-2027-1');
    expect(
      legacySchedule.schedules['2026-2027-1']!.courses.single.name,
      '旧版课程',
    );

    await File('${directory.path}/agenda.json').writeAsString(
      await File('test/fixtures/legacy/v0.2.0/agenda.json').readAsString(),
    );
    final legacyAgenda = await AgendaStore().readAndMigrate();
    expect(legacyAgenda.single.title, '旧版日程');
    expect(legacyAgenda.single.color, isNull);
    final migratedAgenda = jsonDecode(
      await File('${directory.path}/agenda.json').readAsString(),
    ) as Map;
    expect(migratedAgenda['schemaVersion'], currentStorageSchemaVersion);
    expect(migratedAgenda['entries'], [legacyAgenda.single.toJson()]);
    expect(
      (await AgendaStore().readAndMigrate()).single.id,
      legacyAgenda.single.id,
    );

    await File('${directory.path}/academics.json').writeAsString(
      await File('test/fixtures/legacy/v0.3.0/academics.json').readAsString(),
    );
    final legacyAcademic = await AcademicStore().read('student');
    expect(legacyAcademic.targetCredits, 150);
    expect(legacyAcademic.categoryTargets, {'必修': 90});

    await File('${directory.path}/schedule.json').writeAsString(
      jsonEncode({
        'selectedTerm': semester.term,
        'semesters': {semester.term: semester.toJson()},
      }),
    );
    expect((await ScheduleStore().read()).selectedTerm, semester.term);

    await File('${directory.path}/agenda.json')
        .writeAsString(jsonEncode([deadline.toJson()]));
    expect((await AgendaStore().readAndMigrate()).single.id, deadline.id);
    expect(
      jsonDecode(await File('${directory.path}/agenda.json').readAsString()),
      {
        'schemaVersion': currentStorageSchemaVersion,
        'entries': [deadline.toJson()],
      },
    );

    await File('${directory.path}/academics.json')
        .writeAsString(jsonEncode({'student': record.toJson()}));
    expect((await AcademicStore().read('student')).targetCredits, 150);

    await File('${directory.path}/schedule.json').writeAsString(
      jsonEncode({
        'schemaVersion': currentStorageSchemaVersion + 1,
        'selectedTerm': null,
        'semesters': <String, Object>{},
      }),
    );
    await expectLater(ScheduleStore().read(), throwsFormatException);
  });
}
