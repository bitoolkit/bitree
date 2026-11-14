import 'package:bitree/automation/native_lua.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final library = NativeLuaLibrary.open();

  test('C Lua filters JSON data with standard string semantics', () {
    final result = library.executeFilter(
      source: '''
function filter(data)
    data.courses[1].name = string.gsub(data.courses[1].name, "-", "_")
    data.events[1].title = _VERSION
    return data
end
''',
      data: {
        'courses': [
          {'name': 'a-b-c'},
        ],
        'deadlines': [],
        'events': [
          {'title': 'event'},
        ],
        'exams': [],
      },
    ) as Map;
    expect(result['courses'][0]['name'], 'a_b_c');
    expect(result['events'][0]['title'], 'Lua 5.5');
    expect(result['deadlines'], isEmpty);
    expect(result['exams'], isEmpty);
  });

  test('filter has no module, host, filesystem or code-loading APIs', () {
    final result = library.executeFilter(
      source: '''
assert(require == nil and package == nil)
assert(io == nil and os == nil and debug == nil)
assert(load == nil and loadfile == nil and dofile == nil)
assert(coroutine == nil and string.dump == nil)
assert(__bitree_host_call == nil and __bitree_make_context == nil)
assert(__bitree_json_encode == nil and __bitree_json_decode == nil)
function filter(data) return data end
''',
      data: {'courses': [], 'deadlines': [], 'events': [], 'exams': []},
    );
    expect(result, isA<Map>());
  });

  test('error text survives the FFI boundary without JSON escaping', () {
    const message = '错误："引号"、反斜杠\\与换行\n下一行';
    expect(
      () => library.executeFilter(
        source: 'function filter(data) error(data.message, 0) end',
        data: {'message': message},
      ),
      throwsA(
        isA<NativeLuaError>()
            .having((error) => error.code, 'code', 'script_error')
            .having((error) => error.message, 'message', message),
      ),
    );
  });

  test('C Lua enforces its memory limit and recovers on the next call', () {
    expect(
      () => library.executeFilter(
        source: '''
function filter(data)
    data.value = string.rep("x", 40 * 1024 * 1024)
    return data
end
''',
        data: {},
      ),
      throwsA(
        isA<NativeLuaError>().having(
          (error) => error.code,
          'code',
          'memory_limit',
        ),
      ),
    );
    expect(
      library.executeFilter(
        source: 'function filter(data) return data end',
        data: {'ok': true},
      ),
      {'ok': true},
    );
  });

  test('C Lua interrupts infinite loops', () {
    expect(
      () => library.executeFilter(
        source: 'function filter(data) while true do end end',
        data: {},
        timeoutMs: 100,
      ),
      throwsA(
        isA<NativeLuaError>().having((error) => error.code, 'code', 'timeout'),
      ),
    );
  });

  test('C Lua observes cancellation', () {
    final cancellation = NativeLuaCancellation();
    addTearDown(cancellation.dispose);
    cancellation.cancel();
    expect(
      () => library.executeFilter(
        source: 'function filter(data) while true do end end',
        data: {},
        cancellation: cancellation,
      ),
      throwsA(
        isA<NativeLuaError>().having(
          (error) => error.code,
          'code',
          'cancelled',
        ),
      ),
    );
  });

  test('each call starts with a fresh Lua state', () {
    const script = '''
count = (count or 0) + 1
function filter(data)
    data.count = count
    return data
end
''';
    for (var index = 0; index < 2; index++) {
      expect(library.executeFilter(source: script, data: {}), {'count': 1});
    }
  });
}
