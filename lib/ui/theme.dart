import 'package:flutter/material.dart';

import '../schedule/building_palette.dart';
import '../schedule/model.dart';
import 'course_palette.dart';
import 'design.dart';
import 'system_palette.dart';

const copper = Color(0xFFA85E3E);

ThemeData bitreeTheme(
  Brightness brightness, {
  CoursePalette? coursePalette,
  SystemPalette? systemPalette,
}) {
  final dark = brightness == Brightness.dark;
  final scheme =
      systemPalette?.colorScheme(brightness) ??
      ColorScheme.fromSeed(
        seedColor: copper,
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.neutral,
      ).copyWith(
        primary: dark ? const Color(0xFFE5AE8F) : copper,
        onPrimary: dark ? const Color(0xFF301C12) : Colors.white,
        primaryContainer: dark
            ? const Color(0xFF3B302A)
            : const Color(0xFFEEE6E0),
        onPrimaryContainer: dark
            ? const Color(0xFFE9D8CC)
            : const Color(0xFF493224),
        secondaryContainer: dark
            ? const Color(0xFF343434)
            : const Color(0xFFE5E5E5),
        onSecondaryContainer: dark
            ? const Color(0xFFE8E8E8)
            : const Color(0xFF292929),
        surface: dark ? const Color(0xFF171717) : const Color(0xFFF8F8F8),
        onSurface: dark ? const Color(0xFFE8E8E8) : const Color(0xFF242424),
        onSurfaceVariant: dark
            ? const Color(0xFFAAAAAA)
            : const Color(0xFF666666),
        surfaceContainerLowest: dark ? const Color(0xFF111111) : Colors.white,
        surfaceContainerLow: dark ? const Color(0xFF202020) : Colors.white,
        surfaceContainer: dark
            ? const Color(0xFF282828)
            : const Color(0xFFF0F0F0),
        surfaceContainerHigh: dark
            ? const Color(0xFF303030)
            : const Color(0xFFE8E8E8),
        surfaceContainerHighest: dark
            ? const Color(0xFF383838)
            : const Color(0xFFE0E0E0),
        outline: dark ? const Color(0xFF808080) : const Color(0xFF858585),
        outlineVariant: dark
            ? const Color(0xFF3A3A3A)
            : const Color(0xFFDDDDDD),
        surfaceTint: Colors.transparent,
      );
  return ThemeData(
    useMaterial3: true,
    extensions: [
      CoursePaletteTheme(
        coursePalette?.brightness == brightness ? coursePalette : null,
      ),
      if (systemPalette != null) SystemPaletteTheme(systemPalette),
    ],
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    fontFamilyFallback: const [
      'Noto Sans CJK SC',
      'Microsoft YaHei',
      'PingFang SC',
    ],
    visualDensity: VisualDensity.standard,
    textTheme: TextTheme(
      titleLarge: TextStyle(
        fontSize: 20,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      bodyLarge: TextStyle(fontSize: 15, height: 1.5, color: scheme.onSurface),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.45,
        color: scheme.onSurface,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.4,
        color: scheme.onSurfaceVariant,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: appControlSize,
        padding: appControlPadding,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        shape: appControlShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: appControlSize,
        padding: appControlPadding,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        side: BorderSide(color: scheme.outlineVariant),
        shape: appControlShape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: appControlSize,
        padding: appControlPadding,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        shape: appControlShape,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        minimumSize: appControlSize,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        backgroundColor: scheme.surfaceContainerLow,
        foregroundColor: scheme.onSurfaceVariant,
        selectedBackgroundColor: scheme.primaryContainer,
        selectedForegroundColor: scheme.onPrimaryContainer,
        side: BorderSide(color: scheme.outlineVariant),
        shape: appControlShape,
      ),
    ),
    chipTheme: ChipThemeData(
      shape: appControlShape,
      side: BorderSide(color: scheme.outlineVariant),
      backgroundColor: scheme.surfaceContainerLow,
      selectedColor: scheme.primaryContainer,
      labelStyle: TextStyle(fontSize: 14, color: scheme.onSurface),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    ),
    searchBarTheme: SearchBarThemeData(
      constraints: const BoxConstraints(minHeight: 48),
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerLow),
      shape: WidgetStatePropertyAll(
        appControlShape.copyWith(
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      textStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 15, color: scheme.onSurface),
      ),
      hintStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
      ),
    ),
    searchViewTheme: SearchViewThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: appControlShape,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: appControlSize,
        foregroundColor: scheme.onSurfaceVariant,
        shape: appControlShape,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: scheme.primaryContainer,
      indicatorShape: appControlShape,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 23,
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          height: 1.3,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w400,
          color: states.contains(WidgetState.selected)
              ? scheme.onSurface
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    listTileTheme: ListTileThemeData(
      minLeadingWidth: 24,
      shape: appControlShape,
      horizontalTitleGap: 14,
      minVerticalPadding: 12,
      iconColor: scheme.onSurfaceVariant,
      titleTextStyle: TextStyle(fontSize: 15, color: scheme.onSurface),
      subtitleTextStyle: TextStyle(
        fontSize: 13,
        height: 1.45,
        color: scheme.onSurfaceVariant,
      ),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerLow),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(6),
        side: WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant)),
        shape: const WidgetStatePropertyAll(appControlShape),
      ),
    ),
    menuButtonTheme: MenuButtonThemeData(
      style: MenuItemButton.styleFrom(
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(fontSize: 14),
        shape: appControlShape,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      border: const OutlineInputBorder(borderRadius: AppCorners.control),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppCorners.control,
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppCorners.control,
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      constraints: const BoxConstraints(maxWidth: 560),
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: scheme.outlineVariant,
      dragHandleSize: const Size(32, 4),
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: AppCorners.sheet),
    ),
    dialogTheme: DialogThemeData(
      constraints: const BoxConstraints.tightFor(width: 360),
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: appPanelShape,
    ),
    datePickerTheme: const DatePickerThemeData(
      shape: appPanelShape,
      dayShape: WidgetStatePropertyAll(appControlShape),
      yearShape: WidgetStatePropertyAll(appControlShape),
    ),
    timePickerTheme: const TimePickerThemeData(
      shape: appPanelShape,
      hourMinuteShape: appControlShape,
      dayPeriodShape: appControlShape,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: AppCorners.compact,
      ),
      textStyle: TextStyle(fontSize: 12, color: scheme.onInverseSurface),
    ),
  );
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
