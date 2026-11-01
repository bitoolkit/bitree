import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../academics/controller.dart';
import '../agenda/controller.dart';
import '../agenda/view_mode.dart';
import '../classrooms/repository.dart';
import '../core/diagnostics.dart';
import '../core/platform/desktop_widget.dart';
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
import '../ui/system_palette.dart';

enum AppLanguage {
  system,
  chinese,
  english;

  Locale? get locale => switch (this) {
    AppLanguage.system => null,
    AppLanguage.chinese => const Locale('zh'),
    AppLanguage.english => const Locale('en'),
  };
}

/// Composes feature state and owns application startup and appearance.
/// Feature changes are observed by their views, not relayed through this object.
class AppController extends ChangeNotifier {
  AppController({
    required ScheduleStore store,
    required SchoolService school,
    required SchoolStorage schoolStorage,
    required this._preferences,
    required this.agenda,
    required this.academics,
    SystemPaletteSource? systemPaletteSource,
    Future<Map<String, CoursePalette>> Function()? coursePaletteLoader,
    MoocStorage? moocStorage,
  }) : _coursePaletteLoader = coursePaletteLoader ?? CoursePalette.loadBuiltins,
       _systemPaletteSource = systemPaletteSource ?? SystemPaletteSource(),
       timetable = TimetableController(store) {
    this.school = SchoolController(
      service: school,
      storage: schoolStorage,
      timetable: timetable,
      agenda: agenda,
      academics: academics,
    );
    classrooms = ClassroomRepository(this.school);
    _systemPaletteSource.watch(() => _refreshSystemPalette());
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
  }

  final TimetableController timetable;
  late final SchoolController school;
  late final ClassroomRepository classrooms;
  final AgendaController agenda;
  final AcademicController academics;
  late final MoocController mooc;
  late final SyncController sync;
  final SharedPreferencesAsync _preferences;
  final agendaViewMode = ValueNotifier(AgendaViewMode.timeline);
  final _preferenceWrites = <String, Future<void>>{};
  bool _themeChosen = false;
  bool _agendaViewChosen = false;
  bool _ready = false;
  ThemeMode _themeMode = ThemeMode.system;
  bool _developerMode = false;
  bool _widgetUseSystemPalette = false;
  final Future<Map<String, CoursePalette>> Function() _coursePaletteLoader;
  final Map<String, CoursePalette> _palettes = {};
  final Map<Brightness, String?> _paletteSelections = {};
  Future<void>? _paletteSettingsLoad;
  Future<void> _coursePaletteWrite = Future<void>.value();
  final SystemPaletteSource _systemPaletteSource;
  bool _globalUseSystemPalette = false;
  bool _globalPaletteChosen = false;
  bool _disposed = false;
  int _paletteRequest = 0;
  SystemPalette? _systemPalette;
  Future<void> _globalPaletteWrite = Future<void>.value();

  bool get ready => _ready;
  ThemeMode get themeMode => _themeMode;
  bool get developerMode => _developerMode;
  bool get widgetUseSystemPalette => _widgetUseSystemPalette;
  Map<String, CoursePalette> palettesFor(Brightness brightness) => {
    for (final entry in _palettes.entries)
      if (entry.value.brightness == brightness) entry.key: entry.value,
  };
  Map<String, CoursePalette> get customPalettes => {
    for (final entry in _palettes.entries)
      if (!CoursePalette.builtinIds.contains(entry.key)) entry.key: entry.value,
  };
  String? paletteIdFor(Brightness brightness) => _paletteSelections[brightness];
  CoursePalette? paletteFor(Brightness brightness) =>
      _palettes[paletteIdFor(brightness)];
  bool get globalUseSystemPalette => _globalUseSystemPalette;
  SystemPalette? get systemPalette =>
      _globalUseSystemPalette ? _systemPalette : null;
  AppLanguage _language = AppLanguage.system;

  AppLanguage get language => _language;

  Future<void> initialize() async {
    await timetable.load();
    try {
      final theme = await _preferences.getString('theme');
      if (!_themeChosen) {
        _themeMode =
            ThemeMode.values
                .where((value) => value.name == theme)
                .firstOrNull ??
            ThemeMode.system;
      }
    } on Exception catch (failure, stack) {
      AppDiagnostics.instance.error('读取外观设置', failure, stack);
    }
    try {
      final language = await _preferences.getString('language');
      _language =
          AppLanguage.values
              .where((value) => value.name == language)
              .firstOrNull ??
          AppLanguage.system;
    } catch (failure, stack) {
      AppDiagnostics.instance.report('读取语言设置', failure, stack);
    }
    await loadCoursePalettes();
    try {
      _widgetUseSystemPalette =
          await _preferences.getBool('widgetUseSystemPalette') ?? false;
    } catch (failure, stack) {
      AppDiagnostics.instance.report('读取小组件调色板设置', failure, stack);
    }
    try {
      final enabled =
          await _preferences.getBool('globalUseSystemPalette') ?? false;
      if (!_globalPaletteChosen) _globalUseSystemPalette = enabled;
    } catch (failure, stack) {
      AppDiagnostics.instance.report('读取全局调色板设置', failure, stack);
    }
    await _refreshSystemPalette();
    await updateDesktopWidget(
      lightCourseColors: paletteFor(Brightness.light)?.widgetColors ?? {},
      darkCourseColors: paletteFor(Brightness.dark)?.widgetColors ?? {},
      useSystemPalette: _widgetUseSystemPalette,
    );
    try {
      final savedView = await _preferences.getString('agendaViewMode');
      if (!_agendaViewChosen) {
        agendaViewMode.value =
            AgendaViewMode.values
                .where((mode) => mode.name == savedView)
                .firstOrNull ??
            AgendaViewMode.timeline;
      }
    } on Exception catch (failure, stack) {
      AppDiagnostics.instance.error('读取日程视图设置', failure, stack);
    }
    await school.loadAccount();
    await agenda.load();
    await mooc.load();
    await academics.load(school.username);
    _ready = true;
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode value) {
    _themeChosen = true;
    _themeMode = value;
    notifyListeners();
    return _writePreference('theme', value.name, '保存外观设置');
  }

  Future<void> setLanguage(AppLanguage value) async {
    try {
      await _preferences.setString('language', value.name);
      _language = value;
      notifyListeners();
    } catch (failure, stack) {
      AppDiagnostics.instance.report('保存语言设置', failure, stack);
    }
  }

  void unlockDeveloperMode() {
    if (_developerMode) return;
    _developerMode = true;
    notifyListeners();
  }

  Future<void> loadCoursePalettes() =>
      _paletteSettingsLoad ??= _loadCoursePalettes();

  Future<void> _loadCoursePalettes() async {
    try {
      _palettes.addAll(await _coursePaletteLoader());
      final saved = await _preferences.getString('coursePalettes');
      if (saved == null) {
        // Preserve choices made before JSON palettes were introduced.
        final legacy = await _preferences.getString('darkCoursePalette');
        if (_palettes.containsKey(legacy)) {
          _paletteSelections[Brightness.dark] = legacy;
        }
      } else {
        final json = jsonDecode(saved) as Map<String, dynamic>;
        final custom = json['custom'] as Map<String, dynamic>;
        for (final entry in custom.entries) {
          try {
            if (CoursePalette.builtinIds.contains(entry.key)) continue;
            _palettes[entry.key] = CoursePalette.fromJson(entry.value);
          } catch (failure, stack) {
            AppDiagnostics.instance.report('读取自定义配色', failure, stack);
          }
        }
        for (final brightness in Brightness.values) {
          final id = json[brightness.name];
          if (id is String && _palettes[id]?.brightness == brightness) {
            _paletteSelections[brightness] = id;
          }
        }
      }
    } catch (failure, stack) {
      AppDiagnostics.instance.report('读取调色板设置', failure, stack);
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> _saveCoursePalettes(
    Map<String, CoursePalette> palettes,
    Map<Brightness, String?> selections,
  ) => _preferences.setString(
    'coursePalettes',
    jsonEncode({
      for (final brightness in Brightness.values)
        brightness.name: selections[brightness],
      'custom': {
        for (final entry in palettes.entries)
          if (!CoursePalette.builtinIds.contains(entry.key))
            entry.key: entry.value.toJson(),
      },
    }),
  );

  Future<void> _syncWidgetPalettes() => updateDesktopWidget(
    lightCourseColors: paletteFor(Brightness.light)?.widgetColors ?? {},
    darkCourseColors: paletteFor(Brightness.dark)?.widgetColors ?? {},
    useSystemPalette: _widgetUseSystemPalette,
  );

  // One queue keeps imports, deletions and rapid selections in order. Keep the
  // queue usable after a failed write while allowing import failures to reach UI.
  Future<void> _queuePaletteWrite(Future<void> Function() operation) {
    final result = _coursePaletteWrite.then((_) => operation());
    _coursePaletteWrite = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> setCoursePalette(Brightness brightness, String? id) =>
      _queuePaletteWrite(() async {
        await loadCoursePalettes();
        if (id != null && _palettes[id]?.brightness != brightness) {
          throw const FormatException('此配色不适用于所选的明暗模式。');
        }
        final selections = {..._paletteSelections, brightness: id};
        try {
          await _saveCoursePalettes(_palettes, selections);
          _paletteSelections[brightness] = id;
          if (!_disposed) notifyListeners();
          await _syncWidgetPalettes();
        } catch (failure, stack) {
          AppDiagnostics.instance.report('保存调色板设置', failure, stack);
        }
      });

  Future<void> importCoursePalette(String source) async {
    // Validate the whole file before touching either selection or persistence.
    final palette = CoursePalette.parse(source);
    await _queuePaletteWrite(() async {
      await loadCoursePalettes();
      var suffix = DateTime.now().microsecondsSinceEpoch;
      while (_palettes.containsKey('custom-$suffix')) {
        suffix++;
      }
      final id = 'custom-$suffix';
      final palettes = {..._palettes, id: palette};
      final selections = {..._paletteSelections, palette.brightness: id};
      await _saveCoursePalettes(palettes, selections);
      _palettes[id] = palette;
      _paletteSelections[palette.brightness] = id;
      if (!_disposed) notifyListeners();
      await _syncWidgetPalettes();
    });
  }

  Future<void> deleteCoursePalette(String id) => _queuePaletteWrite(() async {
    await loadCoursePalettes();
    if (!customPalettes.containsKey(id)) return;
    final palettes = {..._palettes}..remove(id);
    final selections = {
      for (final entry in _paletteSelections.entries)
        entry.key: entry.value == id ? null : entry.value,
    };
    try {
      await _saveCoursePalettes(palettes, selections);
      _palettes.remove(id);
      _paletteSelections
        ..clear()
        ..addAll(selections);
      if (!_disposed) notifyListeners();
      await _syncWidgetPalettes();
    } catch (failure, stack) {
      AppDiagnostics.instance.report('删除自定义配色', failure, stack);
    }
  });

  Future<void> setWidgetUseSystemPalette(bool value) =>
      _queuePaletteWrite(() async {
        try {
          await _preferences.setBool('widgetUseSystemPalette', value);
          _widgetUseSystemPalette = value;
          if (!_disposed) notifyListeners();
          await _syncWidgetPalettes();
        } catch (failure, stack) {
          AppDiagnostics.instance.report('保存小组件调色板设置', failure, stack);
        }
      });

  Future<void> setGlobalUseSystemPalette(bool value) async {
    _globalPaletteChosen = true;
    _globalUseSystemPalette = value;
    // Invalidate pending platform reads when the switch changes.
    _paletteRequest++;
    notifyListeners();
    final refresh = _refreshSystemPalette();
    _globalPaletteWrite = _globalPaletteWrite.then((_) async {
      try {
        await _preferences.setBool('globalUseSystemPalette', value);
      } catch (failure, stack) {
        AppDiagnostics.instance.report('保存全局调色板设置', failure, stack);
      }
    });
    await Future.wait<void>([refresh, _globalPaletteWrite]);
  }

  Future<void> _refreshSystemPalette() async {
    if (_disposed || !_globalUseSystemPalette) return;
    final request = ++_paletteRequest;
    try {
      final palette = await _systemPaletteSource.load();
      if (_disposed || request != _paletteRequest) return;
      _systemPalette = palette;
      notifyListeners();
    } catch (failure, stack) {
      // Keep the last working palette, or the original app theme on first load.
      AppDiagnostics.instance.report('读取系统调色板', failure, stack);
    }
  }

  /// Publish immediately and serialize writes so rapid toggles cannot save an
  /// older choice after a newer one.
  Future<void> setAgendaViewMode(AgendaViewMode value) {
    _agendaViewChosen = true;
    agendaViewMode.value = value;
    return _writePreference('agendaViewMode', value.name, '保存日程视图设置');
  }

  Future<void> _writePreference(String key, String value, String operation) {
    final previous = _preferenceWrites[key] ?? Future<void>.value();
    final write = previous.then((_) async {
      try {
        await _preferences.setString(key, value);
      } on Exception catch (failure, stack) {
        AppDiagnostics.instance.error(operation, failure, stack);
      }
    });
    _preferenceWrites[key] = write;
    return write;
  }

  @override
  void dispose() {
    _disposed = true;
    _paletteRequest++;
    _systemPaletteSource.dispose();
    agendaViewMode.dispose();
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
