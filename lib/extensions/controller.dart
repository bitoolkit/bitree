import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/diagnostics.dart';
import '../sources/builtin.dart';
import '../sources/registry.dart';
import '../sources/source.dart';
import 'lua_source.dart';
import 'package.dart';
import 'store.dart';

/// Owns installed extension packages and their source declarations. Source
/// instances still belong to [SourceRegistry]; this controller only mutates
/// the catalog and package lifecycle.
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
  bool _ready = false;
  bool _disposed = false;

  bool get ready => _ready;
  Iterable<ExtensionPackage> get packages => _packages.values;

  Future<void> load() async {
    try {
      final library = await _store.read();
      _packages
        ..clear()
        ..addAll({for (final package in library.packages) package.manifest.id: package});
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

  /// Loads and compiles the Lua source for a definition when it is an
  /// extension source. Built-in Dart definitions return null.
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

  Future<ExtensionPackage> installDirectory(String path) async {
    final package = await _loader.readDirectory(path);
    final previous = _packages[package.manifest.id];
    final installed = package.copyWith(
      enabled: previous?.enabled ?? false,
      installedAt: DateTime.now(),
    );
    _packages[installed.manifest.id] = installed;
    _rebuildCatalog();
    await _save();
    _notify();
    return installed;
  }

  Future<void> setEnabled(String packageId, bool enabled) async {
    final package = _packages[packageId];
    if (package == null) throw FormatException('未知扩展：$packageId');
    if (enabled) {
      await _validateSources(package);
    }
    _packages[packageId] = package.copyWith(enabled: enabled);
    await _save();
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
    }
    _rebuildCatalog();
    await _save();
    _notify();
  }

  void _rebuildCatalog() {
    sources.replaceCatalog(
      SourceCatalog([
        ...BuiltinSources.all,
        for (final package in _packages.values)
          ...package.manifest.definitions,
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

  Future<void> _save() => _store.write(
    ExtensionLibrary(packages: _packages.values.toList()),
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
