import 'dart:async';

import 'package:flutter/foundation.dart';

import '../agenda/controller.dart';
import '../agenda/deadline_source.dart';
import '../core/async/cancelable_request.dart';
import '../mooc/controller.dart';
import '../mooc/progress.dart';
import '../schedule/controller.dart';
import '../school/controller.dart';
import '../school/verification.dart';
import 'model.dart';

export 'model.dart';

/// Owns one synchronization round. School reads share a session and run in
/// sequence; MOOC runs alongside them. There is no persistent task queue.
class SyncController extends ChangeNotifier {
  SyncController({
    required this._school,
    required this._mooc,
    required this._timetable,
    required this._agenda,
  }) {
    _school.addListener(_notify);
    _mooc.addListener(_notify);
  }
  final SchoolController _school;
  final MoocController _mooc;
  final TimetableController _timetable;
  final AgendaController _agenda;
  Future<bool>? _operation;
  Completer<void>? _cancelledSignal;
  bool _disposed = false;
  bool _cancelled = false;
  String? _term;
  List<SyncTarget> _targets = const [];
  final _results = <SyncTarget, SyncResult>{};
  final _running = <SyncTarget>{};

  bool get busy => _operation != null;
  bool get cancelled => _cancelled;
  bool get waitingForSchool => _school.busy;
  MoocProgress? get moocProgress => _mooc.progress;
  String? get term => _term;
  List<SyncTarget> get targets => _targets;
  Map<SyncTarget, SyncResult> get results => Map.unmodifiable(_results);
  Set<SyncTarget> get bulkTargets => {
    for (final target in SyncTarget.values)
      if (!target.isAcademicRecord) target,
  };
  Set<SyncTarget> get defaultTargets => {
    for (final target in bulkTargets)
      if (target != SyncTarget.mooc || !_mooc.needsLogin) target,
  };
  Set<SyncTarget> get incompleteTargets => {
    for (final target in _targets)
      if (_results[target]?.outcome != SyncOutcome.synced) target,
  };
  bool isRunning(SyncTarget target) => _running.contains(target);

  Future<bool> synchronize(
    Set<SyncTarget> selected, {
    String? term,
    VerifySchoolLogin? verify,
  }) {
    if (_operation case final current?) return current;
    assert(!_disposed && selected.isNotEmpty);
    _term = term;
    _targets = List.unmodifiable(SyncTarget.values.where(selected.contains));
    _results.clear();
    return _start(_targets, verify: verify);
  }

  Future<bool> retryIncomplete() {
    if (_operation case final current?) return current;
    final selected = incompleteTargets.toList();
    if (selected.isEmpty) return Future.value(true);
    return _start(selected);
  }

  Future<bool> _start(List<SyncTarget> selected, {VerifySchoolLogin? verify}) {
    assert(!_disposed);
    final finished = Completer<bool>();
    _operation = finished.future;
    _cancelledSignal = Completer<void>();
    _cancelled = false;
    for (final target in selected) {
      _results.remove(target);
    }
    _notify();
    unawaited(
      _run(
        selected,
        verify,
      ).then(finished.complete, onError: finished.completeError),
    );
    return finished.future;
  }

  Future<bool> _run(
    List<SyncTarget> selected,
    VerifySchoolLogin? verify,
  ) async {
    try {
      await Future.wait([
        _syncSchoolAndLab(selected, verify),
        if (selected.contains(SyncTarget.mooc)) _syncMooc(),
      ]);
      return !_cancelled && incompleteTargets.isEmpty;
    } finally {
      if (_cancelled) {
        for (final target in selected) {
          _results.putIfAbsent(
            target,
            () => const SyncResult(SyncOutcome.cancelled),
          );
        }
      }
      _operation = null;
      _cancelledSignal = null;
      _notify();
    }
  }

  Future<void> _syncSchoolAndLab(
    List<SyncTarget> selected,
    VerifySchoolLogin? verify,
  ) async {
    final term = _term;
    for (final target in selected.where((target) => target.usesSchoolSession)) {
      while (_school.busy && !_cancelled) {
        await Future.any([_school.idle, _cancelledSignal!.future]);
      }
      if (_cancelled) break;
      if (_school.loginExpired ||
          _school.username == null ||
          (_school.verificationRequired && verify == null)) {
        _results[target] = SyncResult(
          _school.verificationRequired
              ? SyncOutcome.needsVerification
              : SyncOutcome.needsLogin,
        );
        _notify();
        continue;
      }
      _running.add(target);
      _notify();
      try {
        final success = await switch (target) {
          SyncTarget.schedule => _school.synchronize(
            term: term,
            verify: verify,
          ),
          SyncTarget.exams => _school.importExams(term: term, verify: verify),
          SyncTarget.grades => _school.importGrades(verify: verify),
          SyncTarget.studyPlan => _school.importStudyPlan(verify: verify),
          SyncTarget.lexue => _school.importDeadlines(
            source: DeadlineSource.lexue,
            verify: verify,
          ),
          SyncTarget.eclass => _school.importDeadlines(
            source: DeadlineSource.eclass,
            verify: verify,
          ),
          _ => throw StateError('不是学校同步内容'),
        };
        final outcome = _cancelled
            ? SyncOutcome.cancelled
            : success
            ? SyncOutcome.synced
            : _school.verificationRequired || _school.loginExpired
            ? _school.verificationRequired
                  ? SyncOutcome.needsVerification
                  : SyncOutcome.needsLogin
            : SyncOutcome.failed;
        _results[target] = SyncResult(
          outcome,
          detail: success ? null : _school.error,
        );
      } finally {
        _running.remove(target);
        _notify();
      }
    }
    if (!_cancelled && selected.contains(SyncTarget.physicsLab)) {
      _running.add(SyncTarget.physicsLab);
      _notify();
      try {
        final schedule = _timetable.schedule;
        final count = schedule == null
            ? null
            : await _agenda.updatePhysicsLabDeadlines(
                schedule,
                checkActive: _checkActive,
              );
        _results[SyncTarget.physicsLab] = SyncResult(
          schedule == null
              ? SyncOutcome.noSchedule
              : count == null
              ? SyncOutcome.saveFailed
              : SyncOutcome.synced,
          count: count,
        );
      } on RequestCancelled {
        // The round records cancelled content after all running reads stop.
      } finally {
        _running.remove(SyncTarget.physicsLab);
        _notify();
      }
    }
  }

  Future<void> _syncMooc() async {
    if (_mooc.needsLogin) {
      _results[SyncTarget.mooc] = const SyncResult(SyncOutcome.needsLogin);
      _notify();
      return;
    }
    _running.add(SyncTarget.mooc);
    _notify();
    try {
      final result = await _mooc.synchronize();
      if (!_cancelled) {
        _results[SyncTarget.mooc] = SyncResult(
          result == null || result.failures.isNotEmpty
              ? SyncOutcome.failed
              : SyncOutcome.synced,
          count: result?.entries.length,
          detail: result == null
              ? _mooc.error
              : result.failures.isEmpty
              ? null
              : [
                  for (final failure in result.failures)
                    '${failure.course}：${failure.message}',
                ].join('\n'),
        );
      }
    } on RequestCancelled {
      cancel();
    } on Exception {
      if (!_cancelled) {
        _results[SyncTarget.mooc] = SyncResult(
          _mooc.needsLogin ? SyncOutcome.needsLogin : SyncOutcome.failed,
          detail: _mooc.error,
        );
      }
    } finally {
      _running.remove(SyncTarget.mooc);
      _notify();
    }
  }

  void _checkActive() {
    if (_cancelled) throw const RequestCancelled();
  }

  void cancel() {
    if (!busy || _cancelled) return;
    _cancelled = true;
    _cancelledSignal!.complete();
    if (_running.any((target) => target.usesSchoolSession)) _school.cancel();
    if (_running.contains(SyncTarget.mooc)) _mooc.cancel();
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _school.removeListener(_notify);
    _mooc.removeListener(_notify);
    cancel();
    super.dispose();
  }
}
