import 'package:flutter/material.dart';

import '../core/platform/system_palette.dart';
import 'course_palette.dart';
import 'design.dart';
import 'system_palette.dart';

const brandSeed = Color(0xFF255188);

ThemeData bitreeTheme(
  Brightness brightness, {
  CoursePalette? coursePalette,
  SystemPalette? systemPalette,
}) {
  final dark = brightness == Brightness.dark;
  final scheme =
      systemPalette?.colorScheme(brightness) ??
      ColorScheme.fromSeed(
        seedColor: brandSeed,
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.neutral,
      ).copyWith(
        primary: dark ? const Color(0xFF97C2F5) : brandSeed,
        onPrimary: dark ? const Color(0xFF0C2340) : Colors.white,
        primaryContainer: dark
            ? const Color(0xFF1B314D)
            : const Color(0xFFE3EDF9),
        onPrimaryContainer: dark
            ? const Color(0xFFD6E7FC)
            : const Color(0xFF132F54),
        secondaryContainer: dark
            ? const Color(0xFF242A34)
            : const Color(0xFFE7EBF1),
        onSecondaryContainer: dark
            ? const Color(0xFFE2E7F0)
            : const Color(0xFF242B35),
        error: dark ? const Color(0xFFF28B82) : const Color(0xFFC93636),
        onError: dark ? const Color(0xFF4A1210) : Colors.white,
        errorContainer: dark
            ? const Color(0xFF3A1D1D)
            : const Color(0xFFFCECEC),
        onErrorContainer: dark
            ? const Color(0xFFFCD5D2)
            : const Color(0xFF7B1E1E),
        surface: dark ? const Color(0xFF101216) : Colors.white,
        onSurface: dark ? const Color(0xFFECEFF4) : const Color(0xFF14171D),
        onSurfaceVariant: dark
            ? const Color(0xFF98A1B0)
            : const Color(0xFF5B6370),
        surfaceContainerLowest: dark ? const Color(0xFF0B0D10) : Colors.white,
        surfaceContainerLow: dark
            ? const Color(0xFF161920)
            : const Color(0xFFF5F7FA),
        surfaceContainer: dark
            ? const Color(0xFF1F242C)
            : const Color(0xFFECEFF4),
        surfaceContainerHigh: dark
            ? const Color(0xFF272D37)
            : const Color(0xFFE2E7EF),
        surfaceContainerHighest: dark
            ? const Color(0xFF303744)
            : const Color(0xFFD8DFEA),
        outline: dark ? const Color(0xFF6E7787) : const Color(0xFF7A8291),
        outlineVariant: dark
            ? const Color(0xFF262C37)
            : const Color(0xFFE4E8F0),
        surfaceTint: Colors.transparent,
      );
  final panelTitle = TextStyle(
    fontSize: 19,
    height: 1.32,
    letterSpacing: -0.25,
    fontWeight: FontWeight.w600,
    color: scheme.onSurface,
  );
  final dialogTheme = DialogThemeData(
    constraints: const BoxConstraints.tightFor(width: 360),
    insetPadding: const EdgeInsets.all(AppSpacing.xl),
    backgroundColor: scheme.surfaceContainerLow,
    surfaceTintColor: Colors.transparent,
    barrierColor: Colors.black54,
    elevation: 6,
    shape: appPanelShape,
    titleTextStyle: panelTitle,
    actionsPadding: const EdgeInsets.fromLTRB(
      AppSpacing.xl,
      0,
      AppSpacing.xl,
      AppSpacing.xl,
    ),
  );
  final pickerConfirmStyle = TextButton.styleFrom(
    backgroundColor: scheme.primary,
    foregroundColor: scheme.onPrimary,
    disabledBackgroundColor: scheme.onSurface.withValues(alpha: .12),
    disabledForegroundColor: scheme.onSurface.withValues(alpha: .38),
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
      headlineSmall: TextStyle(
        fontSize: 25,
        height: 1.2,
        letterSpacing: -0.4,
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: scheme.onSurface,
      ),
      titleLarge: panelTitle,
      titleMedium: TextStyle(
        fontSize: 15.5,
        height: 1.38,
        letterSpacing: -0.15,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      bodyLarge: TextStyle(fontSize: 15, height: 1.48, color: scheme.onSurface),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.45,
        color: scheme.onSurface,
      ),
      bodySmall: TextStyle(
        fontSize: 12.5,
        height: 1.4,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: TextStyle(
        fontSize: 13.5,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 19,
        letterSpacing: -0.25,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.7),
      thickness: 1,
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 3,
      activeTrackColor: scheme.primary,
      inactiveTrackColor: scheme.surfaceContainerHigh,
      thumbColor: scheme.primary,
      overlayColor: scheme.primary.withValues(alpha: 0.12),
      thumbShape: const RoundSliderThumbShape(
        enabledThumbRadius: 7,
        elevation: 1,
        pressedElevation: 2,
      ),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(999),
    ),
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
        backgroundColor: dark ? scheme.surfaceContainerLow : Colors.white,
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
        minimumSize: const Size(44, 42),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurfaceVariant,
        selectedBackgroundColor: dark
            ? scheme.surfaceContainerHighest
            : scheme.surfaceContainerLowest,
        selectedForegroundColor: scheme.onSurface,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: appControlShape,
      side: BorderSide(color: scheme.outlineVariant),
      backgroundColor: scheme.surfaceContainerLow,
      selectedColor: scheme.primaryContainer,
      labelStyle: TextStyle(fontSize: 13.5, color: scheme.onSurface),
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
          size: 22,
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11.5,
          height: 1.3,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? scheme.onSurface
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      indicatorColor: scheme.primaryContainer,
      indicatorShape: appControlShape,
      selectedIconTheme: IconThemeData(size: 21, color: scheme.primary),
      unselectedIconTheme: IconThemeData(
        size: 21,
        color: scheme.onSurfaceVariant,
      ),
      selectedLabelTextStyle: TextStyle(
        fontSize: 11.5,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      unselectedLabelTextStyle: TextStyle(
        fontSize: 11.5,
        height: 1.3,
        fontWeight: FontWeight.w500,
        color: scheme.onSurfaceVariant,
      ),
    ),
    listTileTheme: ListTileThemeData(
      minLeadingWidth: 24,
      shape: appControlShape,
      horizontalTitleGap: 14,
      minVerticalPadding: 11,
      iconColor: scheme.onSurfaceVariant,
      titleTextStyle: TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
        color: scheme.onSurface,
      ),
      subtitleTextStyle: TextStyle(
        fontSize: 12.5,
        height: 1.42,
        color: scheme.onSurfaceVariant,
      ),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(
          dark ? scheme.surfaceContainerLow : Colors.white,
        ),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(6),
        side: WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant)),
        shape: const WidgetStatePropertyAll(appControlShape),
      ),
    ),
    menuButtonTheme: MenuButtonThemeData(
      style: MenuItemButton.styleFrom(
        minimumSize: const Size(48, 46),
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
      dragHandleSize: const Size(36, 4),
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: AppCorners.sheet),
    ),
    dialogTheme: dialogTheme,
    datePickerTheme: DatePickerThemeData(
      backgroundColor: dialogTheme.backgroundColor,
      surfaceTintColor: dialogTheme.surfaceTintColor,
      elevation: dialogTheme.elevation,
      shape: dialogTheme.shape,
      headerHelpStyle: panelTitle,
      confirmButtonStyle: pickerConfirmStyle,
      dayShape: const WidgetStatePropertyAll(appControlShape),
      yearShape: const WidgetStatePropertyAll(appControlShape),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: dialogTheme.backgroundColor,
      elevation: dialogTheme.elevation,
      shape: dialogTheme.shape,
      helpTextStyle: panelTitle,
      confirmButtonStyle: pickerConfirmStyle,
      hourMinuteShape: appControlShape,
      dayPeriodShape: appControlShape,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
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
