import 'package:bitree/agenda/controller.dart';
import 'package:bitree/core/async/cancelable_request.dart';
import 'package:bitree/sources/builtin.dart';
import 'package:bitree/sources/host.dart';
import 'package:bitree/sources/registry.dart';
import 'package:bitree/sources/runtime.dart';
import 'package:bitree/sources/source.dart';
import 'package:bitree/sources/sync.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  test(
    'source sync discovers courses and imports each selected deadline',
    () async {
      final definition = SourceDefinition(
        id: 'test.builtin',
        packageId: 'test',
        sourceId: 'builtin',
        name: const LocalizedSourceName({'zh': '测试来源'}),
        operations: const {
          SourceOperation.coursesList,
          SourceOperation.deadlinesRead,
        },
        builtin: true,
      );
      final registry = SourceRegistry(
        store: MemorySourceStore(),
        catalog: SourceCatalog([definition]),
      );
      final instance = registry.ensureInstance(definition.id);
      final agenda = AgendaController(MemoryAgendaStore());
      await agenda.load();
      final host = SourceHost(
        registry: registry,
        runtimeFor: (definition) async => _FakeRuntime(),
      );
      final sync = SourceSync(sources: registry, host: host, agenda: agenda);

      final result = await sync.synchronize(instance);

      expect(result.complete, isTrue);
      expect(result.courseCount, 2);
      expect(result.deadlineCount, 2);
      expect(agenda.entries, hasLength(2));
      expect(
        agenda.entries.singleWhere((entry) => entry.course == '课程一').startsAt,
        DateTime.utc(2026, 11, 2, 23, 59),
      );
    },
  );

  test('source runtime cancellation uses the shared request type', () async {
    final definition = SourceDefinition(
      id: 'test.cancel',
      packageId: 'test',
      sourceId: 'cancel',
      name: const LocalizedSourceName({'zh': '取消来源'}),
      operations: const {SourceOperation.coursesList},
    );
    final registry = SourceRegistry(
      store: MemorySourceStore(),
      catalog: SourceCatalog([definition]),
    );
    final instance = registry.ensureInstance(definition.id);
    final agenda = AgendaController(MemoryAgendaStore());
    await agenda.load();
    final sync = SourceSync(
      sources: registry,
      host: SourceHost(
        registry: registry,
        runtimeFor: (definition) async => _CancellingRuntime(),
      ),
      agenda: agenda,
    );

    await expectLater(
      sync.synchronize(instance),
      throwsA(isA<RequestCancelled>()),
    );
  });
}

class _FakeRuntime implements SourceRuntime {
  @override
  Future<Object?> call(
    SourceDefinition definition,
    SourceOperation operation,
    Map<String, Object?> query,
    SourceOperationContext context,
  ) async {
    if (operation == SourceOperation.coursesList) {
      return [
        {'remoteId': '1', 'name': '课程一'},
        {'remoteId': '2', 'name': '课程二'},
      ];
    }
    final course = query['course'] as Map;
    return [
      {
        'remoteId': 'task-${course['remoteId']}',
        'title': '作业',
        'dueAt': '2026-11-02T15:59:00Z',
        'course': course['name'],
      },
    ];
  }
}

class _CancellingRuntime implements SourceRuntime {
  @override
  Future<Object?> call(
    SourceDefinition definition,
    SourceOperation operation,
    Map<String, Object?> query,
    SourceOperationContext context,
  ) async => throw const SourceCancelled();
}
