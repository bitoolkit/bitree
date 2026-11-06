import 'package:bitree/agenda/controller.dart';
import 'package:bitree/agenda/deadline_source.dart';
import 'package:bitree/agenda/model.dart';
import 'package:bitree/agenda/ui/agenda_operations.dart';
import 'package:bitree/automation/projection.dart';
import 'package:bitree/l10n/app_localizations_zh.dart';
import 'package:bitree/l10n/formats.dart';
import 'package:bitree/schedule/model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  final course = Course(
    id: 'course',
    name: '原课程',
    weekday: 1,
    startSection: 1,
    endSection: 2,
    weeks: [1],
  );
  final schedule = SemesterSchedule(
    term: '2026-2027-1',
    firstMonday: DateTime.utc(2026, 9, 7),
    courses: [course],
  );
  final old = AgendaEntry(
    id: 'old',
    title: '原作业',
    kind: AgendaKind.deadline,
    startsAt: DateTime.utc(2026, 9, 7, 12),
    source: DeadlineSource.lexue,
    course: '原课程',
    local: false,
  );
  final newer = AgendaEntry(
    id: 'new',
    title: '原作业',
    kind: AgendaKind.deadline,
    startsAt: old.startsAt,
    source: DeadlineSource.eclass,
    course: '原课程',
    local: false,
  );
  const script = '''
function filter(data)
    for _, course in ipairs(data.courses) do course.name = "简称" end
    local deadlines = {}
    for _, ddl in ipairs(data.deadlines) do
        if ddl.source ~= "lexue" then
            ddl.title = "展示作业"
            table.insert(deadlines, ddl)
        end
    end
    data.deadlines = deadlines
    return data
end
''';

  test(
    'projection keeps original identity and validates mutable field values',
    () {
      final input = AutomationProjection.snapshot([schedule], [old]);
      input['courses'][0]['weekday'] = 9;
      expect(
        () => AutomationProjection.fromResult(input, [schedule], [old]),
        throwsFormatException,
      );
      final changedIdentity = AutomationProjection.snapshot([schedule], [old]);
      changedIdentity['deadlines'][0]['done'] = true;
      expect(
        () =>
            AutomationProjection.fromResult(changedIdentity, [schedule], [old]),
        throwsFormatException,
      );
      final duplicate = AutomationProjection.snapshot([schedule], [old]);
      duplicate['courses'].add(duplicate['courses'][0]);
      expect(
        () => AutomationProjection.fromResult(duplicate, [schedule], [old]),
        throwsFormatException,
      );
    },
  );

  test('generated titles and notes honor explicit presentation overrides', () {
    final generated = AgendaEntry(
      id: 'physics',
      title: '原生成标题',
      kind: AgendaKind.deadline,
      startsAt: old.startsAt,
      term: schedule.term,
      details: PhysicsLabDeadlineDetails(
        kind: PhysicsLabDeadlineKind.preview,
        courseLabel: '力学实验',
        classStartsAt: old.startsAt,
        classEndsAt: old.startsAt.add(const Duration(hours: 2)),
      ),
    );
    final input = AutomationProjection.snapshot([schedule], [generated]);
    input['deadlines'][0]['title'] = '预习';
    input['deadlines'][0]['notes'] = '自定义备注';
    final projected = AutomationProjection.fromResult(
      input,
      [schedule],
      [generated],
    ).deadlines.values.single;
    expect(localizedAgendaTitle(AppLocalizationsZh(), projected), '预习');
    expect(localizedAgendaNotes(AppLocalizationsZh(), projected), '自定义备注');
    expect(projected.details, isA<PhysicsLabDeadlineDetails>());
  });

  test(
    'saved filters persist, apply to every term and leave originals intact',
    () async {
      final preferences = MemoryPreferences();
      final second = SemesterSchedule(
        term: '2025-2026-2',
        firstMonday: DateTime.utc(2026, 3, 2),
        courses: [course],
      );
      final controller = TestAppController(
        schedule: schedule,
        schedules: [second],
        entries: [old, newer],
        preferences: preferences,
      );
      await controller.initialize();
      await controller.automation.saveScript(script, fileName: 'rules.lua');
      expect(controller.automation.error, isNull);
      expect(controller.automation.schedule!.courses.single.name, '简称');
      expect(controller.automation.entries.single.title, '展示作业');
      expect(controller.automation.hiddenDeadlines, 1);
      expect(controller.timetable.schedule!.courses.single.name, '原课程');
      expect(controller.agenda.entries.map((entry) => entry.title), [
        '原作业',
        '原作业',
      ]);
      expect(
        controller.automation
            .pendingOn(old.startsAt, now: old.startsAt)
            .map((entry) => entry.id),
        ['new'],
      );
      await controller.timetable.setWeekRange(first: -2, last: 30);
      expect(controller.automation.schedule!.firstWeek, -2);
      expect(controller.automation.schedule!.lastWeek, 30);
      expect(controller.automation.schedule!.courses.single.name, '简称');
      await controller.timetable.selectTerm(
        second.term,
        importTerm: (_) async => false,
      );
      expect(controller.automation.schedule!.courses.single.name, '简称');

      final restarted = TestAppController(
        schedule: schedule,
        entries: [old, newer],
        preferences: preferences,
      );
      await restarted.initialize();
      expect(restarted.settings.developerMode, isFalse);
      expect(restarted.automation.enabled, isTrue);
      expect(restarted.automation.fileName, 'rules.lua');
      expect(restarted.automation.entries.single.title, '展示作业');
      await restarted.automation.setEnabled(false);
      expect(restarted.automation.schedule!.courses.single.name, '原课程');
      expect(restarted.automation.entries, hasLength(2));
    },
  );

  test(
    'completing a presentation row only changes the original done flag',
    () async {
      final store = MemoryAgendaStore([old, newer]);
      final controller = TestAppController(
        schedule: schedule,
        agenda: AgendaController(store),
      );
      await controller.initialize();
      await controller.automation.saveScript(script);
      final display = controller.automation.entries.single;
      expect(
        await toggleAgendaDone(controller.agenda, display, haptic: false),
        isTrue,
      );
      await controller.automation.settled;
      expect(store.entries.last.done, isTrue);
      expect(store.entries.last.title, '原作业');
      expect(store.entries.last.course, '原课程');
      expect(controller.automation.entries.single.done, isTrue);
      expect(controller.automation.entries.single.title, '展示作业');
    },
  );

  test(
    'bad scripts and invalid results atomically fall back, then recover',
    () async {
      final controller = TestAppController(
        schedule: schedule,
        entries: [old, newer],
      );
      await controller.initialize();
      await controller.automation.saveScript(script);
      expect(controller.automation.hiddenDeadlines, 1);
      await controller.automation.saveScript('''
function filter(data)
    data.courses[1].name = "半完成"
    data.deadlines[1].id = "unknown"
    return data
end
''');
      expect(controller.automation.error, isNotNull);
      expect(controller.automation.schedule!.courses.single.name, '原课程');
      expect(controller.automation.entries, hasLength(2));
      await controller.automation.saveScript(script);
      expect(controller.automation.error, isNull);
      expect(controller.automation.hiddenDeadlines, 1);
      await controller.agenda.save(newer.copyWith(done: true));
      await controller.automation.settled;
      expect(controller.automation.entries.single.done, isTrue);
    },
  );

  test('hidden rows and list removal both preserve ordinary events', () async {
    final event = AgendaEntry(
      id: 'event',
      title: '活动',
      kind: AgendaKind.event,
      startsAt: old.startsAt,
      endsAt: old.startsAt.add(const Duration(hours: 1)),
    );
    final controller = TestAppController(
      schedule: schedule,
      entries: [old, event],
    );
    await controller.initialize();
    await controller.automation.saveScript('''
function filter(data)
    data.courses[1].hidden = true
    data.deadlines = {}
    return data
end
''');
    expect(controller.automation.error, isNull);
    expect(controller.automation.schedule!.courses, isEmpty);
    expect(controller.automation.hiddenCourses, 1);
    expect(controller.automation.entries.single, same(event));
    expect(controller.agenda.entries, hasLength(2));
  });
}
