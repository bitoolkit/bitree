import 'dart:convert';

import '../core/async/cancelable_request.dart';
import '../core/async/read_cache.dart';
import '../core/time.dart';
import '../school/classrooms.dart';
import '../school/controller.dart';
import '../school/verification.dart';
import 'model.dart';

/// Shares school reads across query screens and invalidates them on account changes.
class ClassroomRepository {
  ClassroomRepository(this._school) : _account = _school.username {
    _school.addListener(_accountChanged);
  }

  final SchoolController _school;
  String? _account;
  final _directory = ReadCache<String, ClassroomDirectory?>(
    maxAge: const Duration(days: 1),
  );
  final _occupancy =
      ReadCache<
        ({String account, DateTime date, String buildings}),
        List<BuildingOccupancy>?
      >(maxAge: const Duration(minutes: 5));

  void _accountChanged() {
    if (_account == _school.username) return;
    _account = _school.username;
    _directory.clear();
    _occupancy.clear();
  }

  Future<ClassroomDirectory?> directory({
    required VerifySchoolLogin verify,
    bool refresh = false,
    CancellationToken? cancellation,
  }) async {
    Future<ClassroomDirectory?> load() => _school.read(
      '加载教学楼',
      fetchClassroomDirectory,
      verify: verify,
      cancellation: cancellation,
    );
    final account = _school.username;
    final result = account == null
        ? await load()
        : await _directory.read(account, load, refresh: refresh);
    if (refresh && result != null) _occupancy.clear();
    return result;
  }

  Future<List<BuildingOccupancy>?> occupancy({
    required List<SchoolBuilding> buildings,
    required DateTime date,
    required VerifySchoolLogin verify,
    bool refresh = false,
    CancellationToken? cancellation,
  }) {
    final day = calendarDate(date);
    Future<List<BuildingOccupancy>?> load() => _school.read(
      '查询空教室',
      (session) =>
          fetchClassroomOccupancy(session, buildings: buildings, date: day),
      verify: verify,
      cancellation: cancellation,
    );
    final account = _school.username;
    if (account == null) return load();
    final codes = buildings.map((building) => building.code).toList()..sort();
    return _occupancy.read(
      (account: account, date: day, buildings: jsonEncode(codes)),
      load,
      refresh: refresh,
    );
  }

  void dispose() => _school.removeListener(_accountChanged);
}
