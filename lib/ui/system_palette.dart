import 'package:flutter/material.dart';

import '../core/platform/system_palette.dart';

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
