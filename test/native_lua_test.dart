import 'dart:async';

import 'package:bitree/extensions/native_lua.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final library = NativeLuaLibrary.open();

  test('native C Lua executes a source operation', () async {
    final result = await library.executeAsync(
      source: '''
local time = require("bitree.time")
return {
  operations = {
    ["agenda.read"] = function(ctx, query)
      local title = string.gsub("a-b-c", "-", "_")
      return {
        title = title,
        dueAt = time.localDateTime("2026-11-09", "23:59"),
        empty = require("bitree.json").array(),
        nullValue = require("bitree.json").null
      }
    end
  }
}
''',
      fileName: 'native-test.lua',
      operation: 'agenda.read',
      query: const {},
      context: const {'locale': 'zh'},
      host: (engine, kind, name, arguments) =>
          kind == 'time.localDateTime' ? '2026-11-09T23:59:00+08:00' : null,
      onYield: (engine, request) =>
          throw StateError('unexpected async host call'),
    ) as Map<String, dynamic>;

    expect(result['title'], 'a_b_c');
    expect(result['dueAt'], '2026-11-09T23:59:00+08:00');
    expect(result['empty'], isEmpty);
  });

  test('native C Lua suspends and resumes for an async host request', () async {
    Map<String, Object?>? received;
    final result = await library.executeAsync(
      source: '''
return {
  operations = {
    ["agenda.read"] = function(ctx, query)
      local response = ctx.http.request({
        method = "GET",
        url = "https://example.com/data.json"
      })
      local payload = response.json()
      return {
        status = response.status,
        text = response.text(),
        ok = payload.ok
      }
    end
  }
}
''',
      fileName: 'native-async-test.lua',
      operation: 'agenda.read',
      query: const {},
      context: const {'locale': 'zh'},
      host: (engine, kind, name, arguments) => null,
      onYield: (engine, request) async {
        received = request;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return {
          'status': 200,
          'url': 'https://example.com/data.json',
          'headers': {'content-type': 'application/json'},
          'body': '{"ok":true}',
        };
      },
    ) as Map<String, dynamic>;

    expect(received?['kind'], 'http.request');
    expect((received?['args'] as List).single, {
      'method': 'GET',
      'url': 'https://example.com/data.json',
    });
    expect(result, {'status': 200, 'text': '{"ok":true}', 'ok': true});
  });

  test('native C Lua can suspend more than once in one operation', () async {
    final urls = <String>[];
    final result = await library.executeAsync(
      source: '''
return {
  operations = {
    ["agenda.read"] = function(ctx, query)
      local first = ctx.http.request({ url = "https://example.com/1" })
      local second = ctx.http.request({ url = "https://example.com/2" })
      return {
        first = first.json().value,
        second = second.json().value
      }
    end
  }
}
''',
      fileName: 'native-async-multiple.lua',
      operation: 'agenda.read',
      query: const {},
      context: const {},
      host: (engine, kind, name, arguments) => null,
      onYield: (engine, request) async {
        final args = request['args'] as List;
        final url = (args.single as Map)['url'] as String;
        urls.add(url);
        final value = url.endsWith('/1') ? 1 : 2;
        return {
          'status': 200,
          'headers': {'content-type': 'application/json'},
          'body': '{"value":$value}',
        };
      },
    ) as Map<String, dynamic>;

    expect(urls, ['https://example.com/1', 'https://example.com/2']);
    expect(result, {'first': 1, 'second': 2});
  });

  test('native C Lua times out while an async host call is pending', () async {
    final pending = Completer<Object?>();

    await expectLater(
      library.executeAsync(
        source: '''
return {
  operations = {
    ["agenda.read"] = function(ctx, query)
      ctx.http.request({ url = "https://example.com/slow" })
      return {}
    end
  }
}
''',
        fileName: 'native-async-timeout.lua',
        operation: 'agenda.read',
        query: const {},
        context: const {},
        host: (engine, kind, name, arguments) => null,
        onYield: (engine, request) => pending.future,
        timeoutMs: 100,
      ),
      throwsA(
        isA<NativeLuaError>().having((error) => error.code, 'code', 'timeout'),
      ),
    );
  });

  test('native C Lua stops after an async wait when cancelled', () async {
    final cancellation = NativeLuaCancellation();
    addTearDown(cancellation.dispose);
    Timer(const Duration(milliseconds: 20), cancellation.cancel);

    await expectLater(
      library.executeAsync(
        source: '''
return {
  operations = {
    ["agenda.read"] = function(ctx, query)
      ctx.http.request({ url = "https://example.com/cancel" })
      return {}
    end
  }
}
''',
        fileName: 'native-async-cancel.lua',
        operation: 'agenda.read',
        query: const {},
        context: const {},
        host: (engine, kind, name, arguments) => null,
        cancellation: cancellation,
        onYield: (engine, request) async {
          await Future<void>.delayed(const Duration(milliseconds: 80));
          return {
            'status': 200,
            'headers': const <String, Object?>{},
            'body': '',
          };
        },
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

  test('native C Lua enforces its memory limit', () async {
    await expectLater(
      library.executeAsync(
        source: '''
return {
  operations = {
    ["agenda.read"] = function(ctx, query)
      return string.rep("x", 40 * 1024 * 1024)
    end
  }
}
''',
        fileName: 'native-memory.lua',
        operation: 'agenda.read',
        query: const {},
        context: const {},
        host: (engine, kind, name, arguments) => null,
        onYield: (engine, request) =>
            throw StateError('unexpected async host call'),
      ),
      throwsA(
        isA<NativeLuaError>().having(
          (error) => error.code,
          'code',
          'memory_limit',
        ),
      ),
    );
  });

  test('native C Lua enforces its instruction budget', () async {
    await expectLater(
      library.executeAsync(
        source: '''
return {
  operations = {
    ["agenda.read"] = function(ctx, query)
      while true do end
    end
  }
}
''',
        fileName: 'native-loop.lua',
        operation: 'agenda.read',
        query: const {},
        context: const {},
        host: (engine, kind, name, arguments) => null,
        onYield: (engine, request) =>
            throw StateError('unexpected async host call'),
        timeoutMs: 200,
      ),
      throwsA(
        isA<NativeLuaError>().having((error) => error.code, 'code', 'timeout'),
      ),
    );
  });
}
