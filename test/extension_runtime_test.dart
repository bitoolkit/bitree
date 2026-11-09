import 'dart:io';

import 'package:bitree/extensions/controller.dart';
import 'package:bitree/extensions/lua_source.dart';
import 'package:bitree/sources/builtin.dart';
import 'package:bitree/sources/registry.dart';
import 'package:bitree/sync/controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// A package with a Lexue fix and a new source that lists one course with
/// one deadline.
Future<String> _writePackage() async {
  final directory = await Directory.systemTemp.createTemp(
    'bitree-extension-runtime-',
  );
  addTearDown(() => directory.delete(recursive: true));
  await File('${directory.path}/manifest.json').writeAsString('''
{
  "id": "test.package",
  "name": {"zh": "测试扩展"},
  "version": "1.0.0",
  "apiVersion": 1,
  "sources": [
    {
      "id": "fix",
      "name": {"zh": "乐学修复"},
      "entry": "fix.lua",
      "extends": "builtin.bit.lexue",
      "baseVersion": "1.0.0"
    },
    {
      "id": "extra",
      "name": {"zh": "新平台"},
      "entry": "extra.lua",
      "operations": ["courses.list", "deadlines.read"]
    }
  ]
}
''');
  await File('${directory.path}/fix.lua')
      .writeAsString('return { operations = {}, steps = {} }\n');
  await File('${directory.path}/extra.lua').writeAsString('''
return {
  operations = {
    ["courses.list"] = function(ctx, query)
      return { { remoteId = "1", name = "新平台课程" } }
    end,
    ["deadlines.read"] = function(ctx, query)
      return {
        {
          remoteId = "task-" .. query.course.remoteId,
          title = "新平台作业",
          dueAt = "2026-11-02T15:59:00Z",
          course = query.course.name,
        },
      }
    end,
  },
}
''');
  return directory.path;
}

void main() {
  test(
    'installing adds new sources and switches the sources it extends',
    () async {
      final path = await _writePackage();
      final registry = SourceRegistry(store: MemorySourceStore());
      final extensions = ExtensionController(
        sources: registry,
        store: MemoryExtensionStore(),
      );
      addTearDown(extensions.dispose);
      addTearDown(registry.dispose);
      final lexue = registry.ensureInstance(BuiltinSources.lexue);

      final package = await extensions.inspectDirectory(path);
      expect(extensions.packages, isEmpty);
      await extensions.install(package);

      expect(registry.instance(lexue.id)!.implementationId, 'test.package/fix');
      final extra = registry.instances.singleWhere(
        (instance) => instance.definitionId == 'test.package/extra',
      );
      expect(
        await extensions.runtimeFor(registry.definitionFor(extra)),
        isA<LuaSourceRuntime>(),
      );

      await registry.setImplementation(lexue.id, null);
      final update = await extensions.inspectDirectory(path);
      expect(extensions.fixesAppliedBy(update), isEmpty);
      await extensions.install(update);
      expect(registry.instance(lexue.id)!.implementationId, isNull);

      await registry.setImplementation(lexue.id, 'test.package/fix');
      await extensions.uninstall('test.package');
      expect(registry.instance(lexue.id)!.implementationId, isNull);
    },
  );

  test('sync all reads enabled extension sources', () async {
    final controller = TestAppController();
    await controller.initialize();
    expect(
      controller.sync.bulkTargets,
      isNot(contains(SyncTarget.extensionSources)),
    );
    await controller.extensions.install(
      await controller.extensions.inspectDirectory(await _writePackage()),
    );
    expect(controller.sync.bulkTargets, contains(SyncTarget.extensionSources));

    expect(
      await controller.sync.synchronize({SyncTarget.extensionSources}),
      isTrue,
    );
    expect(controller.sync.results[SyncTarget.extensionSources]!.count, 1);
    expect(controller.agenda.entries.single.title, '新平台作业');

    final extra = controller.sources.instances.singleWhere(
      (instance) => instance.definitionId == 'test.package/extra',
    );
    await controller.sources.setEnabled(extra.id, false);
    expect(
      controller.sync.bulkTargets,
      isNot(contains(SyncTarget.extensionSources)),
    );
  });
}
