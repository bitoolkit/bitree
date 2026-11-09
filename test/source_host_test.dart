import 'package:bitree/extensions/lua_source.dart';
import 'package:bitree/sources/builtin.dart';
import 'package:bitree/sources/host.dart';
import 'package:bitree/sources/registry.dart';
import 'package:bitree/sources/runtime.dart';
import 'package:bitree/sources/source.dart';
import 'package:bitree/sources/transport.dart';
import 'package:flutter_test/flutter_test.dart';

class _CallbackRuntime implements SourceRuntime {
  _CallbackRuntime(this.callback);

  final Future<Object?> Function(
    SourceDefinition definition,
    SourceOperation operation,
    Map<String, Object?> query,
    SourceOperationContext context,
  )
  callback;

  @override
  Future<Object?> call(
    SourceDefinition definition,
    SourceOperation operation,
    Map<String, Object?> query,
    SourceOperationContext context,
  ) => callback(definition, operation, query, context);
}

class _FakeTransport extends SourceHttpTransport {
  Map<String, Object?>? received;

  @override
  Future<Map<String, Object?>> request(
    String instanceId,
    SourcePermissions permissions,
    Map<String, Object?> request, {
    bool Function()? isCancelled,
  }) async {
    received = request;
    return {
      'status': 200,
      'url': 'https://example.com/data.json',
      'headers': {'content-type': 'application/json'},
      'body': '{"title":"来自 HTTP"}',
    };
  }
}

SourceDefinition definition({required SourcePermissions permissions}) =>
    SourceDefinition(
      id: 'test.http-source',
      packageId: 'test.package',
      sourceId: 'http-source',
      name: LocalizedSourceName(const {'zh': '网络来源', 'en': 'HTTP source'}),
      entry: 'main.lua',
      operations: const {SourceOperation.agendaRead},
      permissions: permissions,
    );

const source = '''
return {
  operations = {
    ["agenda.read"] = function(ctx, query)
      local response = ctx.http.request({
        url = "https://example.com/data.json"
      })
      return {
        items = {
          {
            remoteId = "1",
            title = response.json().title,
            kind = "deadline",
            dueDate = "2026-11-09"
          }
        }
      }
    end
  }
}
''';

void main() {
  test(
    'source host delegates built-in operations to the host runtime',
    () async {
      final registry = SourceRegistry(catalog: SourceCatalog.builtin());
      final instance = registry.ensureInstance(BuiltinSources.eclass);
      final calls = <SourceOperation>[];
      SourceOperationContext? received;
      final host = SourceHost(
        registry: registry,
        runtimeFor: (definition) async =>
            _CallbackRuntime((definition, operation, query, context) async {
              calls.add(operation);
              received = context;
              return [
                {
                  'remoteId': '20759',
                  'name': '大学物理AⅡ',
                  'url': 'https://zy-eclass.bit.edu.cn/course/20759',
                },
              ];
            }),
      );

      final result = await host.courses(instance);

      expect(calls, [SourceOperation.coursesList]);
      expect(result.items.single.remoteId, '20759');
      expect(result.items.single.name, '大学物理AⅡ');
      expect(received?.source['baseId'], BuiltinSources.eclass);
      expect(received?.source['instanceId'], instance.id);
    },
  );

  test('source host rejects a disabled built-in instance', () async {
    final registry = SourceRegistry(catalog: SourceCatalog.builtin());
    final instance = registry.ensureInstance(BuiltinSources.eclass);
    final disabled = instance.copyWith(enabled: false);
    final host = SourceHost(
      registry: registry,
      runtimeFor: (definition) async => _CallbackRuntime(
        (definition, operation, query, context) async => const [],
      ),
    );

    await expectLater(
      host.courses(disabled),
      throwsA(
        isA<SourceError>().having(
          (error) => error.code,
          'code',
          'source_disabled',
        ),
      ),
    );
  });

  test('source host forbids HTTP without a network permission', () async {
    final sourceDefinition = definition(permissions: SourcePermissions());
    final registry = SourceRegistry(catalog: SourceCatalog([sourceDefinition]));
    final instance = registry.ensureInstance(sourceDefinition.id);
    final host = SourceHost(
      registry: registry,
      runtimeFor: (definition) async =>
          LuaSourceRuntime(source: source, fileName: definition.entry!),
    );

    await expectLater(
      host.agenda(instance),
      throwsA(
        isA<SourceError>().having(
          (error) => error.code,
          'code',
          'permission_denied',
        ),
      ),
    );
  });

  test('source host passes an authorized HTTP request through', () async {
    final sourceDefinition = definition(
      permissions: SourcePermissions(
        networkHosts: const ['https://example.com'],
      ),
    );
    final registry = SourceRegistry(catalog: SourceCatalog([sourceDefinition]));
    final instance = registry.ensureInstance(sourceDefinition.id);
    final transport = _FakeTransport();
    final host = SourceHost(
      registry: registry,
      runtimeFor: (definition) async =>
          LuaSourceRuntime(source: source, fileName: definition.entry!),
      httpTransport: transport,
    );

    final result = await host.agenda(instance);

    expect(result.items.single.title, '来自 HTTP');
    expect(transport.received, {'url': 'https://example.com/data.json'});
  });
}
