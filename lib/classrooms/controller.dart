import 'package:flutter/foundation.dart';

import '../core/async/cancelable_request.dart';
import '../schedule/model.dart';
import '../school/controller.dart';
import '../school/verification.dart';
import 'model.dart';
import 'repository.dart';

const wenCuiBuildingFilter = 'group:wencui';
String buildingFilterKey(SchoolBuilding building) =>
    'building:${building.code}';

/// Owns query inputs, cancellation and results. Widgets only choose inputs.
class ClassroomController extends ChangeNotifier {
  ClassroomController({
    required this._repository,
    required this._school,
    required this._verify,
    required this._signIn,
    required DateTime date,
  }) : _date = calendarDate(date);

  final ClassroomRepository _repository;
  final SchoolController _school;
  final VerifySchoolLogin _verify;
  final Future<bool> Function() _signIn;
  final _requests = LatestRequest();
  ClassroomDirectory? _directory;
  String? _campusCode;
  String? _buildingFilter;
  DateTime _date;
  ClassroomPeriod? _period;
  List<BuildingOccupancy>? _occupancy;
  bool _busy = false;
  bool _disposed = false;

  ClassroomDirectory? get directory => _directory;
  String? get campusCode => _campusCode;
  String? get buildingFilter => _buildingFilter;
  DateTime get date => _date;
  ClassroomPeriod? get period => _period;
  bool get busy => _busy;
  bool get hasResult => _occupancy != null;
  List<SchoolBuilding> get buildings => [
    for (final building in _directory?.buildings ?? <SchoolBuilding>[])
      if (building.campusCode == _campusCode) building,
  ];

  bool _matchesBuilding(SchoolBuilding building) =>
      _buildingFilter == null ||
      (_buildingFilter == wenCuiBuildingFilter
          ? building.isWenCui
          : _buildingFilter == buildingFilterKey(building));

  List<BuildingOccupancy> get results {
    final groups = <BuildingOccupancy>[];
    for (final group in _occupancy ?? <BuildingOccupancy>[]) {
      if (!_matchesBuilding(group.building)) continue;
      final rooms = group.rooms.where(_matchesPeriod).toList();
      if (rooms.isNotEmpty) {
        groups.add(BuildingOccupancy(building: group.building, rooms: rooms));
      }
    }
    return groups;
  }

  bool _matchesPeriod(ClassroomOccupancy room) => _period == null
      ? room.freePeriods.isNotEmpty
      : room.freePeriod(_period!.start, _period!.end) != null;

  Future<T?> _withLogin<T>(
    CancellationToken cancellation,
    Future<T?> Function() read,
  ) async {
    if (_school.username == null) {
      if (!await _signIn()) return null;
      cancellation.check();
    }
    var result = await read();
    cancellation.check();
    if (result == null && _school.loginExpired) {
      if (!await _signIn()) return null;
      cancellation.check();
      result = await read();
    }
    return result;
  }

  Future<void> _run(Future<void> Function(CancellationToken) query) async {
    if (_disposed) return;
    _busy = true;
    _notify();
    try {
      await _requests.run((cancellation) async {
        try {
          await query(cancellation);
        } finally {
          if (!cancellation.isCancelled) {
            _busy = false;
            _notify();
          }
        }
      });
    } on RequestCancelled {
      // A newer query owns the busy state.
    }
  }

  Future<void> load({bool refresh = false}) => _run((cancellation) async {
    final result = await _withLogin(
      cancellation,
      () => _repository.directory(
        verify: _verify,
        refresh: refresh,
        cancellation: cancellation,
      ),
    );
    cancellation.check();
    if (result == null) return;
    _directory = result;
    if (!result.campuses.any((campus) => campus.code == _campusCode)) {
      _campusCode =
          result.campuses
              .where((campus) => campus.name.contains('良乡'))
              .firstOrNull
              ?.code ??
          result.campuses.firstOrNull?.code;
      _occupancy = null;
    }
    if (!buildings.any(_matchesBuilding)) _buildingFilter = null;
    _notify();
    await _fetch(cancellation, refresh: refresh);
  });

  Future<void> query({bool refresh = false}) =>
      _run((cancellation) => _fetch(cancellation, refresh: refresh));

  Future<void> _fetch(
    CancellationToken cancellation, {
    required bool refresh,
  }) async {
    if (_campusCode == null) return;
    final selected = buildings;
    if (selected.isEmpty) {
      _occupancy = const [];
      return;
    }
    final result = await _withLogin(
      cancellation,
      () => _repository.occupancy(
        buildings: selected,
        date: _date,
        verify: _verify,
        refresh: refresh,
        cancellation: cancellation,
      ),
    );
    cancellation.check();
    if (result != null) _occupancy = result;
  }

  Future<void> selectCampus(String code) async {
    if (_campusCode == code) return;
    _campusCode = code;
    _buildingFilter = null;
    _occupancy = null;
    await query();
  }

  Future<void> selectDate(DateTime date) async {
    final selected = calendarDate(date);
    if (_date == selected) return;
    _date = selected;
    _occupancy = null;
    await query();
  }

  void selectBuilding(String? value) {
    _buildingFilter = value;
    _notify();
  }

  void selectPeriod(ClassroomPeriod? value) {
    _period = value;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _requests.cancel();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}
