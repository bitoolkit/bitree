import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/async/cancelable_request.dart';
import '../core/async/serial_queue.dart';
import '../core/diagnostics.dart';
import '../core/time.dart';
import '../schedule/model.dart';
import 'deadline_clear_scope.dart';
import 'model.dart';
import 'physics_lab_deadlines.dart';
import 'store.dart';

part 'merge.dart';

class AgendaController extends ChangeNotifier {
  AgendaController(this._store);

  final AgendaStore _store;
  List<AgendaEntry> _entries = const [];
  final _operations = SerialQueue();
  bool _ready = false;
  bool _busy = false;
  bool _disposed = false;

  bool get ready => _ready;
  bool get busy => _busy;

  Iterable<AgendaEntry> get entries =>
      _entries.where((entry) => !entry.deleted);

  Iterable<AgendaEntry> get deletedDeadlines =>
      _entries.where((entry) => entry.deleted && entry.isDeadline);

  List<AgendaEntry> pendingOn(DateTime date, {required DateTime now}) =>
      entries
          .where((entry) => !entry.isFinished(now) && entry.occursOn(date))
          .toList()
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

  Future<void> load() => _operations.run(() async {
    if (_disposed) return;
    _busy = true;
    _ready = false;
    _notify();
    try {
      _entries = List.unmodifiable(await _store.readAndMigrate());
      _ready = true;
    } on Exception catch (failure, stack) {
      AppDiagnostics.instance.report('读取日程', failure, stack);
    } finally {
      _busy = false;
      _notify();
    }
  });

  Future<bool> save(AgendaEntry entry) => _write(
    (entries) => [...entries.where((item) => item.id != entry.id), entry],
  );

  Future<bool> restore(AgendaEntry entry) => restoreEntries([entry]);

  /// Restores saved entries in one write and re-inserts records that were
  /// physically removed by a non-DDL deletion.
  Future<bool> restoreEntries(Iterable<AgendaEntry> selected) {
    final byId = {for (final entry in selected) entry.id: entry};
    return _write((entries) {
      final existingIds = {for (final entry in entries) entry.id};
      return [
        for (final entry in entries)
          if (byId.containsKey(entry.id))
            entry.copyWith(deleted: false)
          else
            entry,
        for (final entry in byId.values)
          if (!existingIds.contains(entry.id)) entry.copyWith(deleted: false),
      ];
    });
  }

  Future<bool> delete(AgendaEntry entry) => _write(
    (entries) => [
      for (final item in entries)
        if (item.id != entry.id)
          item
        else if (item.isDeadline)
          item.copyWith(deleted: true),
    ],
  );

  Future<bool> restoreDeletedDeadlines() => restoreEntries(deletedDeadlines);

  Future<bool> emptyDeletedDeadlines() => _write((entries) {
    final remaining = entries
        .where((entry) => !(entry.deleted && entry.isDeadline))
        .toList();
    return remaining.length == entries.length ? null : remaining;
  });

  Future<bool> replaceExams(
    String term,
    List<AgendaEntry> exams, {
    void Function()? checkActive,
  }) => _write((entries) {
    final edited = {
      for (final entry in entries)
        if (entry.kind == AgendaKind.exam && entry.term == term && entry.local)
          entry.id,
    };
    return [
      ...entries.where(
        (entry) =>
            entry.kind != AgendaKind.exam || entry.term != term || entry.local,
      ),
      ...exams.where((entry) => !edited.contains(entry.id)),
    ];
  }, checkActive: checkActive);

  Future<bool> mergeDeadlines(
    List<AgendaEntry> incoming, {
    void Function()? checkActive,
  }) => _write(
    (entries) => _mergeDeadlineEntries(entries, incoming),
    checkActive: checkActive,
  );

  int countDeadlines(DeadlineClearScope scope) =>
      _entries.where(scope.includes).length;

  Set<String> deadlineIdsIn(Iterable<DeadlineClearScope> scopes) {
    final selected = scopes.toSet();
    return {
      for (final entry in _entries)
        if (selected.any((scope) => scope.includes(entry))) entry.id,
    };
  }

  int countDeadlinesIn(Iterable<DeadlineClearScope> scopes) =>
      deadlineIdsIn(scopes).length;

  /// Delete selected origins in one write, never partially one group at a time.
  /// The dialog supplies the exact set it displayed before the final click.
  Future<bool> clearDeadlines(
    Iterable<DeadlineClearScope> scopes, {
    Set<String>? expectedIds,
  }) {
    final selected = scopes.toSet();
    return _write((entries) {
      final ids = {
        for (final entry in entries)
          if (selected.any((scope) => scope.includes(entry))) entry.id,
      };
      if (expectedIds != null && !setEquals(ids, expectedIds)) {
        AppDiagnostics.instance.notice('待删除的 DDL 已变化，请检查后重新确认。');
        return null;
      }
      if (ids.isEmpty) return null;
      return entries
          .where((entry) => !entry.isDeadline || !ids.contains(entry.id))
          .toList();
    });
  }

  /// Refresh this semester's generated records, keeping edits and tombstones.
  /// Only new entries are auto-completed when already past due at import time.
  /// Returns the matched generated count, or null when persistence fails.
  Future<int?> updatePhysicsLabDeadlines(
    SemesterSchedule schedule, {
    DateTime? now,
    void Function()? checkActive,
  }) => _operations.run(() async {
    if (!_ready) {
      _reportNotReady();
      return null;
    }
    checkActive?.call();
    final importedAt = now ?? campusNow();
    final incoming = physicsLabDeadlines(schedule);
    final savedById = {for (final entry in _entries) entry.id: entry};
    final next = <String, AgendaEntry>{
      for (final entry in _entries)
        if (!isPhysicsLabDeadline(entry) ||
            entry.term != schedule.term ||
            entry.local ||
            entry.done ||
            entry.deleted)
          entry.id: entry,
    };
    for (final entry in incoming) {
      final saved = savedById[entry.id];
      next[entry.id] = saved != null && saved.local
          ? saved
          : entry.copyWith(
              done: saved?.done ?? entry.dueAt.isBefore(importedAt),
              deleted: saved?.deleted ?? false,
            );
    }
    final saved = await _commit(next.values.toList(), checkActive: checkActive);
    return saved ? incoming.length : null;
  });

  Future<bool> _write(
    List<AgendaEntry>? Function(List<AgendaEntry> entries) transform, {
    void Function()? checkActive,
  }) => _operations.run(() async {
    if (!_ready) {
      _reportNotReady();
      return false;
    }
    checkActive?.call();
    final next = transform(_entries);
    if (next == null) return false;
    return _commit(next, checkActive: checkActive);
  });

  Future<bool> _commit(
    List<AgendaEntry> next, {
    void Function()? checkActive,
  }) async {
    _busy = true;
    _notify();
    try {
      checkActive?.call();
      await _store.write(next);
      _entries = List.unmodifiable(next);
      return true;
    } on RequestCancelled {
      rethrow;
    } on Exception catch (failure, stack) {
      AppDiagnostics.instance.report('保存日程', failure, stack);
      return false;
    } finally {
      _busy = false;
      _notify();
    }
  }

  void _reportNotReady() {
    if (!_disposed) {
      AppDiagnostics.instance.notice('日程尚未加载，请先重新加载日程。');
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
