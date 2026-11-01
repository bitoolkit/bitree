import '../schedule/section_times.dart';

typedef ClassroomPeriod = ({int start, int end});

extension ClassroomPeriodLabels on ClassroomPeriod {
  bool contains(int section) => start <= section && section <= end;

  bool includes(ClassroomPeriod other) =>
      start <= other.start && end >= other.end;
}

int? currentClassroomSection(DateTime now) {
  int minutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  final minute = now.hour * 60 + now.minute;
  final index = sectionTimes.indexWhere(
    (time) => minutes(time.$1) <= minute && minute < minutes(time.$2),
  );
  return index < 0 ? null : index + 1;
}

class SchoolCampus {
  const SchoolCampus({required this.code, required this.name});

  final String code;
  final String name;
}

class SchoolBuilding {
  const SchoolBuilding({
    required this.code,
    required this.name,
    required this.campusCode,
  });

  final String code;
  final String name;
  final String? campusCode;

  bool get isWenCui => name.trim().startsWith('文萃楼');
}

class ClassroomDirectory {
  const ClassroomDirectory({required this.campuses, required this.buildings});

  final List<SchoolCampus> campuses;
  final List<SchoolBuilding> buildings;
}

class BuildingOccupancy {
  const BuildingOccupancy({required this.building, required this.rooms});

  final SchoolBuilding building;
  final List<ClassroomOccupancy> rooms;
}

class ClassroomOccupancy {
  const ClassroomOccupancy({required this.name, required this.busySections});

  final String name;
  final Set<int> busySections;

  List<({ClassroomPeriod period, bool busy})> get periods {
    final result = <({ClassroomPeriod period, bool busy})>[];
    for (var section = 1; section <= sectionTimes.length; section++) {
      final busy = busySections.contains(section);
      if (result.isNotEmpty && result.last.busy == busy) {
        final previous = result.removeLast();
        result.add((
          period: (start: previous.period.start, end: section),
          busy: busy,
        ));
      } else {
        result.add((period: (start: section, end: section), busy: busy));
      }
    }
    return result;
  }

  List<ClassroomPeriod> get freePeriods => [
    for (final block in periods)
      if (!block.busy) block.period,
  ];

  /// The continuous free period containing the entire requested range.
  ClassroomPeriod? freePeriod(int start, int end) => freePeriods
      .where((period) => period.includes((start: start, end: end)))
      .firstOrNull;
}
