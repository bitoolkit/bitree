import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../agenda/model.dart';
import '../agenda/view_mode.dart';
import '../core/async/serial_queue.dart';
import '../core/diagnostics.dart';
import '../core/platform/desktop_widget.dart';
import '../core/platform/system_palette.dart';
import '../schedule/height_mode.dart';
import '../ui/course_palette.dart';

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

/// Persists application-wide presentation choices.
class AppSettingsController extends ChangeNotifier {
  AppSettingsController(
    this._preferences, {
    SystemPaletteSource? systemPaletteSource,
    Future<Map<String, CoursePalette>> Function()? coursePaletteLoader,
  }) : _systemPaletteSource = systemPaletteSource ?? SystemPaletteSource(),
       _coursePaletteLoader =
           coursePaletteLoader ?? CoursePalette.loadBuiltins {
    _systemPaletteSource.watch(_refreshSystemPalette);
  }

  final SharedPreferencesAsync _preferences;
  final Future<Map<String, CoursePalette>> Function() _coursePaletteLoader;
  final Map<String, CoursePalette> _palettes = {};
  final Map<Brightness, String?> _paletteSelections = {};
  final _paletteWrites = SerialQueue();
  final _globalPreferenceWrites = SerialQueue();
  final _preferenceWrites = <String, Future<void>>{};
  final SystemPaletteSource _systemPaletteSource;
  final agendaViewMode = ValueNotifier(AgendaViewMode.timeline);
  final timetableHeightMode = ValueNotifier(TimetableHeightMode.normal);
  final deadlineCutoff = ValueNotifier(const DeadlineCutoffWindow());
  final agendaLayoutDays = ValueNotifier(AgendaEntry.defaultTailDays);
  final agendaEventInfoBar = ValueNotifier(true);

  Future<void>? _paletteSettingsLoad;
  SystemPalette? _systemPalette;
  ThemeMode _themeMode = ThemeMode.system;
  AppLanguage _language = AppLanguage.system;
  bool _themeChosen = false;
  bool _agendaViewChosen = false;
  bool _timetableHeightChosen = false;
  bool _deadlineCutoffChosen = false;
  bool _agendaLayoutDaysChosen = false;
  bool _agendaEventInfoBarChosen = false;
  bool _developerMode = false;
  bool _widgetUseSystemPalette = false;
  bool _globalUseSystemPalette = false;
  bool _globalPaletteChosen = false;
  bool _disposed = false;
  int _paletteRequest = 0;

  ThemeMode get themeMode => _themeMode;
  AppLanguage get language => _language;
  bool get developerMode => _developerMode;
  bool get widgetUseSystemPalette => _widgetUseSystemPalette;
  bool get globalUseSystemPalette => _globalUseSystemPalette;
  SystemPalette? get systemPalette =>
      _globalUseSystemPalette ? _systemPalette : null;

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

  Future<void> initialize() async {
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
    await _syncWidgetPalettes();
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
    try {
      final savedHeight = await _preferences.getString('timetableHeightMode');
      if (!_timetableHeightChosen && !_disposed) {
        timetableHeightMode.value =
            TimetableHeightMode.values
                .where((mode) => mode.name == savedHeight)
                .firstOrNull ??
            TimetableHeightMode.normal;
      }
    } on Exception catch (failure, stack) {
      AppDiagnostics.instance.error('读取课表高度设置', failure, stack);
    }
    try {
      final savedCutoff = await _preferences.getString('deadlineCutoff');
      if (!_deadlineCutoffChosen && !_disposed && savedCutoff != null) {
        final decoded = jsonDecode(savedCutoff);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('DDL 伪提前设置格式不正确');
        }
        deadlineCutoff.value = DeadlineCutoffWindow.fromJson(decoded);
        _notify();
      }
    } catch (failure, stack) {
      AppDiagnostics.instance.report('读取 DDL 伪提前设置', failure, stack);
    }
    try {
      final saved = await _preferences.getString('agendaLayoutDays');
      if (!_agendaLayoutDaysChosen && !_disposed && saved != null) {
        final days = int.tryParse(saved);
        if (days == null ||
            days < AgendaEntry.minTailDays ||
            days > AgendaEntry.maxTailDays) {
          throw FormatException(
            'DDL 排版宽度必须为 ${AgendaEntry.minTailDays}–'
            '${AgendaEntry.maxTailDays} 天',
          );
        }
        agendaLayoutDays.value = days;
        _notify();
      }
    } catch (failure, stack) {
      AppDiagnostics.instance.report('读取 DDL 排版宽度', failure, stack);
    }
    try {
      final saved = await _preferences.getString('agendaEventInfoBar');
      if (!_agendaEventInfoBarChosen && !_disposed && saved != null) {
        if (saved != 'true' && saved != 'false') {
          throw const FormatException('日程信息栏设置必须是布尔值');
        }
        agendaEventInfoBar.value = saved == 'true';
        _notify();
      }
    } catch (failure, stack) {
      AppDiagnostics.instance.report('读取日程信息栏设置', failure, stack);
    }
  }

  Future<void> setTheme(ThemeMode value) {
    _themeChosen = true;
    _themeMode = value;
    _notify();
    return _writePreference('theme', value.name, '保存外观设置');
  }

  Future<void> setLanguage(AppLanguage value) async {
    try {
      await _preferences.setString('language', value.name);
      _language = value;
      _notify();
    } catch (failure, stack) {
      AppDiagnostics.instance.report('保存语言设置', failure, stack);
    }
  }

  void unlockDeveloperMode() {
    if (_developerMode) return;
    _developerMode = true;
    _notify();
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
          try {
            await _saveCoursePalettes(_palettes, _paletteSelections);
            await _preferences.remove('darkCoursePalette');
          } catch (failure, stack) {
            AppDiagnostics.instance.report('迁移调色板设置', failure, stack);
          }
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
        try {
          await _preferences.remove('darkCoursePalette');
        } catch (failure, stack) {
          AppDiagnostics.instance.report('清理旧调色板设置', failure, stack);
        }
      }
    } catch (failure, stack) {
      AppDiagnostics.instance.report('读取调色板设置', failure, stack);
    }
    _notify();
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

  Future<void> setCoursePalette(Brightness brightness, String? id) =>
      _paletteWrites.run(() async {
        await loadCoursePalettes();
        if (id != null && _palettes[id]?.brightness != brightness) {
          throw const FormatException('此配色不适用于所选的明暗模式。');
        }
        final selections = {..._paletteSelections, brightness: id};
        try {
          await _saveCoursePalettes(_palettes, selections);
          _paletteSelections[brightness] = id;
          _notify();
          await _syncWidgetPalettes();
        } catch (failure, stack) {
          AppDiagnostics.instance.report('保存调色板设置', failure, stack);
        }
      });

  Future<void> importCoursePalette(String source) async {
    // Validate the whole file before touching either selection or persistence.
    final palette = CoursePalette.parse(source);
    await _paletteWrites.run(() async {
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
      _notify();
      await _syncWidgetPalettes();
    });
  }

  Future<void> deleteCoursePalette(String id) => _paletteWrites.run(() async {
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
      _notify();
      await _syncWidgetPalettes();
    } catch (failure, stack) {
      AppDiagnostics.instance.report('删除自定义配色', failure, stack);
    }
  });

  Future<void> setWidgetUseSystemPalette(bool value) =>
      _paletteWrites.run(() async {
        try {
          await _preferences.setBool('widgetUseSystemPalette', value);
          _widgetUseSystemPalette = value;
          _notify();
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
    _notify();
    final refresh = _refreshSystemPalette();
    final write = _globalPreferenceWrites.run(() async {
      try {
        await _preferences.setBool('globalUseSystemPalette', value);
      } catch (failure, stack) {
        AppDiagnostics.instance.report('保存全局调色板设置', failure, stack);
      }
    });
    await Future.wait<void>([refresh, write]);
  }

  Future<void> _refreshSystemPalette() async {
    if (_disposed || !_globalUseSystemPalette) return;
    final request = ++_paletteRequest;
    try {
      final palette = await _systemPaletteSource.load();
      if (_disposed || request != _paletteRequest) return;
      _systemPalette = palette;
      _notify();
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

  Future<void> setTimetableHeightMode(TimetableHeightMode value) {
    _timetableHeightChosen = true;
    timetableHeightMode.value = value;
    return _writePreference('timetableHeightMode', value.name, '保存课表高度设置');
  }

  Future<void> setDeadlineCutoff(DeadlineCutoffWindow value) {
    if (_disposed) return Future<void>.value();
    _deadlineCutoffChosen = true;
    deadlineCutoff.value = value;
    _notify();
    return _writePreference(
      'deadlineCutoff',
      jsonEncode(value.toJson()),
      '保存 DDL 伪提前设置',
    );
  }

  Future<void> setAgendaLayoutDays(int value) {
    if (_disposed) return Future<void>.value();
    if (value < AgendaEntry.minTailDays || value > AgendaEntry.maxTailDays) {
      throw RangeError.range(
        value,
        AgendaEntry.minTailDays,
        AgendaEntry.maxTailDays,
        'agendaLayoutDays',
      );
    }
    _agendaLayoutDaysChosen = true;
    agendaLayoutDays.value = value;
    _notify();
    return _writePreference(
      'agendaLayoutDays',
      value.toString(),
      '保存 DDL 排版宽度',
    );
  }

  Future<void> setAgendaEventInfoBar(bool value) {
    if (_disposed) return Future<void>.value();
    _agendaEventInfoBarChosen = true;
    agendaEventInfoBar.value = value;
    _notify();
    return _writePreference(
      'agendaEventInfoBar',
      value ? 'true' : 'false',
      '保存日程信息栏设置',
    );
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

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _paletteRequest++;
    _systemPaletteSource.dispose();
    agendaViewMode.dispose();
    timetableHeightMode.dispose();
    deadlineCutoff.dispose();
    agendaLayoutDays.dispose();
    agendaEventInfoBar.dispose();
    super.dispose();
  }
}
