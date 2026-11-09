import 'package:flutter/foundation.dart';

import '../core/async/serial_queue.dart';
import '../core/diagnostics.dart';
import 'builtin.dart';
import 'course_selection.dart';
import 'source.dart';
import 'store.dart';

/// Owns source definitions, accounts, instances and course selection. Domain
/// controllers remain responsible for their own records.
class SourceRegistry extends ChangeNotifier {
  SourceRegistry({
    SourceStore? store,
    SourceCatalog? catalog,
  }) : _store = store ?? const SourceStore(),
       _catalog = catalog ?? SourceCatalog.builtin();

  final SourceStore _store;
  SourceCatalog _catalog;
  final _operations = SerialQueue();
  final _accounts = <String, SourceAccount>{};
  final _instances = <String, SourceInstance>{};
  final _selections = <String, SourceCourseSelection>{};
  bool _ready = false;
  bool _disposed = false;

  bool get ready => _ready;
  Iterable<SourceAccount> get accounts => _accounts.values;
  Iterable<SourceInstance> get instances => _instances.values;
  SourceCatalog get catalog => _catalog;

  void replaceCatalog(SourceCatalog catalog) {
    _catalog = catalog;
    _notify();
  }

  Future<void> load() => _operations.run(() async {
    try {
      final library = await _store.read();
      _accounts
        ..clear()
        ..addAll({for (final account in library.accounts) account.id: account});
      _instances
        ..clear()
        ..addAll({
          for (final instance in library.instances) instance.id: instance,
        });
      _selections
        ..clear()
        ..addAll(library.selections);
    } catch (failure, stack) {
      AppDiagnostics.instance.report('读取数据来源', failure, stack);
    }
    _ready = true;
    _notify();
  });

  SourceAccount? account(String? id) =>
      id == null ? null : _accounts[id];

  SourceInstance? instance(String id) => _instances[id];

  SourceInstance? instanceForAccount(String definitionId, String accountId) {
    for (final instance in _instances.values) {
      if (instance.definitionId == definitionId &&
          instance.accountId == accountId) {
        return instance;
      }
    }
    return null;
  }

  SourceInstance ensureInstance(
    String definitionId, {
    String? accountId,
    Map<String, dynamic> settings = const {},
  }) {
    _catalog.require(definitionId);
    if (accountId != null) {
      final existing = instanceForAccount(definitionId, accountId);
      if (existing != null) return existing;
      final unbound = _instances.values
          .where(
            (instance) =>
                instance.definitionId == definitionId &&
                instance.accountId == null,
          )
          .firstOrNull;
      if (unbound != null) {
        final bound = unbound.copyWith(accountId: accountId);
        _instances[bound.id] = bound;
        _notify();
        return bound;
      }
    }
    final existing = _instances.values
        .where(
          (instance) =>
              instance.definitionId == definitionId &&
              instance.accountId == accountId,
        )
        .firstOrNull;
    if (existing != null) return existing;
    final id = accountId == null
        ? 'instance:$definitionId'
        : 'instance:$definitionId:$accountId';
    final created = SourceInstance(
      id: id,
      definitionId: definitionId,
      accountId: accountId,
      settings: settings,
      createdAt: DateTime.now(),
    );
    _instances[id] = created;
    _notify();
    return created;
  }

  Future<SourceAccount> ensureAccount({
    required String service,
    required String identity,
    String? displayName,
    SourceAccountStatus status = SourceAccountStatus.signedIn,
  }) => _operations.run(() async {
    final id = '$service:$identity';
    final existing = _accounts[id];
    final account =
        existing?.copyWith(
          displayName: displayName,
          status: status,
        ) ??
        SourceAccount(
          id: id,
          service: service,
          identity: identity,
          displayName: displayName,
          status: status,
        );
    _accounts[id] = account;
    await _save();
    _notify();
    return account;
  });

  Future<void> updateAccount(SourceAccount account) => _operations.run(() async {
    _accounts[account.id] = account;
    await _save();
    _notify();
  });

  Future<void> removeAccount(String id) => _operations.run(() async {
    _accounts.remove(id);
    final removed = [
      for (final instance in _instances.values)
        if (instance.accountId == id) instance.id,
    ];
    for (final instanceId in removed) {
      _instances.remove(instanceId);
      _selections.remove(instanceId);
    }
    await _save();
    _notify();
  });

  Future<void> setEnabled(String instanceId, bool enabled) =>
      _operations.run(() async {
        final existing = _requireInstance(instanceId);
        _instances[instanceId] = existing.copyWith(enabled: enabled);
        await _save();
        _notify();
      });

  Future<void> setImplementation(
    String instanceId,
    String? definitionId,
  ) => _operations.run(() async {
    final existing = _requireInstance(instanceId);
    if (definitionId != null) _catalog.require(definitionId);
    _instances[instanceId] = existing.copyWith(
      implementationId: definitionId,
    );
    await _save();
    _notify();
  });

  Future<void> setSettings(
    String instanceId,
    Map<String, dynamic> settings,
  ) => _operations.run(() async {
    final existing = _requireInstance(instanceId);
    final definition = definitionFor(existing);
    final validated = <String, dynamic>{};
    for (final field in definition.settings) {
      final value = field.validate(settings[field.key] ?? field.defaultValue);
      if (value != null) validated[field.key] = value;
    }
    if (settings.keys.any(
      (key) => !definition.settings.any((field) => field.key == key),
    )) {
      throw const FormatException('来源设置包含未声明字段');
    }
    _instances[instanceId] = existing.copyWith(settings: validated);
    await _save();
    _notify();
  });

  SourceDefinition definitionFor(SourceInstance instance) =>
      _catalog.require(instance.implementationId ?? instance.definitionId);

  SourceCourseSelection selection(String instanceId) {
    final existing = _selections[instanceId];
    if (existing != null) return existing;
    final created = SourceCourseSelection(sourceInstanceId: instanceId);
    _selections[instanceId] = created;
    return created;
  }

  Future<void> mergeDiscoveredCourses(
    String instanceId,
    Iterable<PlatformCourse> courses,
  ) => _operations.run(() async {
    _requireInstance(instanceId);
    selection(instanceId).mergeDiscovered(courses);
    await _save();
    _notify();
  });

  Future<void> addManualCourse(
    String instanceId,
    PlatformCourse course,
  ) => _operations.run(() async {
    _requireInstance(instanceId);
    selection(instanceId).addManual(course);
    await _save();
    _notify();
  });

  Future<void> removeManualCourse(String instanceId, String remoteId) =>
      _operations.run(() async {
        _requireInstance(instanceId);
        selection(instanceId).removeManual(remoteId);
        await _save();
        _notify();
      });

  Future<void> setCourseSelected(
    String instanceId,
    String remoteId,
    bool selected,
  ) => _operations.run(() async {
    _requireInstance(instanceId);
    selection(instanceId).setSelected(remoteId, selected);
    await _save();
    _notify();
  });

  Future<void> linkCourse(
    String instanceId, {
    required String localCourseId,
    required String remoteId,
  }) => _operations.run(() async {
    _requireInstance(instanceId);
    selection(
      instanceId,
    ).link(localCourseId: localCourseId, remoteId: remoteId);
    await _save();
    _notify();
  });

  Future<void> unlinkCourse(
    String instanceId, {
    required String localCourseId,
    required String remoteId,
  }) => _operations.run(() async {
    _requireInstance(instanceId);
    selection(
      instanceId,
    ).unlink(localCourseId: localCourseId, remoteId: remoteId);
    await _save();
    _notify();
  });

  Future<void> unlinkLocalCourse(String localCourseId) =>
      _operations.run(() async {
        for (final selection in _selections.values) {
          selection.unlinkLocal(localCourseId);
        }
        await _save();
        _notify();
      });

  SourceInstance _requireInstance(String id) {
    final instance = _instances[id];
    if (instance == null) throw FormatException('未知的来源实例：$id');
    return instance;
  }

  Future<void> _save() => _store.write(
    SourceLibrary(
      accounts: _accounts.values.toList(),
      instances: _instances.values.toList(),
      selections: Map.of(_selections),
    ),
  );

  Future<void> persist() => _operations.run(_save);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
