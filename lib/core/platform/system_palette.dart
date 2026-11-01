import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Platform boundary kept injectable for unsupported platforms and tests.
class SystemPaletteSource {
  static const _channel = MethodChannel('dev.so1ve.bitree/theme');
  bool _watching = false;

  Future<SystemPalette?> load() async {
    if (!Platform.isAndroid) return null;
    return SystemPalette.fromPlatform(
      await _channel.invokeMethod<Object?>('getSystemPalette'),
    );
  }

  void watch(VoidCallback onChanged) {
    if (!Platform.isAndroid) return;
    _watching = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') onChanged();
    });
  }

  void dispose() {
    if (_watching) _channel.setMethodCallHandler(null);
  }
}

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

  Color tone(String family, int tone) {
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
        tone(family, dark ? night : light);
    Color neutral(int light, int night) => accent('neutral1', light, night);
    Color variant(int light, int night) => accent('neutral2', light, night);
    // Keep Material's semantic error roles while replacing all palette roles.
    return ColorScheme.fromSeed(
      seedColor: tone('accent1', 40),
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
      primaryFixed: tone('accent1', 90),
      primaryFixedDim: tone('accent1', 80),
      onPrimaryFixed: tone('accent1', 10),
      onPrimaryFixedVariant: tone('accent1', 30),
      secondaryFixed: tone('accent2', 90),
      secondaryFixedDim: tone('accent2', 80),
      onSecondaryFixed: tone('accent2', 10),
      onSecondaryFixedVariant: tone('accent2', 30),
      tertiaryFixed: tone('accent3', 90),
      tertiaryFixedDim: tone('accent3', 80),
      onTertiaryFixed: tone('accent3', 10),
      onTertiaryFixedVariant: tone('accent3', 30),
    );
  }
}
