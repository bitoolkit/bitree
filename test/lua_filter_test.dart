import 'dart:async';

import 'package:bitree/automation/example.dart';
import 'package:bitree/automation/lua_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> data() => {
    'courses': [
      {
        'id': 'course',
        'term': 'term',
        'name': '某个非常长的课程名称',
        'weeks': [1, 2],
      },
    ],
    'events': <Map<String, dynamic>>[],
    'exams': <Map<String, dynamic>>[],
    'deadlines': [
      {'id': 'old', 'course': '某门课程', 'source': 'lexue', 'done': false},
      {'id': 'new', 'course': '某个非常长的课程名称', 'source': 'eclass', 'done': true},
    ],
  };

  test(
    'the documented filter renames and removes rows without mutating input',
    () async {
      final input = data();
      final result = await LuaFilterExecutor().run(automationExample, input);
      expect((result['courses'] as List).single['name'], '简称');
      expect((result['courses'] as List).single['weeks'], [1, 2]);
      expect(result['deadlines'], [
        {'id': 'new', 'course': '简称', 'source': 'eclass', 'done': true},
      ]);
      expect(input['courses'][0]['name'], '某个非常长的课程名称');
      expect(input['deadlines'], hasLength(2));
    },
  );

  test(
    'a batch filter can retain old tasks until a new-platform match exists',
    () async {
      final result = await LuaFilterExecutor().run(
        '''
function filter(data)
    local current = {}
    for _, ddl in ipairs(data.deadlines) do
        if ddl.source == "eclass" then current[ddl.course] = true end
    end
    local result = {}
    for _, ddl in ipairs(data.deadlines) do
        if ddl.source ~= "lexue" or not current[ddl.course] then
            table.insert(result, ddl)
        end
    end
    data.deadlines = result
    return data
end
''',
        {
          'courses': [],
          'deadlines': [
            {'id': 'old-a', 'course': 'A', 'source': 'lexue'},
            {'id': 'new-a', 'course': 'A', 'source': 'eclass'},
            {'id': 'old-b', 'course': 'B', 'source': 'lexue'},
          ],
        },
      );
      expect((result['deadlines'] as List).map((row) => row['id']), [
        'new-a',
        'old-b',
      ]);
    },
  );

  test('empty arrays survive table conversion', () async {
    final result = await LuaFilterExecutor().run(
      'function filter(data) return data end',
      {'courses': [], 'deadlines': []},
    );
    expect(result, {'courses': [], 'deadlines': [], 'events': [], 'exams': []});
  });

  test(
    'events and exams support transforms and legacy output preserves them',
    () async {
      final input = {
        ...data(),
        'events': [
          {'id': 'event', 'title': '活动'},
        ],
        'exams': [
          {'id': 'exam', 'title': '考试'},
        ],
      };
      final executor = LuaFilterExecutor();
      final changed = await executor.run('''
function filter(data)
    data.events[1].title = tostring(12) .. type("x")
    data.exams[1].hidden = true
    return data
end
''', input);
      expect(changed['events'][0]['title'], '12string');
      expect(changed['exams'][0]['hidden'], isTrue);
      final legacy = await executor.run('''
function filter(data)
    return {courses = data.courses, deadlines = data.deadlines}
end
''', input);
      expect(legacy['events'], input['events']);
      expect(legacy['exams'], input['exams']);
    },
  );

  for (final script in [
    'function filter(data)',
    'function transform(data) return data end',
    'function filter(data) return nil end',
    'function filter(data) return {} end',
    'function filter(data) data.courses[3] = data.courses[1] return data end',
    'function filter(data) data.courses[1].name = data return data end',
    'function filter(data) return missing(data) end',
    'function filter(data) string.gsub("x", "x", "y") return data end',
    'function filter(data) require("/etc/passwd") return data end',
    'function filter(data) io.open("/etc/passwd") return data end',
  ]) {
    test('invalid or unavailable operations fail: $script', () async {
      await expectLater(
        LuaFilterExecutor().run(script, data()),
        throwsA(isA<Exception>()),
      );
    });
  }

  test('timeout kills a busy worker and the executor can be reused', () async {
    final executor = LuaFilterExecutor(
      timeout: const Duration(milliseconds: 200),
    );
    await expectLater(
      executor.run('function filter(data) while true do end end', data()),
      throwsA(isA<TimeoutException>()),
    );
    expect(
      await executor.run('function filter(data) return data end', data()),
      isA<Map>(),
    );
  });

  test('superseding a run cancels its worker', () async {
    final executor = LuaFilterExecutor();
    final first = executor.run('while true do end', data());
    final cancelled = expectLater(first, throwsA(isA<LuaFilterCancelled>()));
    final second = executor.run(
      'function filter(data) return data end',
      data(),
    );
    await cancelled;
    expect(await second, isA<Map>());
  });
}
