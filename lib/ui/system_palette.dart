import 'package:flutter/material.dart';

import '../schedule/building_palette.dart';

/// Android's five wallpaper-derived tonal palettes, shared by both app themes.
class SystemPalette {
  SystemPalette._(this._families);

  static const _tones = [100, 99, 95, 90, 80, 70, 60, 50, 40, 30, 20, 10, 0];
  static const _names = [
    'accent1',
    'accent2',
    'accent3',
    'neutral1',
    'neutral2',
  ];
  final Map<String, List<Color>> _families;

  static SystemPalette? fromPlatform(Object? value) {
    if (value is! Map) return null;
    final families = <String, List<Color>>{};
    for (final name in _names) {
      final colors = value[name];
      if (colors is! List ||
          colors.length != _tones.length ||
          colors.any((color) => color is! int)) {
        return null;
      }
      families[name] = [for (final color in colors) Color(color as int)];
    }
    return SystemPalette._(families);
  }

  Color _tone(String family, int tone) {
    final colors = _families[family]!;
    for (var i = 0; i < _tones.length - 1; i++) {
      final upper = _tones[i];
      final lower = _tones[i + 1];
      if (tone <= upper && tone >= lower) {
        return Color.lerp(
          colors[i],
          colors[i + 1],
          (upper - tone) / (upper - lower),
        )!;
      }
    }
    return colors.last;
  }

  ColorScheme colorScheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    Color accent(String family, int light, int night) =>
        _tone(family, dark ? night : light);
    Color neutral(int light, int night) => accent('neutral1', light, night);
    Color variant(int light, int night) => accent('neutral2', light, night);
    // Keep Material's semantic error roles while replacing all palette roles.
    return ColorScheme.fromSeed(
      seedColor: _tone('accent1', 40),
      brightness: brightness,
    ).copyWith(
      primary: accent('accent1', 40, 80),
      onPrimary: accent('accent1', 100, 20),
      primaryContainer: accent('accent1', 90, 30),
      onPrimaryContainer: accent('accent1', 10, 90),
      secondary: accent('accent2', 40, 80),
      onSecondary: accent('accent2', 100, 20),
      secondaryContainer: accent('accent2', 90, 30),
      onSecondaryContainer: accent('accent2', 10, 90),
      tertiary: accent('accent3', 40, 80),
      onTertiary: accent('accent3', 100, 20),
      tertiaryContainer: accent('accent3', 90, 30),
      onTertiaryContainer: accent('accent3', 10, 90),
      surface: neutral(98, 6),
      onSurface: neutral(10, 90),
      onSurfaceVariant: variant(30, 80),
      surfaceDim: neutral(87, 6),
      surfaceBright: neutral(98, 24),
      surfaceContainerLowest: neutral(100, 4),
      surfaceContainerLow: neutral(96, 10),
      surfaceContainer: neutral(94, 12),
      surfaceContainerHigh: neutral(92, 17),
      surfaceContainerHighest: neutral(90, 22),
      outline: variant(50, 60),
      outlineVariant: variant(80, 30),
      inverseSurface: neutral(20, 90),
      onInverseSurface: neutral(95, 20),
      inversePrimary: accent('accent1', 80, 40),
      surfaceTint: accent('accent1', 40, 80),
      primaryFixed: _tone('accent1', 90),
      primaryFixedDim: _tone('accent1', 80),
      onPrimaryFixed: _tone('accent1', 10),
      onPrimaryFixedVariant: _tone('accent1', 30),
      secondaryFixed: _tone('accent2', 90),
      secondaryFixedDim: _tone('accent2', 80),
      onSecondaryFixed: _tone('accent2', 10),
      onSecondaryFixedVariant: _tone('accent2', 30),
      tertiaryFixed: _tone('accent3', 90),
      tertiaryFixedDim: _tone('accent3', 80),
      onTertiaryFixed: _tone('accent3', 10),
      onTertiaryFixedVariant: _tone('accent3', 30),
    );
  }

  /// Match the widget's campus grouping and tone choices.
  ({Color fill, Color text, Color accent}) courseColors(
    CampusArea? area,
    Brightness brightness,
  ) {
    final family = switch (area) {
      CampusArea.northTeaching || CampusArea.eastFacilities => 'accent1',
      CampusArea.wencui => 'accent2',
      CampusArea.southScience || CampusArea.southEngineering => 'accent3',
      null => 'neutral2',
    };
    final dark = brightness == Brightness.dark;
    final alternate =
        area == CampusArea.eastFacilities ||
        area == CampusArea.southEngineering;
    return (
      fill: _tone(family, dark ? (alternate ? 20 : 30) : (alternate ? 95 : 90)),
      text: _tone(family, dark ? 90 : 10),
      accent: _tone(family, dark ? 80 : 40),
    );
  }
}

class SystemPaletteTheme extends ThemeExtension<SystemPaletteTheme> {
  const SystemPaletteTheme(this.palette);

  final SystemPalette palette;

  @override
  SystemPaletteTheme copyWith({SystemPalette? palette}) =>
      SystemPaletteTheme(palette ?? this.palette);

  @override
  SystemPaletteTheme lerp(covariant SystemPaletteTheme? other, double t) =>
      other == null || t < 0.5 ? this : other;
}
