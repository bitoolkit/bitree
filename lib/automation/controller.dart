import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../agenda/controller.dart';
import '../agenda/model.dart';
import '../core/async/serial_queue.dart';
import '../core/diagnostics.dart';
import '../core/platform/desktop_widget.dart';
import '../schedule/controller.dart';
import '../schedule/model.dart';
import 'lua_filter.dart';
import 'projection.dart';

class AutomationController extends ChangeNotifier {
  AutomationController(
    this._preferences,
    this._timetable,
    this._agenda, {
    LuaFilterExecutor? executor,
    Future<void> Function(Map<String, dynamic>)? widgetPublisher,
  }) : _executor = executor ?? LuaFilterExecutor(),
       _widgetPublisher = widgetPublisher ?? publishDesktopWidgetData {
    _timetable.addListener(_refresh);
    _agenda.addListener(_refresh);
  }

  final SharedPreferencesAsync _preferences;
  final TimetableController _timetable;
  final AgendaController _agenda;
  final LuaFilterExecutor _executor;
  final Future<void> Function(Map<String, dynamic>) _widgetPublisher;
  final _writes = SerialQueue();
  AutomationProjection? _projection;
  String _source = '';
  String _fileName = '';
  bool _enabled = false;
  bool _loaded = false;
  bool _running = false;
  bool _disposed = false;
  String? _error;
  Duration? _executionDuration;
  String? _snapshot;
  int _revision = 0;
  Future<void> _pending = Future.value();

  String get source => _source;
  String get fileName => _fileName;
  bool get enabled => _enabled;
  bool get running => _running;
  String? get error => _error;
  Duration? get executionDuration => _executionDuration;
  Future<void> get settled => _pending;

  SemesterSchedule? get schedule {
    final raw = _timetable.schedule;
    if (raw == null) return null;
    final projected = _projection?.schedules[raw.term];
    // Semester dates and week bounds are host state, not script output. A
    // bounds-only edit need not rerun Lua or retain old semester metadata.
    return projected == null ? raw : raw.copyWith(courses: projected.courses);
  }

  List<AgendaEntry> get entries =>
      (_projection?.entries.values ?? _agenda.entries).toList();

  AutomationChanges get changes =>
      _projection?.changes ?? const AutomationChanges();

  List<AgendaEntry> pendingOn(DateTime date, {required DateTime now}) =>
      entries
          .where((entry) => !entry.isFinished(now) && entry.occursOn(date))
          .toList()
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

  int get hiddenCourses => _projection == null
      ? 0
      : _timetable.schedules.fold(0, (count, schedule) {
          final visible = _projection!.schedules[schedule.term]!.courses
              .map((course) => course.id)
              .toSet();
          return count +
              schedule.courses
                  .where((course) => !visible.contains(course.id))
                  .length;
        });
  int get hiddenDeadlines => _projection == null
      ? 0
      : _agenda.entries
            .where(
              (entry) =>
                  entry.isDeadline &&
                  !_projection!.entries.containsKey(entry.id),
            )
            .length;

  Future<void> initialize() async {
    try {
      final saved = await _preferences.getString('automation');
      if (saved != null) {
        final json = jsonDecode(saved) as Map<String, dynamic>;
        _source = json['source'] as String;
        _fileName = json['fileName'] as String;
        _enabled = json['enabled'] as bool;
      }
    } catch (failure, stack) {
      _source = '';
      _fileName = '';
      _enabled = false;
      AppDiagnostics.instance.report('读取自动化设置', failure, stack);
    }
    if (_disposed) return;
    _loaded = true;
    _refresh();
    await _pending;
  }

  Future<void> saveScript(String source, {String fileName = ''}) =>
      _writes.run(() async {
        if (utf8.encode(source).length > LuaFilterExecutor.maxScriptBytes) {
          throw const FormatException('Lua script exceeds 128 KiB.');
        }
        await _save(
          source: source,
          fileName: fileName,
          enabled: source.trim().isNotEmpty,
        );
      });

  Future<void> setEnabled(bool value) => _writes.run(() async {
    await _save(
      source: _source,
      fileName: _fileName,
      enabled: value && _source.trim().isNotEmpty,
    );
  });

  Future<void> _save({
    required String source,
    required String fileName,
    required bool enabled,
  }) async {
    await _preferences.setString(
      'automation',
      jsonEncode({'source': source, 'fileName': fileName, 'enabled': enabled}),
    );
    if (_disposed) return;
    _source = source;
    _fileName = fileName;
    _enabled = enabled;
    _snapshot = null;
    _refresh();
    await _pending;
  }

  void rerun() {
    _snapshot = null;
    _refresh();
  }

  void _refresh() {
    if (_disposed || !_loaded) return;
    final schedules = _timetable.schedules.toList();
    final entries = _agenda.entries.toList();
    final data = AutomationProjection.snapshot(schedules, entries);
    final snapshot = jsonEncode(data);
    if (_snapshot == snapshot) {
      if (!_running) _pending = _publishWidget();
      return;
    }
    _snapshot = snapshot;
    final revision = ++_revision;
    _executor.cancel();
    _projection = null;
    _error = null;
    _executionDuration = null;
    _running = _enabled && _source.trim().isNotEmpty;
    notifyListeners();
    final published = _publishWidget();
    if (!_running) {
      _pending = published;
      return;
    }
    _pending = _apply(revision, data, schedules, entries);
  }

  Future<void> _publishWidget() {
    final payload = <String, dynamic>{
      'schedule': schedule?.toJson(),
      'entries': [for (final entry in entries) entry.toJson()],
    };
    return _widgetPublisher(payload);
  }

  Future<void> _apply(
    int revision,
    Map<String, dynamic> data,
    List<SemesterSchedule> schedules,
    List<AgendaEntry> entries,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await _executor.run(_source, data);
      if (_disposed || revision != _revision) return;
      _projection = AutomationProjection.fromResult(result, schedules, entries);
    } on LuaFilterCancelled {
      return;
    } catch (failure) {
      if (_disposed || revision != _revision) return;
      _error = failure is TimeoutException
          ? 'Lua filter timed out (2 s).'
          : failure.toString();
    } finally {
      stopwatch.stop();
      if (!_disposed && revision == _revision) {
        _executionDuration = stopwatch.elapsed;
        _running = false;
        notifyListeners();
        await _publishWidget();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    _timetable.removeListener(_refresh);
    _agenda.removeListener(_refresh);
    _executor.cancel();
    super.dispose();
  }
}
