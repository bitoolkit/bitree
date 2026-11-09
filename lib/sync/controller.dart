import 'dart:async';

import 'package:flutter/foundation.dart';

import '../agenda/controller.dart';
import '../agenda/deadline_source.dart';
import '../core/async/cancelable_request.dart';
import '../mooc/controller.dart';
import '../mooc/progress.dart';
import '../schedule/controller.dart';
import '../school/controller.dart';
import '../sources/builtin.dart';
import '../sources/course_selection.dart';
import '../sources/registry.dart';
import '../sources/source.dart';
import '../sources/sync.dart';

enum SyncTarget {
  schedule,
  exams,
  grades,
  studyPlan,
  lexue(DeadlineSource.lexue),
  eclass(DeadlineSource.eclass),
  mooc(DeadlineSource.mooc),
  physicsLab,

  /// Every enabled course source added by an extension.
  extensionSources;

  const SyncTarget([this.source]);
  final DeadlineSource? source;

  bool get usesSchoolSession => switch (this) {
    schedule || exams || grades || studyPlan || lexue || eclass => true,
    mooc || physicsLab || extensionSources => false,
  };

  SyncCategory get category => switch (this) {
    schedule || exams || grades || studyPlan => SyncCategory.schoolData,
    lexue ||
    eclass ||
    mooc ||
    physicsLab ||
    extensionSources => SyncCategory.deadlineData,
  };

  bool get isAcademicRecord => this == grades || this == studyPlan;

  /// The data source whose settings decide how this target is read.
  String? get definitionId => switch (this) {
    lexue => BuiltinSources.lexue,
    eclass => BuiltinSources.eclass,
    mooc => BuiltinSources.mooc,
    _ => null,
  };
}

SyncTarget? syncTargetForDefinition(String definitionId) => SyncTarget.values
    .where((target) => target.definitionId == definitionId)
    .firstOrNull;

enum SyncCategory { schoolData, deadlineData }

enum SyncOutcome {
  synced,
  failed,
  needsLogin,
  needsVerification,
  cancelled,
  noSchedule,
  saveFailed,
}

class SyncResult {
  const SyncResult(this.outcome, {this.count, this.detail});

  final SyncOutcome outcome;
  final int? count;
  final Object? detail;
}

/// An extension source that did not finish; its name is localized on display.
class SourceSyncIssue {
  const SourceSyncIssue(this.source, this.message);

  final LocalizedSourceName source;
  final String message;
}

/// Owns one synchronization round. School reads share a session and run in
/// sequence; MOOC runs alongside them. There is no persistent task queue.
/// Learning platforms follow their data source: disabled sources are left
/// out, only selected courses are read, and an extension implementation
/// replaces the built-in reader.
class SyncController extends ChangeNotifier {
  SyncController({
    required this._school,
    required this._mooc,
    required this._timetable,
    required this._agenda,
    required this._sources,
    required this._sourceSync,
  }) {
    _school.addListener(_notify);
    _mooc.addListener(_notify);
    _sources.addListener(_notify);
  }
  final SchoolController _school;
  final MoocController _mooc;
  final TimetableController _timetable;
  final AgendaController _agenda;
  final SourceRegistry _sources;
  final SourceSync _sourceSync;
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
      if (target == SyncTarget.extensionSources
          ? _extensionSources.isNotEmpty
          : !target.isAcademicRecord && (_instanceFor(target)?.enabled ?? true))
        target,
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

  SourceInstance? _instanceFor(SyncTarget target) {
    final definitionId = target.definitionId;
    if (definitionId == null) return null;
    final username = _school.username;
    final bound = target.usesSchoolSession && username != null
        ? _sources.instanceForAccount(definitionId, 'bit.school:$username')
        : null;
    return bound ??
        _sources.instances
            .where((instance) => instance.definitionId == definitionId)
            .firstOrNull;
  }

  /// Enabled sources an extension added that list courses to read.
  List<SourceInstance> get _extensionSources => [
    for (final instance in _sources.instances)
      if (instance.enabled &&
          _sources.catalog[instance.definitionId]?.builtin == false &&
          _sources
              .definitionFor(instance)
              .supports(SourceOperation.coursesList))
        instance,
  ];

  CourseChooser? _chooserFor(SourceInstance? instance) => instance == null
      ? null
      : (discovered) async {
          await _sources.mergeDiscoveredCourses(instance.id, discovered);
          return _sources.selection(instance.id).selectedCourses;
        };

  Future<bool> synchronize(Set<SyncTarget> selected, {String? term}) {
    if (_operation case final current?) return current;
    assert(!_disposed && selected.isNotEmpty);
    final finished = Completer<bool>();
    _operation = finished.future;
    _cancelledSignal = Completer<void>();
    _cancelled = false;
    _term = term;
    _targets = List.unmodifiable(SyncTarget.values.where(selected.contains));
    _results.clear();
    _notify();
    unawaited(_run().then(finished.complete, onError: finished.completeError));
    return finished.future;
  }

  Future<bool> _run() async {
    try {
      await Future.wait([
        _syncSchoolAndLab(_term),
        if (_targets.contains(SyncTarget.mooc)) _syncMooc(),
        if (_targets.contains(SyncTarget.extensionSources))
          _syncExtensionSources(),
      ]);
      return !_cancelled && incompleteTargets.isEmpty;
    } finally {
      if (_cancelled) {
        for (final target in _targets) {
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

  Future<void> _syncSchoolAndLab(String? term) async {
    for (final target in _targets.where((target) => target.usesSchoolSession)) {
      while (_school.busy && !_cancelled) {
        await Future.any([_school.idle, _cancelledSignal!.future]);
      }
      if (_cancelled) break;
      if (_school.verificationRequired ||
          _school.loginExpired ||
          _school.username == null) {
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
        _results[target] = await _syncSchoolTarget(target, term);
      } finally {
        _running.remove(target);
        _notify();
      }
    }
    if (!_cancelled && _targets.contains(SyncTarget.physicsLab)) {
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

  Future<SyncResult> _syncSchoolTarget(SyncTarget target, String? term) async {
    final instance = _instanceFor(target);
    if (instance != null && instance.implementationId != null) {
      return _syncWithSource(instance);
    }
    final success = await switch (target) {
      SyncTarget.schedule => _school.synchronize(term: term),
      SyncTarget.exams => _school.importExams(term: term),
      SyncTarget.grades => _school.importGrades(),
      SyncTarget.studyPlan => _school.importStudyPlan(),
      SyncTarget.lexue || SyncTarget.eclass => _school.importDeadlines(
        source: target.source!,
        chooseCourses: _chooserFor(instance),
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
    return SyncResult(outcome, detail: success ? null : _school.error);
  }

  Future<SyncResult> _syncWithSource(SourceInstance instance) async {
    try {
      final result = await _sourceSync.synchronize(
        instance,
        isCancelled: () => _cancelled,
      );
      return SyncResult(
        result.complete ? SyncOutcome.synced : SyncOutcome.failed,
        count: result.deadlineCount,
        detail: result.complete
            ? null
            : [
                for (final failure in result.failures)
                  '${failure.course}：${failure.error}',
              ].join('\n'),
      );
    } on RequestCancelled {
      return const SyncResult(SyncOutcome.cancelled);
    } on Exception catch (error) {
      return SyncResult(SyncOutcome.failed, detail: error);
    }
  }

  Future<void> _syncExtensionSources() async {
    _running.add(SyncTarget.extensionSources);
    _notify();
    try {
      var count = 0;
      final issues = <SourceSyncIssue>[];
      for (final instance in _extensionSources) {
        if (_cancelled) return;
        final result = await _syncWithSource(instance);
        count += result.count ?? 0;
        if (result.outcome == SyncOutcome.failed) {
          issues.add(
            SourceSyncIssue(
              _sources.catalog[instance.definitionId]!.name,
              '${result.detail}',
            ),
          );
        }
      }
      if (!_cancelled) {
        _results[SyncTarget.extensionSources] = SyncResult(
          issues.isEmpty ? SyncOutcome.synced : SyncOutcome.failed,
          count: count,
          detail: issues.isEmpty ? null : issues,
        );
      }
    } finally {
      _running.remove(SyncTarget.extensionSources);
      _notify();
    }
  }

  Future<void> _syncMooc() async {
    _running.add(SyncTarget.mooc);
    _notify();
    try {
      final instance = _instanceFor(SyncTarget.mooc);
      if (instance != null && instance.implementationId != null) {
        final result = await _syncWithSource(instance);
        if (!_cancelled) _results[SyncTarget.mooc] = result;
        return;
      }
      final result = await _mooc.synchronize(
        chooseCourses: _chooserFor(instance),
      );
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
    _sources.removeListener(_notify);
    cancel();
    super.dispose();
  }
}
