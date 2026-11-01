import 'package:bitree/academics/controller.dart';
import 'package:bitree/academics/model.dart';
import 'package:bitree/academics/store.dart';
import 'package:bitree/agenda/controller.dart';
import 'package:bitree/agenda/model.dart';
import 'package:bitree/agenda/store.dart';
import 'package:bitree/app/controller.dart';
import 'package:bitree/mooc/credentials.dart';
import 'package:bitree/mooc/storage.dart';
import 'package:bitree/schedule/model.dart';
import 'package:bitree/schedule/store.dart';
import 'package:bitree/school/network.dart';
import 'package:bitree/school/service.dart';
import 'package:bitree/school/storage.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoryScheduleStore extends ScheduleStore {
  MemoryScheduleStore({
    List<SemesterSchedule> schedules = const [],
    SemesterSchedule? selected,
  }) : schedules = {for (final schedule in schedules) schedule.term: schedule},
       selectedTerm = selected?.term ?? schedules.firstOrNull?.term {
    if (selected != null) this.schedules[selected.term] = selected;
  }

  final Map<String, SemesterSchedule> schedules;
  String? selectedTerm;

  @override
  Future<ScheduleLibrary> read() async =>
      (selectedTerm: selectedTerm, schedules: Map.of(schedules));

  @override
  Future<void> write(ScheduleLibrary library) async {
    schedules
      ..clear()
      ..addAll(library.schedules);
    selectedTerm = library.selectedTerm;
  }

  @override
  Future<void> clear() async {
    schedules.clear();
    selectedTerm = null;
  }
}

class MemoryAgendaStore extends AgendaStore {
  MemoryAgendaStore([this.entries = const []]);
  List<AgendaEntry> entries;
  @override
  Future<List<AgendaEntry>> read() async => entries;
  @override
  Future<void> write(List<AgendaEntry> entries) async =>
      this.entries = List.of(entries);
}

class MemoryAcademicStore extends AcademicStore {
  final accounts = <String, AcademicRecord>{};
  @override
  Future<AcademicRecord> read(String account) async =>
      accounts[account] ?? const AcademicRecord();
  @override
  Future<void> write(String account, AcademicRecord record) async =>
      accounts[account] = record;
}

class MemoryPreferences extends Fake implements SharedPreferencesAsync {
  MemoryPreferences([Map<String, String> values = const {}])
    : _values = Map.of(values);

  final Map<String, String> _values;

  String? value(String key) => _values[key];

  @override
  Future<String?> getString(String key) async => _values[key];
  @override
  Future<void> setString(String key, String value) async =>
      _values[key] = value;
}

class MemorySchoolStorage extends SchoolStorage {
  MemorySchoolStorage({this.credentials});
  SchoolCredentials? credentials;
  final _cookies = <SchoolNetwork, CookieJar>{};

  CookieJar _cookiesFor(SchoolNetwork network) =>
      _cookies.putIfAbsent(network, CookieJar.new);

  @override
  Future<List<Cookie>> cookiesFor(SchoolNetwork network, Uri source) =>
      _cookiesFor(network).loadForRequest(source);
  @override
  Future<void> saveCookies(
    SchoolNetwork network,
    Uri source,
    List<Cookie> cookies,
  ) => _cookiesFor(network).saveFromResponse(source, cookies);
  @override
  Future<void> clearSession(SchoolNetwork network) async =>
      _cookies.remove(network);
  @override
  Future<SchoolCredentials?> readCredentials() async => credentials;
  @override
  Future<void> saveCredentials(SchoolCredentials credentials) async =>
      this.credentials = credentials;
  @override
  Future<void> clear() async {
    credentials = null;
    _cookies.clear();
  }
}

/// Uses production controllers; only persistence and platform boundaries are in memory.
class TestAppController extends AppController {
  TestAppController({
    SemesterSchedule? schedule,
    List<SemesterSchedule> schedules = const [],
    this.initialWeek,
    AgendaController? agenda,
    List<AgendaEntry> entries = const [],
    MemorySchoolStorage? schoolStorage,
    MoocStorage? moocStorage,
    SchoolService? school,
    SharedPreferencesAsync? preferences,
    ScheduleStore? scheduleStore,
    AcademicStore? academicStore,
  }) : super(
         store:
             scheduleStore ??
             MemoryScheduleStore(schedules: schedules, selected: schedule),
         school: school ?? SchoolService(),
         schoolStorage: schoolStorage ?? MemorySchoolStorage(),
         preferences: preferences ?? MemoryPreferences(),
         moocStorage: moocStorage ?? MemoryMoocStorage(),
         agenda: agenda ?? AgendaController(MemoryAgendaStore(entries)),
         academics: AcademicController(academicStore ?? MemoryAcademicStore()),
       ) {
    addTearDown(dispose);
  }

  final int? initialWeek;
  @override
  Future<void> initialize() async {
    await super.initialize();
    if (initialWeek case final week?) timetable.selectWeek(week);
  }
}

class MemoryMoocStorage extends MoocStorage {
  MoocAccount? account;
  @override
  Future<MoocAccount?> read() async => account;
  @override
  Future<void> write(MoocAccount value) async => account = value;
  @override
  Future<void> clear() async => account = null;
}
