import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../academics/controller.dart';
import '../agenda/controller.dart';
import '../automation/controller.dart';
import '../classrooms/repository.dart';
import '../core/diagnostics.dart';
import '../core/platform/system_palette.dart';
import '../extensions/controller.dart';
import '../extensions/store.dart';
import '../mooc/controller.dart';
import '../mooc/storage.dart';
import '../schedule/controller.dart';
import '../schedule/store.dart';
import '../school/controller.dart';
import '../school/service.dart';
import '../school/storage.dart';
import '../sources/builtin.dart';
import '../sources/host.dart';
import '../sources/registry.dart';
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
    SourceRegistry? sourceRegistry,
    ExtensionStore? extensionStore,
  }) : settings = AppSettingsController(
         preferences,
         systemPaletteSource: systemPaletteSource,
         coursePaletteLoader: coursePaletteLoader,
       ),
       timetable = TimetableController(store),
       sources = sourceRegistry ?? SourceRegistry() {
    automation = AutomationController(preferences, timetable, agenda);
    this.school = SchoolController(
      service: school,
      storage: schoolStorage,
      timetable: timetable,
      agenda: agenda,
      academics: academics,
      sources: sources,
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
    extensions = ExtensionController(sources: sources, store: extensionStore);
    sourceHost = SourceHost(
      registry: sources,
      loadSource: (definition) => extensions.sourceFor(definition),
    );
  }

  final AppSettingsController settings;
  final TimetableController timetable;
  final SourceRegistry sources;
  late final ExtensionController extensions;
  late final SourceHost sourceHost;
  late final AutomationController automation;
  late final SchoolController school;
  late final ClassroomRepository classrooms;
  final AgendaController agenda;
  final AcademicController academics;
  late final MoocController mooc;
  late final SyncController sync;
  bool _ready = false;

  bool get ready => _ready;

  Future<void> initialize() async {
    await extensions.load();
    await sources.load();
    await timetable.load();
    await settings.initialize();
    await school.loadAccount();
    await _connectSourceInstances();
    await agenda.load();
    await automation.initialize();
    await mooc.load();
    await academics.load(school.username);
    _ready = true;
    notifyListeners();
  }

  Future<void> _connectSourceInstances() async {
    try {
      for (final definitionId in [
        BuiltinSources.school,
        BuiltinSources.lexue,
        BuiltinSources.eclass,
        BuiltinSources.mooc,
      ]) {
        sources.ensureInstance(definitionId);
      }
      final username = school.username;
      if (username != null) {
        final account = await sources.ensureAccount(
          service: 'bit.school',
          identity: username,
          displayName: username,
        );
        for (final definitionId in [
          BuiltinSources.school,
          BuiltinSources.lexue,
          BuiltinSources.eclass,
        ]) {
          final instance = sources.ensureInstance(
            definitionId,
            accountId: account.id,
          );
          final legacy = 'instance:$definitionId';
          if (instance.id != legacy) {
            await timetable.rebindSourceInstance(legacy, instance.id);
            await agenda.rebindSourceInstance(legacy, instance.id);
          }
        }
      }
      sources.ensureInstance(BuiltinSources.physicsLab);
      await sources.persist();
    } catch (failure, stack) {
      AppDiagnostics.instance.report('初始化数据来源', failure, stack);
    }
  }

  @override
  void dispose() {
    automation.dispose();
    settings.dispose();
    sync.dispose();
    classrooms.dispose();
    school.dispose();
    mooc.dispose();
    timetable.dispose();
    sources.dispose();
    extensions.dispose();
    agenda.dispose();
    academics.dispose();
    super.dispose();
  }
}
