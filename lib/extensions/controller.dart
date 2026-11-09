import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/diagnostics.dart';
import '../sources/builtin.dart';
import '../sources/registry.dart';
import '../sources/runtime.dart';
import '../sources/source.dart';
import 'bundle_store.dart';
import 'bundled.dart';
import 'download.dart';
import 'lua_source.dart';
import 'package.dart';
import 'store.dart';

/// Owns installed extension packages and their source declarations. An
/// installed package is active: installing it adds its new sources and
/// switches the sources it extends to its implementation. Source instances
/// still belong to [SourceRegistry].
class ExtensionController extends ChangeNotifier {
  ExtensionController({
    required this.sources,
    ExtensionStore? store,
    ExtensionPackageLoader? loader,
    BundledExtensionLoader? bundledLoader,
    ExtensionDownloader? downloader,
    ExtensionBundleStore? bundleStore,
  }) : _store = store ?? const ExtensionStore(),
       _loader = loader ?? const ExtensionPackageLoader(),
       _bundledLoader = bundledLoader ?? AssetBundledExtensions(),
       _downloader = downloader ?? ExtensionDownloader(),
       _bundleStore = bundleStore ?? const ExtensionBundleStore();

  final SourceRegistry sources;
  final ExtensionStore _store;
  final ExtensionPackageLoader _loader;
  final BundledExtensionLoader _bundledLoader;
  final ExtensionDownloader _downloader;
  final ExtensionBundleStore _bundleStore;
  final Map<String, ExtensionPackage> _packages = {};
  final Map<String, Map<String, String>> _bundledSources = {};
  final Set<String> _bundledIds = {};
  final Map<String, String> _sourcesByDefinition = {};
  final Map<String, SourceRuntime> _runtimesByDefinition = {};
  bool _ready = false;
  bool _disposed = false;

  bool get ready => _ready;
  Iterable<ExtensionPackage> get packages => _packages.values;
  bool isBundled(String packageId) => _bundledIds.contains(packageId);

  Future<void> load() async {
    try {
      final bundled = await _bundledLoader.load();
      final library = await _store.read();
      _packages.clear();
      _bundledSources.clear();
      _bundledIds.clear();
      _sourcesByDefinition.clear();
      _runtimesByDefinition.clear();
      for (final package in bundled) {
        final id = package.manifest.id;
        _validateSourceMap(package.manifest, package.sources);
        _bundledIds.add(id);
        _bundledSources[id] = Map.unmodifiable(package.sources);
        _packages[id] = ExtensionPackage(
          manifest: package.manifest,
          location: 'bundled:$id',
        );
      }
      for (final package in library.packages) {
        if (_bundledIds.contains(package.manifest.id) ||
            _isReservedPackageId(package.manifest.id)) {
          continue;
        }
        _packages[package.manifest.id] = package;
      }
      _rebuildCatalog();
      _ready = true;
      _notify();
    } catch (failure, stack) {
      AppDiagnostics.instance.report('读取扩展', failure, stack);
      _ready = true;
      _notify();
    }
  }

  ExtensionPackage? package(String id) => _packages[id];

  String? bundledImplementationFor(String definitionId) {
    for (final package in _packages.values) {
      if (!isBundled(package.manifest.id)) continue;
      for (final definition in package.manifest.definitions) {
        if (definition.extendsId == definitionId) return definition.id;
      }
    }
    return null;
  }

  Future<void> activateBundledImplementations() async {
    for (final instance in sources.instances.toList()) {
      final implementation = bundledImplementationFor(instance.definitionId);
      final selected = instance.implementationId;
      if (implementation != null &&
          (selected == null || sources.catalog[selected] == null)) {
        await sources.setImplementation(instance.id, implementation);
      }
    }
  }

  SourceDefinition? definitionForInstance(SourceInstance instance) {
    try {
      return sources.definitionFor(instance);
    } on FormatException {
      return null;
    }
  }

  /// Loads the Lua source for an extension definition.
  Future<String?> sourceFor(SourceDefinition definition) async {
    final entry = definition.entry;
    if (entry == null) return null;
    final package = _packages[definition.packageId];
    if (package == null) {
      throw FormatException('扩展包未安装：${definition.packageId}');
    }
    if (isBundled(package.manifest.id)) {
      return _bundledSources[package.manifest.id]?[entry];
    }
    final cached = _sourcesByDefinition[definition.id];
    if (cached != null) return cached;
    final sources = await _loader.readSources(package);
    for (final declared in package.manifest.sources) {
      final id = declared.definitionId(package.manifest.id);
      if (sources[declared.entry] case final source?) {
        _sourcesByDefinition[id] = source;
      }
    }
    return _sourcesByDefinition[definition.id];
  }

  Future<SourceRuntime?> runtimeFor(SourceDefinition definition) async {
    final cached = _runtimesByDefinition[definition.id];
    if (cached != null) return cached;
    final source = await sourceFor(definition);
    if (source == null) return null;
    final runtime = LuaSourceRuntime(
      source: source,
      fileName: definition.entry!,
    );
    _runtimesByDefinition[definition.id] = runtime;
    return runtime;
  }

  /// Reads and validates a package folder without installing it.
  Future<ExtensionPackage> inspectDirectory(String path) async {
    final package = await _loader.readDirectory(path);
    _requireUserPackageId(package.manifest.id);
    final catalog = sources.catalog.withDefinitions(
      package.manifest.definitions,
    );
    for (final definition in package.manifest.definitions) {
      catalog.require(definition.id);
    }
    await _validateSources(package);
    return package;
  }

  Future<ExtensionBundle> inspectDownload({
    required String url,
    required String sha256,
  }) async {
    final parsed = Uri.tryParse(url.trim());
    if (parsed == null) throw const FormatException('扩展包地址无效');
    final bundle = await _downloader.inspect(url: parsed, sha256: sha256);
    _requireUserPackageId(bundle.manifest.id);
    if (_bundledIds.contains(bundle.manifest.id)) {
      throw FormatException('不能覆盖内置扩展包：${bundle.manifest.id}');
    }
    _validateSourceMap(bundle.manifest, bundle.sources);
    return bundle;
  }

  /// Fixes that [install] applies to the sources they extend. A reinstall or
  /// update keeps the implementation each source already uses.
  List<SourceDefinition> fixesAppliedBy(ExtensionPackage package) {
    final installed = {
      for (final definition
          in _packages[package.manifest.id]?.manifest.definitions ??
              const <SourceDefinition>[])
        definition.id,
    };
    return [
      for (final definition in package.manifest.definitions)
        if (definition.extendsId != null && !installed.contains(definition.id))
          definition,
    ];
  }

  Future<void> install(ExtensionPackage package) async {
    _requireUserPackageId(package.manifest.id);
    if (_bundledIds.contains(package.manifest.id)) {
      throw FormatException('不能覆盖内置扩展包：${package.manifest.id}');
    }
    final conflict = [
      for (final existing in _packages.values)
        if (existing.manifest.id != package.manifest.id)
          for (final definition in existing.manifest.definitions)
            if (package.manifest.definitions.any(
              (candidate) => candidate.id == definition.id,
            ))
              definition.id,
    ];
    if (conflict.isNotEmpty) {
      throw FormatException('扩展来源编号已被占用：${conflict.join(', ')}');
    }
    await _validateSources(package);
    final previous = _packages[package.manifest.id];
    final fixes = fixesAppliedBy(package);
    _packages[package.manifest.id] = package.installed(DateTime.now());
    _sourcesByDefinition.clear();
    _runtimesByDefinition.clear();
    _rebuildCatalog();
    await _save();
    for (final definition in package.manifest.definitions) {
      if (definition.extendsId == null) sources.ensureInstance(definition.id);
    }
    for (final fix in fixes) {
      for (final instance in sources.instances.toList()) {
        if (instance.definitionId == fix.extendsId ||
            instance.implementationId == fix.extendsId) {
          await sources.setImplementation(instance.id, fix.id);
        }
      }
    }
    await sources.persist();
    if (previous != null &&
        previous.managed &&
        previous.location != package.location) {
      await _bundleStore.remove(previous);
    }
    _notify();
  }

  Future<void> installDownload(ExtensionBundle bundle) async {
    final package = await _bundleStore.write(bundle);
    try {
      await install(package);
    } catch (_) {
      await _bundleStore.remove(package);
      rethrow;
    }
  }

  Future<void> uninstall(String packageId) async {
    if (_bundledIds.contains(packageId)) {
      throw const FormatException('内置扩展包不能卸载');
    }
    final package = _packages.remove(packageId);
    if (package == null) return;
    for (final definition in package.manifest.definitions) {
      for (final instance in sources.instances) {
        if (instance.implementationId == definition.id) {
          await sources.setImplementation(
            instance.id,
            bundledImplementationFor(instance.definitionId),
          );
        }
      }
      _sourcesByDefinition.remove(definition.id);
      _runtimesByDefinition.remove(definition.id);
    }
    _rebuildCatalog();
    await _save();
    await _bundleStore.remove(package);
    _notify();
  }

  void _rebuildCatalog() {
    sources.replaceCatalog(
      SourceCatalog([
        ...BuiltinSources.all,
        for (final package in _packages.values) ...package.manifest.definitions,
      ]),
    );
  }

  Future<void> _validateSources(ExtensionPackage package) async {
    final sources = await _loader.readSources(package);
    _validateSourceMap(package.manifest, sources);
  }

  void _validateSourceMap(
    ExtensionManifest manifest,
    Map<String, String> sources,
  ) {
    for (final declaration in manifest.sources) {
      final source = sources[declaration.entry];
      if (source == null) {
        throw FormatException('扩展缺少脚本：${declaration.entry}');
      }
      // Parsing the entry table is enough to validate syntax and the public
      // contract without running an operation or touching a session.
      LuaSourceModule.parse(
        source,
        fileName: declaration.entry,
        requiredOperations: declaration.operations,
      );
    }
  }

  Future<void> _save() =>
      _store.write(
        ExtensionLibrary(
          packages: [
            for (final package in _packages.values)
              if (!isBundled(package.manifest.id)) package,
          ],
        ),
      );

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

bool _isReservedPackageId(String id) =>
    id == 'builtin' || id.startsWith('builtin.');

void _requireUserPackageId(String id) {
  if (_isReservedPackageId(id)) {
    throw FormatException('扩展包编号使用保留前缀：$id');
  }
}
