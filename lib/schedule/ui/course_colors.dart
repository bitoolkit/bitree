import 'package:flutter/material.dart';

import '../../core/platform/system_palette.dart';
import '../../ui/course_palette.dart';
import '../../ui/system_palette.dart';
import '../building_palette.dart';
import '../model.dart';

extension SystemPaletteCourseColors on SystemPalette {
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
      fill: tone(family, dark ? (alternate ? 20 : 30) : (alternate ? 95 : 90)),
      text: tone(family, dark ? 90 : 10),
      accent: tone(family, dark ? 80 : 40),
    );
  }
}

({Color fill, Color text, Color secondaryText, Color accent, Color elapsedFill})
courseColors(BuildContext context, Course course) {
  final palette =
      matchCampusBuilding(course.room, campus: course.campus) ??
      unknownBuildingPalette;
  final theme = Theme.of(context);
  final dark = theme.brightness == Brightness.dark;
  final system = theme.extension<SystemPaletteTheme>()?.palette;
  if (system != null) {
    final colors = system.courseColors(palette.area, theme.brightness);
    return (
      fill: colors.fill,
      text: colors.text,
      secondaryText: Color.lerp(colors.fill, colors.text, 0.8)!,
      accent: colors.accent,
      elapsedFill: Color.lerp(colors.fill, colors.accent, dark ? 0.16 : 0.32)!,
    );
  }
  final custom = theme.extension<CoursePaletteTheme>()?.palette;
  final colors =
      custom?.colorsFor(palette.area) ?? (dark ? palette.dark : palette.light);
  final accent = Color(colors.accent);
  // Custom palettes already contain the final mixed block fill.
  final fill = dark && custom == null
      ? Color.lerp(Color(colors.fill), accent, 0.24)!
      : Color(colors.fill);
  final text = Color(colors.text);
  return (
    fill: fill,
    text: text,
    secondaryText: Color.lerp(fill, text, 0.8)!,
    accent: accent,
    elapsedFill: Color.lerp(fill, accent, dark ? 0.16 : 0.32)!,
  );
}
