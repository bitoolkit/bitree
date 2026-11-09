import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/diagnostics.dart';
import '../sources/builtin.dart';
import '../sources/registry.dart';
import '../sources/runtime.dart';
import '../sources/source.dart';
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
  }) : _store = store ?? const ExtensionStore(),
       _loader = loader ?? const ExtensionPackageLoader();

  final SourceRegistry sources;
  final ExtensionStore _store;
  final ExtensionPackageLoader _loader;
  final Map<String, ExtensionPackage> _packages = {};
  final Map<String, String> _sourcesByDefinition = {};
  final Map<String, SourceRuntime> _runtimesByDefinition = {};
  bool _ready = false;
  bool _disposed = false;

  bool get ready => _ready;
  Iterable<ExtensionPackage> get packages => _packages.values;

  Future<void> load() async {
    try {
      final library = await _store.read();
      _packages
        ..clear()
        ..addAll({
          for (final package in library.packages) package.manifest.id: package,
        });
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
    final catalog = sources.catalog.withDefinitions(
      package.manifest.definitions,
    );
    for (final definition in package.manifest.definitions) {
      catalog.require(definition.id);
    }
    await _validateSources(package);
    return package;
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
        if (instance.definitionId == fix.extendsId) {
          await sources.setImplementation(instance.id, fix.id);
        }
      }
    }
    await sources.persist();
    _notify();
  }

  Future<void> uninstall(String packageId) async {
    final package = _packages.remove(packageId);
    if (package == null) return;
    for (final definition in package.manifest.definitions) {
      for (final instance in sources.instances) {
        if (instance.implementationId == definition.id) {
          await sources.setImplementation(instance.id, null);
        }
      }
      _sourcesByDefinition.remove(definition.id);
      _runtimesByDefinition.remove(definition.id);
    }
    _rebuildCatalog();
    await _save();
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
    for (final declaration in package.manifest.sources) {
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
      _store.write(ExtensionLibrary(packages: _packages.values.toList()));

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
