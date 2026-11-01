import 'package:bitree/core/platform/system_palette.dart';
import 'package:bitree/ui/system_palette.dart';
import 'package:flutter/material.dart';

Map<String, List<int>> systemPaletteValues({double hue = 150}) => {
  for (final (name, offset, saturation) in [
    ('accent1', 0, 0.5),
    ('accent2', 30, 0.25),
    ('accent3', 60, 0.4),
    ('neutral1', 0, 0.05),
    ('neutral2', 0, 0.1),
  ])
    name: [
      for (final tone in [100, 99, 95, 90, 80, 70, 60, 50, 40, 30, 20, 10, 0])
        HSLColor.fromAHSL(
          1,
          (hue + offset) % 360,
          saturation,
          tone / 100,
        ).toColor().toARGB32().toSigned(32),
    ],
};

SystemPalette testSystemPalette({double hue = 150}) =>
    SystemPalette.fromPlatform(systemPaletteValues(hue: hue))!;

class MemorySystemPaletteSource extends SystemPaletteSource {
  MemorySystemPaletteSource({this.palette, this.loader});

  SystemPalette? palette;
  Future<SystemPalette?> Function()? loader;
  VoidCallback? onChanged;
  int reads = 0;

  @override
  Future<SystemPalette?> load() async {
    reads++;
    return loader == null ? palette : await loader!();
  }

  @override
  void watch(VoidCallback onChanged) => this.onChanged = onChanged;

  @override
  void dispose() => onChanged = null;
}
