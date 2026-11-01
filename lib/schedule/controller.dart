import 'package:flutter/foundation.dart';

import '../core/async/cancelable_request.dart';
import '../core/diagnostics.dart';
import 'model.dart';
import 'store.dart';

/// Owns saved semesters and the week currently being viewed.
class TimetableController extends ChangeNotifier {
  TimetableController(this._store);

  final ScheduleStore _store;
  final _schedules = <String, SemesterSchedule>{};
  Future<void> _operations = Future<void>.value();
  String? _selectedTerm;
  List<String> _terms = const [];
  int _week = 1;
  bool _ready = false;
  bool _busy = false;
  bool _disposed = false;

  bool get ready => _ready;
  bool get busy => _busy;
  int get week => _week;
  List<String> get terms => _terms;
  SemesterSchedule? get schedule => _schedules[_selectedTerm];
  Iterable<SemesterSchedule> get schedules => _schedules.values;
  List<int> get weeks => schedule?.weeks ?? const [];

  Future<void> load() => _serialize(() async {
    try {
      final library = await _store.read();
      _schedules
        ..clear()
        ..addAll(library.schedules);
      _selectedTerm = library.selectedTerm;
      _terms = List.unmodifiable(_schedules.keys);
      _ready = true;
      _goToCurrentWeek();
    } on Exception catch (failure, stack) {
      AppDiagnostics.instance.report('读取本地课表', failure, stack);
    }
    _notify();
  });

  void _goToCurrentWeek() {
    final current = schedule?.weekAt(campusNow()) ?? 1;
    _week = weeks.contains(current) ? current : weeks.firstOrNull ?? 1;
  }

  void selectWeek(int value) {
    final next = value.clamp(weeks.firstOrNull ?? 1, weeks.lastOrNull ?? 1);
    if (_week == next) return;
    _week = next;
    _notify();
  }

  void showCurrentWeek() {
    _goToCurrentWeek();
    _notify();
  }

  Future<bool> importSchedule(
    SemesterSchedule incoming,
    List<String> availableTerms, {
    void Function()? checkActive,
  }) => _serialize(() {
    final next = incoming.mergeLocalChanges(_schedules[incoming.term]);
    return _commit(
      next,
      availableTerms: availableTerms,
      resetWeek: true,
      checkActive: checkActive,
    );
  });

  Future<bool> saveCourse(
    Course course, {
    Course? replacing,
    SemesterSchedule? semester,
  }) => _serialize(() async {
    final current = semester == null
        ? schedule
        : _schedules[semester.term] ?? semester;
    if (current == null) return false;
    return _commit(
      current.copyWith(
        courses: [
          ...current.courses.where(
            (item) => item.id != course.id && item.id != replacing?.id,
          ),
          course,
        ],
      ),
    );
  });

  Future<bool> deleteCourse(Course course) => _serialize(() async {
    final current = schedule;
    if (current == null) return false;
    return _commit(
      current.copyWith(
        courses: [...current.courses.where((item) => item.id != course.id)],
      ),
    );
  });

  Future<bool> setWeekRange({required int first, required int last}) =>
      _serialize(() async {
        final current = schedule;
        if (current == null) return false;
        return _commit(current.copyWith(firstWeek: first, lastWeek: last));
      });

  Future<bool> selectTerm(
    String term, {
    required Future<bool> Function(String term) importTerm,
  }) {
    final saved = _schedules[term];
    return saved == null
        ? importTerm(term)
        : _serialize(() async {
            final current = _schedules[term];
            return current != null && await _commit(current);
          });
  }

  Future<bool> _commit(
    SemesterSchedule next, {
    List<String> availableTerms = const [],
    bool resetWeek = false,
    void Function()? checkActive,
  }) async {
    checkActive?.call();
    final changingTerm = _selectedTerm != next.term;
    final nextSchedules = {..._schedules, next.term: next};
    final nextTerms = List<String>.unmodifiable({
      ..._terms,
      ...availableTerms,
      next.term,
    });

    _busy = true;
    _notify();
    try {
      checkActive?.call();
      await _store.write((selectedTerm: next.term, schedules: nextSchedules));
      _schedules
        ..clear()
        ..addAll(nextSchedules);
      _selectedTerm = next.term;
      _terms = nextTerms;
      if (changingTerm || resetWeek) {
        _goToCurrentWeek();
      } else {
        _week = _week.clamp(next.weeks.first, next.weeks.last);
      }
      return true;
    } on RequestCancelled {
      rethrow;
    } on Exception catch (failure, stack) {
      AppDiagnostics.instance.report('保存课表', failure, stack);
      return false;
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<bool> clear() => _serialize(() async {
    _busy = true;
    _notify();
    try {
      await _store.clear();
      _schedules.clear();
      _selectedTerm = null;
      _terms = const [];
      _week = 1;
      return true;
    } on Exception catch (failure, stack) {
      AppDiagnostics.instance.report('删除本地课表', failure, stack);
      return false;
    } finally {
      _busy = false;
      _notify();
    }
  });

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _operations.then((_) => operation());
    _operations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
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
