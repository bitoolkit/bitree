import 'package:flutter/material.dart';

import '../../ui/course_palette.dart';
import '../deadline_source.dart';
import '../model.dart';
import '../physics_lab_deadlines.dart';
import 'agenda_color_palette.dart';

typedef _TimelineColors = ({Color fill, Color text, Color accent});

enum _TimelineTone {
  exam(
    light: (
      fill: Color(0xFFF5E0B2),
      text: Color(0xFF322400),
      accent: Color(0xFF735601),
    ),
    dark: (
      fill: Color(0xFF33270D),
      text: Color(0xFFF3EAD9),
      accent: Color(0xFFD5AF57),
    ),
  ),
  physicsLabDeadline(
    light: (
      fill: Color(0xFFCEE5FF),
      text: Color(0xFF112740),
      accent: Color(0xFF225C99),
    ),
    dark: (
      fill: Color(0xFF182A3E),
      text: Color(0xFFE0EDFC),
      accent: Color(0xFF7DB9FC),
    ),
  ),
  lexue(
    light: (
      fill: Color(0xFFFFD8CA),
      text: Color(0xFF3C1C0F),
      accent: Color(0xFF8E4120),
    ),
    dark: (
      fill: Color(0xFF3B2117),
      text: Color(0xFFFBE6DE),
      accent: Color(0xFFF29B79),
    ),
  ),
  eclass(
    light: (
      fill: Color(0xFFEED8FF),
      text: Color(0xFF2F1E3A),
      accent: Color(0xFF6E468A),
    ),
    dark: (
      fill: Color(0xFF302339),
      text: Color(0xFFF0E7F8),
      accent: Color(0xFFCB9FEB),
    ),
  ),
  mooc(
    light: (
      fill: Color(0xFFBDF0D5),
      text: Color(0xFF042F1E),
      accent: Color(0xFF036C49),
    ),
    dark: (
      fill: Color(0xFF123022),
      text: Color(0xFFDDF1E6),
      accent: Color(0xFF68CB9E),
    ),
  );

  const _TimelineTone({required this.light, required this.dark});

  final _TimelineColors light;
  final _TimelineColors dark;
}

/// Source/type colors are specific to the timeline, not other agenda views.
({Color fill, Color text, Color accent}) agendaTimelineColors(
  BuildContext context,
  AgendaEntry entry,
  DateTime now,
) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;

  final physicsLabDeadline = isPhysicsLabDeadline(entry);
  final customColors = switch (entry.color) {
    final color? => agendaColorValues(theme.colorScheme, color),
    null => null,
  };
  final tone = switch (entry.kind) {
    AgendaKind.event => null,
    AgendaKind.exam => _TimelineTone.exam,
    AgendaKind.deadline when physicsLabDeadline =>
      _TimelineTone.physicsLabDeadline,
    AgendaKind.deadline => switch (entry.source) {
      DeadlineSource.lexue => _TimelineTone.lexue,
      DeadlineSource.eclass => _TimelineTone.eclass,
      DeadlineSource.mooc => _TimelineTone.mooc,
      null => null,
    },
  };
  final finished = entry.done || entry.isFinished(now);
  final fillAlpha = finished ? 0.5 : 1.0;
  final foregroundAlpha = finished ? 0.5 : 1.0;
  late final _TimelineColors colors;
  if (customColors != null) {
    colors = (
      fill: customColors.fill.withValues(
        alpha: customColors.fill.a * fillAlpha,
      ),
      text: customColors.text.withValues(
        alpha: customColors.text.a * foregroundAlpha,
      ),
      accent: customColors.accent.withValues(
        alpha: customColors.accent.a * foregroundAlpha,
      ),
    );
  } else if (tone != null) {
    final values = theme.brightness == Brightness.dark ? tone.dark : tone.light;
    colors = (
      fill: values.fill.withValues(alpha: values.fill.a * fillAlpha),
      text: values.text.withValues(alpha: values.text.a * foregroundAlpha),
      accent: values.accent.withValues(
        alpha: values.accent.a * foregroundAlpha,
      ),
    );
  } else if (agendaPaletteColors(theme) case final blockPalette?) {
    final fill = Color(blockPalette.fill);
    final text = Color(blockPalette.text);
    final accent = Color(blockPalette.accent);
    colors = (
      fill: fill.withValues(alpha: fill.a * fillAlpha),
      text: text.withValues(alpha: text.a * foregroundAlpha),
      accent: accent.withValues(alpha: accent.a * foregroundAlpha),
    );
  } else {
    final manualDeadline =
        entry.isDeadline && entry.source == null && !physicsLabDeadline;
    final fill = finished
        ? scheme.surfaceContainerHighest
        : manualDeadline
        ? scheme.secondaryContainer
        : scheme.primaryContainer;
    final text = finished
        ? scheme.onSurfaceVariant
        : manualDeadline
        ? scheme.onSecondaryContainer
        : scheme.onPrimaryContainer;
    final accent = manualDeadline ? scheme.secondary : scheme.primary;
    colors = (
      fill: fill.withValues(alpha: fill.a * fillAlpha),
      text: text.withValues(alpha: text.a * foregroundAlpha),
      accent: accent.withValues(alpha: accent.a * foregroundAlpha),
    );
  }

  if (!entry.overdue(now)) return colors;
  return (
    fill: scheme.errorContainer,
    text: scheme.onErrorContainer,
    accent: scheme.error,
  );
}
