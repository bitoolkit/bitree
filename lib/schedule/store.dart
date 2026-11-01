import '../core/json.dart';
import '../core/platform/desktop_widget.dart';
import '../core/storage/json_file.dart';
import 'model.dart';

typedef ScheduleLibrary = ({
  String? selectedTerm,
  Map<String, SemesterSchedule> schedules,
});

class ScheduleStore {
  final _file = const JsonFile('schedule.json');

  Future<ScheduleLibrary> read() async =>
      await _file.read(_decode) ??
      (selectedTerm: null, schedules: const <String, SemesterSchedule>{});

  ScheduleLibrary _decode(Object? value) {
    final library = jsonObject(value, '课表');
    final semesters = jsonObjectField(library, 'semesters');
    return (
      selectedTerm: jsonStringFieldOrNull(library, 'selectedTerm'),
      schedules: {
        for (final entry in semesters.entries)
          entry.key: SemesterSchedule.fromJson(
            jsonObject(entry.value, 'semesters.${entry.key}'),
          ),
      },
    );
  }

  Future<void> write(ScheduleLibrary library) async {
    await _file.write({
      'selectedTerm': library.selectedTerm,
      'semesters': {
        for (final entry in library.schedules.entries)
          entry.key: entry.value.toJson(),
      },
    });
    refreshDesktopWidget();
  }

  Future<void> clear() async {
    await _file.delete();
    refreshDesktopWidget();
  }
}
