import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../academics/controller.dart';
import '../agenda/controller.dart';
import '../classrooms/repository.dart';
import '../core/platform/system_palette.dart';
import '../mooc/controller.dart';
import '../mooc/storage.dart';
import '../schedule/controller.dart';
import '../schedule/store.dart';
import '../school/controller.dart';
import '../school/service.dart';
import '../school/storage.dart';
import '../sync/controller.dart';
import '../ui/course_palette.dart';
import 'settings_controller.dart';

/// Composes feature state and owns application startup.
/// Feature changes are observed by their views, not relayed through this object.
class AppController extends ChangeNotifier {
  AppController({
    required ScheduleStore store,
    required SchoolService school,
    required SchoolStorage schoolStorage,
    required SharedPreferencesAsync preferences,
    required this.agenda,
    required this.academics,
    SystemPaletteSource? systemPaletteSource,
    Future<Map<String, CoursePalette>> Function()? coursePaletteLoader,
    MoocStorage? moocStorage,
  }) : settings = AppSettingsController(
         preferences,
         systemPaletteSource: systemPaletteSource,
         coursePaletteLoader: coursePaletteLoader,
       ),
       timetable = TimetableController(store) {
    this.school = SchoolController(
      service: school,
      storage: schoolStorage,
      timetable: timetable,
      agenda: agenda,
      academics: academics,
    );
    classrooms = ClassroomRepository(this.school);
    mooc = MoocController(
      storage: moocStorage ?? MoocStorage(),
      agenda: agenda,
    );
    sync = SyncController(
      school: this.school,
      mooc: mooc,
      timetable: timetable,
      agenda: agenda,
    );
    settings.deadlineCutoff.addListener(_updateDeadlineCutoff);
    _updateDeadlineCutoff();
  }

  void _updateDeadlineCutoff() =>
      agenda.setDeadlineCutoff(settings.deadlineCutoff.value);

  final AppSettingsController settings;
  final TimetableController timetable;
  late final SchoolController school;
  late final ClassroomRepository classrooms;
  final AgendaController agenda;
  final AcademicController academics;
  late final MoocController mooc;
  late final SyncController sync;
  bool _ready = false;

  bool get ready => _ready;

  Future<void> initialize() async {
    await timetable.load();
    await settings.initialize();
    await school.loadAccount();
    await agenda.load();
    await mooc.load();
    await academics.load(school.username);
    _ready = true;
    notifyListeners();
  }

  @override
  void dispose() {
    settings.deadlineCutoff.removeListener(_updateDeadlineCutoff);
    settings.dispose();
    sync.dispose();
    classrooms.dispose();
    school.dispose();
    mooc.dispose();
    timetable.dispose();
    agenda.dispose();
    academics.dispose();
    super.dispose();
  }
}
