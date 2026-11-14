import '../core/json.dart';
import '../core/storage/json_file.dart';
import '../core/storage/schema.dart';
import 'model.dart';

typedef ScheduleLibrary = ({
  String? selectedTerm,
  Map<String, SemesterSchedule> schedules,
});

class ScheduleStore {
  final _file = const JsonFile('schedule.json');

  Future<ScheduleLibrary> readAndMigrate() async {
    final stored = await _file.read(_decode);
    if (stored == null) {
      return (
        selectedTerm: null,
        schedules: const <String, SemesterSchedule>{},
      );
    }
    if (stored.legacy) await write(stored.library);
    return stored.library;
  }

  ({ScheduleLibrary library, bool legacy}) _decode(Object? value) {
    final library = jsonObject(value, '课表');
    final version = storageSchemaVersion(library);
    final semesters = jsonObjectField(library, 'semesters');
    return (
      library: (
        selectedTerm: jsonStringFieldOrNull(library, 'selectedTerm'),
        schedules: {
          for (final entry in semesters.entries)
            entry.key: SemesterSchedule.fromJson(
              jsonObject(entry.value, 'semesters.${entry.key}'),
            ),
        },
      ),
      legacy: version < currentStorageSchemaVersion,
    );
  }

  Future<void> write(ScheduleLibrary library) async {
    await _file.write({
      'schemaVersion': currentStorageSchemaVersion,
      'selectedTerm': library.selectedTerm,
      'semesters': {
        for (final entry in library.schedules.entries)
          entry.key: entry.value.toJson(),
      },
    });
  }

  Future<void> clear() => _file.delete();
}
