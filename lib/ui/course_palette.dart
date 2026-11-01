import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../schedule/building_palette.dart';
import 'system_palette.dart';

/// A block-only palette. Page surfaces and controls keep the app's ColorScheme.
class CoursePalette {
  CoursePalette._(this.name, this.brightness, Map<String, int> colors)
    : _colors = Map.unmodifiable(colors);

  factory CoursePalette.parse(String source) {
    final Object? json;
    try {
      json = jsonDecode(source);
    } on FormatException {
      throw const FormatException('配色文件不是有效的 JSON。');
    }
    return CoursePalette.fromJson(json);
  }

  factory CoursePalette.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('配色文件必须是一个 JSON 对象。');
    }
    final name = json['name'];
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('name 必须是非空名称。');
    }
    final brightness = switch (json['brightness']) {
      'light' => Brightness.light,
      'dark' => Brightness.dark,
      _ => throw const FormatException('brightness 必须是 light 或 dark。'),
    };
    final colors = <String, int>{};
    for (final key in colorKeys) {
      final value = json[key];
      if (value is! String ||
          value.length != 7 ||
          !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
        throw FormatException('$key 必须是不透明的 #RRGGBB 颜色。');
      }
      colors[key] = 0xFF000000 | int.parse(value.substring(1), radix: 16);
    }
    return CoursePalette._(name.trim(), brightness, colors);
  }

  static const colorKeys = [
    'base',
    'text',
    'northTeaching',
    'wencui',
    'southScience',
    'eastFacilities',
    'southEngineering',
    'neutral',
    'agenda',
  ];
  static const builtinIds = ['mocha', 'macchiato', 'frappe'];

  static Future<Map<String, CoursePalette>> loadBuiltins() async => {
    for (final id in builtinIds)
      id: CoursePalette.parse(
        await rootBundle.loadString('assets/palettes/$id.json'),
      ),
  };

  final String name;
  final Brightness brightness;
  final Map<String, int> _colors;

  Map<String, Object> toJson() => {
    'name': name,
    'brightness': brightness.name,
    for (final key in colorKeys)
      key:
          '#${(_colors[key]! & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
  };

  BuildingColorValues _blockColors(String key) => (
    fill: Color.lerp(
      Color(_colors['base']!),
      Color(_colors[key]!),
      0.24,
    )!.toARGB32(),
    text: _colors['text']!,
    accent: _colors[key]!,
  );

  BuildingColorValues colorsFor(CampusArea? area) =>
      _blockColors(area?.name ?? 'neutral');

  BuildingColorValues get agendaColors => _blockColors('agenda');

  /// Final opaque course fills, shared with the native widget renderer.
  Map<String, List<int>> get widgetColors => {
    'surface': [_colors['base']!, _colors['text']!],
    for (final area in <CampusArea?>[...CampusArea.values, null])
      area?.name ?? 'neutral': [colorsFor(area).fill, colorsFor(area).text],
  };
}

BuildingColorValues? agendaPaletteColors(ThemeData theme) {
  if (theme.extension<SystemPaletteTheme>() != null) return null;
  return theme.extension<CoursePaletteTheme>()?.palette?.agendaColors;
}

class CoursePaletteTheme extends ThemeExtension<CoursePaletteTheme> {
  const CoursePaletteTheme(this.palette);

  final CoursePalette? palette;

  @override
  CoursePaletteTheme copyWith({CoursePalette? palette}) =>
      CoursePaletteTheme(palette ?? this.palette);

  @override
  CoursePaletteTheme lerp(CoursePaletteTheme? other, double t) =>
      other == null || t < 0.5 ? this : other;
}
