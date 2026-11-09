import 'package:bitree/agenda/deadline_source.dart';
import 'package:bitree/agenda/model.dart';
import 'package:bitree/sources/agenda_merge.dart';
import 'package:bitree/sources/course_selection.dart';
import 'package:bitree/sources/source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual platform courses survive discovery and keep their links', () {
    final selection = SourceCourseSelection(sourceInstanceId: 'instance:test');
    selection.mergeDiscovered([
      PlatformCourse(remoteId: '1', name: '自动课程'),
    ]);
    selection.addManual(
      PlatformCourse(remoteId: 'manual', name: '自行加入课程'),
    );
    selection.link(localCourseId: 'local-1', remoteId: 'manual');
    selection.setSelected('1', false);

    selection.mergeDiscovered([
      PlatformCourse(remoteId: '1', name: '自动课程（改名）'),
      PlatformCourse(remoteId: '2', name: '新课程'),
    ]);

    expect(selection.courses.map((course) => course.name), [
      '新课程',
      '自动课程（改名）',
      '自行加入课程',
    ]);
    expect(selection.course('1')!.selected, isFalse);
    expect(selection.course('manual')!.manual, isTrue);
    expect(selection.remoteIdsForLocal('local-1'), ['manual']);
  });

  test('a deadline title override keeps source timing and completion', () {
    final existing = AgendaEntry(
      id: 'saved',
      title: '用户标题',
      kind: AgendaKind.deadline,
      startsAt: DateTime.utc(2026, 11, 1, 23, 59),
      source: DeadlineSource.eclass,
      course: '离散数学',
      local: false,
      origin: RecordOrigin(
        sourceInstanceId: 'instance:account',
        resource: SourceResource.deadline,
        remoteId: '4381',
      ),
      overrides: const {'title'},
      sourceValues: const {
        'title': '原作业',
        'startsAt': '2026-11-01T23:59:00.000Z',
      },
    );
    final incoming = AgendaEntry(
      id: 'incoming',
      title: '原作业',
      kind: AgendaKind.deadline,
      startsAt: DateTime.utc(2026, 11, 8, 23, 59),
      source: DeadlineSource.eclass,
      course: '离散数学',
      local: false,
      origin: RecordOrigin(
        sourceInstanceId: 'instance:account',
        resource: SourceResource.deadline,
        remoteId: '4381',
      ),
    );

    final merged = mergeAgendaSource(
      existing: [existing],
      incoming: [incoming],
      sourceInstanceId: 'instance:account',
      resource: SourceResource.deadline,
    ).single;

    expect(merged.id, 'saved');
    expect(merged.title, '用户标题');
    expect(merged.startsAt, DateTime.utc(2026, 11, 8, 23, 59));
    expect(merged.done, isFalse);
    expect(merged.restoreSource().title, '原作业');
  });
}
