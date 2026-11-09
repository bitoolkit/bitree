import 'package:bitree/extensions/bundled.dart';
import 'package:bitree/extensions/controller.dart';
import 'package:bitree/extensions/package.dart';
import 'package:bitree/sources/builtin.dart';
import 'package:bitree/sources/registry.dart';
import 'package:bitree/sources/source.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

ExtensionManifest _manifest({
  required String id,
  required String sourceId,
  String? extendsId,
}) {
  final source = <String, Object?>{
    'id': sourceId,
    'name': {'zh': sourceId},
    'entry': 'source.lua',
  };
  if (extendsId == null) {
    source['operations'] = ['courses.list'];
  } else {
    source['extends'] = extendsId;
    source['baseVersion'] = '1.0.0';
  }
  return ExtensionManifest.parse({
    'id': id,
    'name': {'zh': id},
    'version': '1.0.0',
    'apiVersion': 1,
    'sources': [source],
  });
}

void main() {
  test('bundled packages are loaded, activated and cannot be replaced', () async {
    final manifest = _manifest(
      id: 'builtin.test',
      sourceId: 'source',
      extendsId: BuiltinSources.lexue,
    );
    final bundled = _BundledLoader([
      BundledExtensionPackage(
        manifest: manifest,
        sources: {'source.lua': 'return { operations = {} }\n'},
      ),
    ]);
    final registry = SourceRegistry(store: MemorySourceStore());
    final extensions = ExtensionController(
      sources: registry,
      store: MemoryExtensionStore(),
      bundledLoader: bundled,
    );
    addTearDown(extensions.dispose);
    addTearDown(registry.dispose);
    final lexue = registry.ensureInstance(BuiltinSources.lexue);

    await extensions.load();
    expect(extensions.isBundled('builtin.test'), isTrue);
    expect(extensions.packages.single.manifest.id, 'builtin.test');
    await extensions.activateBundledImplementations();
    expect(
      registry.instance(lexue.id)!.implementationId,
      'builtin.test/source',
    );
    expect(
      () => extensions.uninstall('builtin.test'),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => extensions.install(
        ExtensionPackage(manifest: manifest, location: 'download:test'),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('catalog resolves a multi-level inheritance chain', () {
    final base = SourceDefinition(
      id: 'test.base',
      packageId: 'test.package',
      sourceId: 'base',
      name: const LocalizedSourceName({'zh': '基础'}),
      extendsId: BuiltinSources.lexue,
      baseVersion: '1.0.0',
      operations: {SourceOperation.coursesResolve},
    );
    final leaf = SourceDefinition(
      id: 'test.leaf',
      packageId: 'test.package',
      sourceId: 'leaf',
      name: const LocalizedSourceName({'zh': '补丁'}),
      extendsId: base.id,
      baseVersion: '1.0.0',
      operations: {SourceOperation.deadlinesRead},
    );
    final catalog = SourceCatalog([...BuiltinSources.all, base, leaf]);
    final effective = catalog.require(leaf.id);

    expect(effective.id, leaf.id);
    expect(effective.supports(SourceOperation.coursesList), isTrue);
    expect(effective.supports(SourceOperation.coursesResolve), isTrue);
    expect(effective.supports(SourceOperation.deadlinesRead), isTrue);
  });

  test('catalog rejects inheritance cycles', () {
    final first = SourceDefinition(
      id: 'test.first',
      packageId: 'test.package',
      sourceId: 'first',
      name: const LocalizedSourceName({'zh': '一'}),
      extendsId: 'test.second',
      baseVersion: '1.0.0',
    );
    final second = SourceDefinition(
      id: 'test.second',
      packageId: 'test.package',
      sourceId: 'second',
      name: const LocalizedSourceName({'zh': '二'}),
      extendsId: first.id,
      baseVersion: '1.0.0',
    );

    expect(
      () => SourceCatalog([first, second]).require(first.id),
      throwsA(isA<FormatException>()),
    );
  });
}

class _BundledLoader implements BundledExtensionLoader {
  _BundledLoader(this.packages);

  final List<BundledExtensionPackage> packages;

  @override
  Future<List<BundledExtensionPackage>> load() async => packages;
}
