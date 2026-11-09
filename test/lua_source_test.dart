import 'package:bitree/extensions/lua_source.dart';
import 'package:bitree/sources/runtime.dart';
import 'package:bitree/sources/source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Lua source dispatches an operation with query and context', () async {
    final module = LuaSourceModule.parse('''
return {
  operations = {
    ["courses.list"] = function(ctx, query)
      return {
        items = {
          { remoteId = "42", name = ctx.config.name .. ":" .. query.term }
        },
        mode = "replace"
      }
    end
  }
}
''');

    final result = await module.callOperation(
      SourceOperation.coursesList,
      SourceOperationContext(config: {'name': '测试'}),
      {'term': '2026-2'},
    );

    expect(result, {
      'items': [
        {'remoteId': '42', 'name': '测试:2026-2'},
      ],
      'mode': 'replace',
    });
  });

  test('Lua source can call a base operation and mutate its result', () async {
    Object? receivedQuery;
    final module = LuaSourceModule.parse('''
return {
  operations = {
    ["deadlines.read"] = function(ctx, query)
      local result = ctx.base.call("deadlines.read", query)
      result.items[1].title = result.items[1].title .. "（已修复）"
      return result
    end
  }
}
''');

    final result = await module.callOperation(
      SourceOperation.deadlinesRead,
      SourceOperationContext(
        baseOperations: {
          'deadlines.read': (query) {
            receivedQuery = query;
            return {
              'items': [
                {'remoteId': '1', 'title': '作业'},
              ],
            };
          },
        },
      ),
      {
        'course': {'remoteId': '1'},
      },
    ) as Map;

    expect(receivedQuery, {
      'course': {'remoteId': '1'},
    });
    expect((result['items'] as List).single['title'], '作业（已修复）');
  });

  test(
    'Lua source exposes original base steps and validates overrides',
    () async {
      final module = LuaSourceModule.parse('''
return {
  operations = {
    ["deadlines.read"] = function(ctx, query)
      return ctx.base.steps.activityRows(ctx, { activities = { 1, 2 } })
    end
  },
  steps = {
    activityRows = function(ctx, body)
      return { body.activities[2] }
    end
  }
}
''');
      module.validateSteps({'activityRows'});

      final result = await module.callOperation(
        SourceOperation.deadlinesRead,
        SourceOperationContext(
          baseSteps: {
            'activityRows': (args) {
              final body = args[1] as Map;
              return body['activities'];
            },
          },
        ),
      );

      expect(result, [1, 2]);
      expect(
        () => LuaSourceModule.parse('''
return {
  operations = {
    ["deadlines.read"] = function(ctx, query)
      return {}
    end
  },
  steps = { missingStep = function() return {} end }
}
''').validateSteps({'activityRows'}),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test('Lua source preserves null and empty JSON containers', () async {
    final module = LuaSourceModule.parse('''
local json = require("bitree.json")
return {
  operations = {
    ["agenda.read"] = function(ctx, query)
      return {
        items = {
          { id = "emptyArray", value = json.array() },
          { id = "emptyObject", value = json.object({}) },
          { id = "nullValue", value = json.null }
        },
        mode = "upsert"
      }
    end
  }
}
''');

    final result = await module.callOperation(
      SourceOperation.agendaRead,
      SourceOperationContext(),
    ) as Map;
    final items = result['items'] as List;

    expect(items[0]['value'], isEmpty);
    expect(items[1]['value'], isEmpty);
    expect(items[2]['value'], same(SourceJsonNull.instance));
  });

  test('Lua string methods support Lua-style multiple returns', () async {
    final module = LuaSourceModule.parse('''
return {
  operations = {
    ["agenda.read"] = function(ctx, query)
      local first, last = string.find("abc-def", "-", 1, true)
      local replaced, count = string.gsub("a-b-c", "-", "_")
      return { first = first, last = last, replaced = replaced, count = count }
    end
  }
}
''');

    final result = await module.callOperation(
      SourceOperation.agendaRead,
      SourceOperationContext(),
    );
    expect(result, {'first': 4, 'last': 4, 'replaced': 'a_b_c', 'count': 2});
  });

  test('host utilities delegate URL, encoding and time conversions', () async {
    final module = LuaSourceModule.parse('''
local time = require("bitree.time")
local url = require("bitree.url")
local encoding = require("bitree.encoding")
return {
  operations = {
    ["agenda.read"] = function(ctx, query)
      return {
        dueDate = time.addDays("2026-11-09", 6),
        dueAt = time.localDateTime("2026-11-15", "23:59"),
        resolved = url.resolve("https://example.com/a/b", "../c"),
        query = url.encodeQuery({ term = "2026-2" }),
        encoded = encoding.base64Encode("hello"),
        decoded = encoding.base64Decode("5L2g5aW9"),
        roundTrip = encoding.utf8Decode(encoding.utf8Encode("中文")),
      }
    end
  }
}
''');

    final result = await module.callOperation(
      SourceOperation.agendaRead,
      SourceOperationContext(),
    );

    expect(result, {
      'dueDate': '2026-11-15',
      'dueAt': '2026-11-15T23:59:00+08:00',
      'resolved': 'https://example.com/c',
      'query': 'term=2026-2',
      'encoded': 'aGVsbG8=',
      'decoded': [0xE4, 0xBD, 0xA0, 0xE5, 0xA5, 0xBD],
      'roundTrip': '中文',
    });
  });

  test('Lua source resumes after an async HTTP handler', () async {
    final module = LuaSourceModule.parse('''
return {
  operations = {
    ["agenda.read"] = function(ctx, query)
      local response = ctx.http.request({
        method = "GET",
        url = "https://example.com/data.json"
      })
      return {
        status = response.status,
        value = response.json().value,
      }
    end
  }
}
''');
    Map<String, Object?>? received;

    final result = await module.callOperation(
      SourceOperation.agendaRead,
      SourceOperationContext(
        httpRequest: (request) async {
          received = request;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          return {
            'status': 200,
            'headers': {'content-type': 'application/json'},
            'body': '{"value":"ok"}',
          };
        },
      ),
    );

    expect(received, {'method': 'GET', 'url': 'https://example.com/data.json'});
    expect(result, {'status': 200, 'value': 'ok'});
  });

  test('base steps still run inside a resumed Lua call', () async {
    final module = LuaSourceModule.parse('''
return {
  operations = {
    ["agenda.read"] = function(ctx, query)
      ctx.http.request({ url = "https://example.com/check" })
      local rows = ctx.base.steps.activityRows(ctx, { activity = "quiz" })
      return { title = rows[1].title }
    end
  }
}
''');
    final context = SourceOperationContext(
      httpRequest: (request) async => {
        'status': 200,
        'headers': {'content-type': 'application/json'},
        'body': '{"ok":true}',
      },
      baseSteps: {
        'activityRows': (args) {
          final body = args[1] as Map;
          return [
            {'title': '步骤 ${body['activity']}'},
          ];
        },
      },
    );

    final result = await module.callOperation(
      SourceOperation.agendaRead,
      context,
    );

    expect(result, {'title': '步骤 quiz'});
  });

  test('host time conversion rejects calendar overflow', () async {
    final module = LuaSourceModule.parse('''
local time = require("bitree.time")
return {
  operations = {
    ["agenda.read"] = function(ctx, query)
      return time.localDateTime("2026-02-31", "23:59")
    end
  }
}
''');

    await expectLater(
      module.callOperation(
        SourceOperation.agendaRead,
        SourceOperationContext(),
      ),
      throwsA(
        isA<SourceError>().having(
          (error) => error.code,
          'code',
          'invalid_time',
        ),
      ),
    );
  });
}
