import 'package:flutter/material.dart';

import '../../schedule/building_palette.dart';
import '../../ui/course_palette.dart';
import '../deadline_source.dart';
import '../model.dart';
import '../physics_lab_deadlines.dart';

/// Source/type colors are specific to the timeline, not other agenda views.
({Color fill, Color text, Color accent}) agendaTimelineColors(
  BuildContext context,
  AgendaEntry entry,
  DateTime now,
) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final paletteName = switch (entry.kind) {
    AgendaKind.exam => '物理实验中心',
    AgendaKind.deadline =>
      isPhysicsLabDeadline(entry)
          ? '综合教学楼A'
          : switch (entry.source) {
              DeadlineSource.lexue => '工程训练中心',
              DeadlineSource.eclass => '文化体育中心',
              DeadlineSource.mooc => '文萃楼A',
              null => null,
            },
    AgendaKind.event => null,
  };
  final palette = paletteName == null
      ? null
      : buildingPaletteNamed(paletteName);
  final finished = entry.isFinished(now);
  final fadeAll =
      finished && (entry.isDeadline || entry.kind == AgendaKind.exam);
  final fillAlpha = fadeAll ? 0.5 : (finished ? 0.55 : 1.0);
  final foregroundAlpha = fadeAll ? 0.5 : 1.0;
  if (palette != null) {
    // Keep source colours recognizable even when the app uses system colours.
    final values = theme.brightness == Brightness.dark
        ? palette.dark
        : palette.light;
    return (
      fill: Color(values.fill).withValues(alpha: fillAlpha),
      text: Color(values.text).withValues(alpha: foregroundAlpha),
      accent: Color(values.accent).withValues(alpha: foregroundAlpha),
    );
  }

  final blockPalette = agendaPaletteColors(theme);
  if (blockPalette != null) {
    return (
      fill: Color(blockPalette.fill).withValues(alpha: fillAlpha),
      text: Color(blockPalette.text).withValues(alpha: foregroundAlpha),
      accent: Color(blockPalette.accent).withValues(alpha: foregroundAlpha),
    );
  }

  final fill = finished
      ? scheme.surfaceContainerHighest
      : switch (entry.kind) {
          AgendaKind.event => scheme.primaryContainer,
          AgendaKind.exam => scheme.tertiaryContainer,
          AgendaKind.deadline => scheme.secondaryContainer,
        };
  final text = finished
      ? scheme.onSurfaceVariant
      : switch (entry.kind) {
          AgendaKind.event => scheme.onPrimaryContainer,
          AgendaKind.exam => scheme.onTertiaryContainer,
          AgendaKind.deadline => scheme.onSecondaryContainer,
        };
  final accent = switch (entry.kind) {
    AgendaKind.event => scheme.primary,
    AgendaKind.exam => scheme.tertiary,
    AgendaKind.deadline => scheme.secondary,
  };
  return (
    fill: fill.withValues(alpha: fillAlpha),
    text: text.withValues(alpha: foregroundAlpha),
    accent: accent.withValues(alpha: foregroundAlpha),
  );
}
