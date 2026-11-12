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
  AgendaController(
    this._store, {
    DateTime Function()? now,
    void Function(String, Object, StackTrace)? reportError,
  }) : _now = now ?? campusNow,
       _reportError = reportError ?? AppDiagnostics.instance.report;

  final AgendaStore _store;
  final DateTime Function() _now;
  final void Function(String, Object, StackTrace) _reportError;
  Timer? _completionTimer;
  bool _completionClockActive = false;
  List<AgendaEntry> _entries = const [];
  final _operations = SerialQueue();
  bool _ready = false;
  bool _busy = false;
  bool _disposed = false;
  DeadlineCutoffWindow _deadlineCutoffWindow = const DeadlineCutoffWindow();

  void setDeadlineCutoff(DeadlineCutoffWindow window) {
    if (_deadlineCutoffWindow == window) return;
    _deadlineCutoffWindow = window;
    _notify();
  }

  AgendaEntry _present(AgendaEntry entry) =>
      entry.withDeadlineCutoff(_deadlineCutoffWindow);

  bool get ready => _ready;
  bool get busy => _busy;

  Iterable<AgendaEntry> get entries =>
      _entries.where((entry) => !entry.deleted).map(_present);

  Iterable<AgendaEntry> get deletedDeadlines => _entries
      .where((entry) => entry.deleted && entry.isDeadline)
      .map(_present);

  List<AgendaEntry> pendingOn(DateTime date, {required DateTime now}) =>
      entries
          .where((entry) => !entry.isFinished(now) && entry.occursOn(date))
          .toList()
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

  Future<void> load() => _operations.run(() async {
    if (_disposed) return;
    _busy = true;
    _ready = false;
    _notify();
    try {
      _entries = List.unmodifiable(await _store.readAndMigrate());
      final completion = _completionUpdates(_entries, _now());
      if (completion.changed) {
        try {
          await _store.write(completion.entries);
          _entries = List.unmodifiable(completion.entries);
        } on Exception catch (failure, stack) {
          // Keep the unmigrated records on failure. A later reconciliation can
          // retry, rather than claiming the automatic opportunity was consumed.
          _reportError('迁移日程完成状态', failure, stack);
        }
      }
      _ready = true;
    } on Exception catch (failure, stack) {
      _reportError('读取日程', failure, stack);
    } finally {
      _busy = false;
      _notify();
      _scheduleCompletionClock();
    }
  });

  /// Metadata editors opt into retaining the latest completion state when their
  /// snapshot was opened before another completion action or clock transition.
  /// Ordinary save callers may still intentionally supply completion values.
  Future<bool> save(
    AgendaEntry entry, {
    bool preserveCompletion = false,
  }) => _write((entries) {
    final existing = entries.where((item) => item.id == entry.id).firstOrNull;
    final AgendaEntry next;
    if (preserveCompletion && existing != null && existing.kind == entry.kind) {
      next = entry.copyWith(
        done: existing.done,
        examAutoCompletionHandled: existing.examAutoCompletionHandled,
        completionSchemaVersion: existing.completionSchemaVersion,
      );
    } else if (existing != null &&
        existing.kind == AgendaKind.exam &&
        entry.kind == AgendaKind.exam &&
        existing.examAutoCompletionHandled) {
      next = entry.copyWith(
        examAutoCompletionHandled: true,
        // Preserve the existing guard for older callers without the marker.
        done: entry.examAutoCompletionHandled ? entry.done : existing.done,
      );
    } else {
      next = entry;
    }
    return [...entries.where((item) => item.id != entry.id), next];
  });

  /// Persist the user's intended value against the latest record, not an old
  /// sheet snapshot. Any manual exam choice consumes its automatic opportunity.
  Future<bool> setDone(String id, bool done) => _operations.run(() async {
    if (_disposed || !_ready) return false;
    final index = _entries.indexWhere(
      (entry) => entry.id == id && !entry.deleted,
    );
    if (index < 0) return false;
    final current = _entries[index];
    final handled = current.kind == AgendaKind.exam
        ? true
        : current.examAutoCompletionHandled;
    final version =
        current.completionSchemaVersion <
            AgendaEntry.currentCompletionSchemaVersion
        ? AgendaEntry.currentCompletionSchemaVersion
        : current.completionSchemaVersion;
    if (current.done == done &&
        current.examAutoCompletionHandled == handled &&
        current.completionSchemaVersion == version) {
      return true;
    }
    final next = [..._entries];
    next[index] = current.copyWith(
      done: done,
      examAutoCompletionHandled: handled,
      completionSchemaVersion: version,
    );
    return _commit(next);
  });

  /// Clock-aware transitions are serialized with edits and syncs. Getters and
  /// widget builds remain pure and cannot repeatedly re-complete reopened exams.
  Future<bool> reconcileExamCompletion({DateTime? now}) =>
      _operations.run(() async {
        if (_disposed || !_ready) return false;
        final updates = _completionUpdates(_entries, now ?? _now());
        if (!updates.changed) {
          _scheduleCompletionClock();
          return true;
        }
        return _commit(updates.entries);
      });

  /// The App owns activation (foreground only); this controller owns one timer.
  void setCompletionClockActive(bool active) {
    if (_disposed) return;
    _completionClockActive = active;
    _completionTimer?.cancel();
    _completionTimer = null;
    if (active) unawaited(reconcileExamCompletion());
  }

  void _scheduleCompletionClock() {
    _completionTimer?.cancel();
    _completionTimer = null;
    if (_disposed || !_ready || !_completionClockActive) return;
    final now = _now();
    final outstanding = _completionUpdates(_entries, now);
    DateTime? nextEnd;
    for (final entry in _entries) {
      if (entry.deleted ||
          entry.kind != AgendaKind.exam ||
          entry.examAutoCompletionHandled ||
          !entry.endsAt!.isAfter(now)) {
        continue;
      }
      if (nextEnd == null || entry.endsAt!.isBefore(nextEnd)) {
        nextEnd = entry.endsAt;
      }
    }
    // A failed write leaves its state untouched. Retry while foregrounded,
    // without a zero-delay loop that would hammer storage on persistent errors.
    final delay = outstanding.changed
        ? const Duration(seconds: 30)
        : nextEnd?.difference(now);
    if (delay == null) return;
    _completionTimer = Timer(delay, () {
      _completionTimer = null;
      unawaited(reconcileExamCompletion());
    });
  }

  /// Manually migrate old four-day DDL tails, including recycled entries.
  /// Returns zero without writing when repeated, or null if persistence fails.
  Future<int?> resetDefaultDeadlineTails() => _operations.run(() async {
    if (_disposed) return null;
    if (!_ready) {
      _reportNotReady();
      return null;
    }
    var count = 0;
    final next = <AgendaEntry>[];
    for (final entry in _entries) {
      if (entry.isDeadline && entry.tailDays == AgendaEntry.defaultTailDays) {
        count++;
        next.add(entry.copyWith(tailDays: null));
      } else {
        next.add(entry);
      }
    }
    if (count == 0) return 0;
    final saved = await _commit(next);
    return saved ? count : null;
  });

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
    final savedById = {
      for (final entry in entries)
        if (entry.kind == AgendaKind.exam && entry.term == term)
          entry.id: entry,
    };
    final edited = {
      for (final entry in savedById.values)
        if (entry.local) entry.id,
    };
    return [
      ...entries.where(
        (entry) =>
            entry.kind != AgendaKind.exam || entry.term != term || entry.local,
      ),
      for (final entry in exams)
        if (!edited.contains(entry.id))
          if (savedById[entry.id] case final saved?)
            entry.copyWith(
              done: saved.done,
              examAutoCompletionHandled: saved.examAutoCompletionHandled,
              completionSchemaVersion: saved.completionSchemaVersion,
            )
          else
            entry,
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
    if (_disposed) return false;
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
      final prepared = _completionUpdates(next, _now()).entries;
      await _store.write(prepared);
      _entries = List.unmodifiable(prepared);
      return true;
    } on RequestCancelled {
      rethrow;
    } on Exception catch (failure, stack) {
      _reportError('保存日程', failure, stack);
      return false;
    } finally {
      _busy = false;
      _notify();
      _scheduleCompletionClock();
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
    _completionTimer?.cancel();
    _completionTimer = null;
    super.dispose();
  }
}

({List<AgendaEntry> entries, bool changed}) _completionUpdates(
  List<AgendaEntry> entries,
  DateTime now,
) {
  var changed = false;
  final next = <AgendaEntry>[];
  for (final entry in entries) {
    var done = entry.done;
    var handled = entry.examAutoCompletionHandled;
    var version = entry.completionSchemaVersion;
    if (version < AgendaEntry.currentCompletionSchemaVersion) {
      // Old events were presented as finished solely because time elapsed.
      // Preserve that history exactly once, never again after an explicit undo.
      if (entry.kind == AgendaKind.event &&
          !entry.deleted &&
          entry.hasEnded(now)) {
        done = true;
      }
      version = AgendaEntry.currentCompletionSchemaVersion;
    }
    if (entry.kind == AgendaKind.exam && done) handled = true;
    if (entry.kind == AgendaKind.exam &&
        !entry.deleted &&
        !handled &&
        entry.hasEnded(now)) {
      done = true;
      handled = true;
    }
    if (done != entry.done ||
        handled != entry.examAutoCompletionHandled ||
        version != entry.completionSchemaVersion) {
      changed = true;
      next.add(
        entry.copyWith(
          done: done,
          examAutoCompletionHandled: handled,
          completionSchemaVersion: version,
        ),
      );
    } else {
      next.add(entry);
    }
  }
  return (entries: next, changed: changed);
}
