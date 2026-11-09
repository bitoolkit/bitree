import 'package:bitree/extensions/lua_source.dart';
import 'package:bitree/sources/builtin.dart';
import 'package:bitree/sources/host.dart';
import 'package:bitree/sources/registry.dart';
import 'package:bitree/sources/source.dart';
import 'package:bitree/sources/transport.dart';
import 'package:flutter_test/flutter_test.dart';

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
  test('source host forbids HTTP without a network permission', () async {
    final sourceDefinition = definition(permissions: SourcePermissions());
    final registry = SourceRegistry(catalog: SourceCatalog([sourceDefinition]));
    final instance = registry.ensureInstance(sourceDefinition.id);
    final host = SourceHost(
      registry: registry,
      loadSource: (definition) async => source,
    );

    await expectLater(
      host.agenda(instance),
      throwsA(
        isA<LuaSourceError>().having(
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
      loadSource: (definition) async => source,
      httpTransport: transport,
    );

    final result = await host.agenda(instance);

    expect(result.items.single.title, '来自 HTTP');
    expect(transport.received, {'url': 'https://example.com/data.json'});
  });
}
