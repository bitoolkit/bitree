import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/async/cancelable_request.dart';
import '../core/diagnostics.dart';
import '../l10n/app_localizations.dart';
import '../schedule/model.dart';
import 'deadline_clear_scope.dart';
import 'model.dart';
import 'physics_lab_deadlines.dart';
import 'store.dart';

class AgendaController extends ChangeNotifier {
  AgendaController(this._store);

  final AgendaStore _store;
  List<AgendaEntry> _entries = const [];
  Future<void> _operations = Future<void>.value();
  bool _ready = false;
  bool _busy = false;
  bool _disposed = false;

  bool get ready => _ready;
  bool get busy => _busy;

  Iterable<AgendaEntry> get entries =>
      _entries.where((entry) => !entry.deleted);

  Iterable<AgendaEntry> get deletedDeadlines =>
      _entries.where((entry) => entry.deleted);

  List<AgendaEntry> pendingOn(DateTime date, {required DateTime now}) =>
      entries
          .where((entry) => !entry.isFinished(now) && entry.occursOn(date))
          .toList()
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

  Future<void> load() => _serialize(() async {
    if (_disposed) return;
    _busy = true;
    _ready = false;
    _notify();
    try {
      _entries = List.unmodifiable(await _store.read());
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

  Future<bool> restore(AgendaEntry entry) => _write(
    (entries) => [
      for (final item in entries)
        item.id == entry.id ? item.copyWith(deleted: false) : item,
      if (!entries.any((item) => item.id == entry.id))
        entry.copyWith(deleted: false),
    ],
  );

  Future<bool> delete(AgendaEntry entry) => _write(
    (entries) => [
      for (final item in entries)
        if (item.id != entry.id)
          item
        else if (item.isDeadline)
          item.copyWith(deleted: true),
    ],
  );

  Future<bool> restoreDeletedDeadlines() => _write(
    (entries) => [for (final entry in entries) entry.copyWith(deleted: false)],
  );

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
  }) => _write((entries) {
    final unmatched = [...incoming];
    final matched = <AgendaEntry>[];
    final merged = <AgendaEntry>[];
    for (final saved in entries) {
      final index = unmatched.indexWhere(
        (entry) => _sameRemoteEntry(saved, entry),
      );
      if (index < 0) {
        if (matched.any((entry) => _sameRemoteEntry(saved, entry))) continue;
        merged.add(saved);
        continue;
      }
      final entry = unmatched.removeAt(index);
      matched.add(entry);
      final next = saved.local ? saved : entry;
      merged.add(
        next.copyWith(
          done: saved.local ? entry.done || saved.done : entry.done,
          deleted: saved.deleted,
        ),
      );
    }
    return [...merged, ...unmatched];
  }, checkActive: checkActive);

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
    required AppLocalizations l10n,
    DateTime? now,
    void Function()? checkActive,
  }) => _serialize(() async {
    if (!_ready) {
      _reportNotReady();
      return null;
    }
    checkActive?.call();
    final importedAt = now ?? campusNow();
    final incoming = physicsLabDeadlines(schedule, l10n);
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
  }) => _serialize(() async {
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

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _operations.then((_) => operation());
    _operations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
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

bool _sameRemoteEntry(AgendaEntry left, AgendaEntry right) {
  if (left.id == right.id && left.source == right.source) return true;
  if (left.kind != AgendaKind.deadline ||
      right.kind != AgendaKind.deadline ||
      left.source == null ||
      left.source != right.source) {
    return false;
  }

  final leftUrl = left.url;
  final rightUrl = right.url;
  if (leftUrl != null && rightUrl != null) {
    if (leftUrl.scheme != rightUrl.scheme ||
        leftUrl.host != rightUrl.host ||
        leftUrl.path != rightUrl.path) {
      return false;
    }
    final leftId = leftUrl.queryParameters['id'];
    final rightId = rightUrl.queryParameters['id'];
    if (leftId != null || rightId != null) return leftId == rightId;
    final leftActivity = leftUrl.fragment;
    final rightActivity = rightUrl.fragment;
    if (leftActivity.isNotEmpty && rightActivity.isNotEmpty) {
      return leftActivity == rightActivity;
    }
    return leftUrl.replace(fragment: '') == rightUrl.replace(fragment: '') &&
        _sameDeadlineMetadata(left, right);
  }

  return _sameDeadlineMetadata(left, right);
}

bool _sameDeadlineMetadata(AgendaEntry left, AgendaEntry right) {
  return left.course == right.course &&
      left.title == right.title &&
      left.startsAt == right.startsAt &&
      left.allDay == right.allDay;
}
