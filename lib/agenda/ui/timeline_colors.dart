import 'package:flutter/material.dart';

import '../../ui/course_palette.dart';
import '../deadline_source.dart';
import '../model.dart';
import '../physics_lab_deadlines.dart';

typedef _TimelineColors = ({Color fill, Color text, Color accent});

enum _TimelineTone {
  exam(
    light: (
      fill: Color(0xFFF4DAAE),
      text: Color(0xFF262626),
      accent: Color(0xFF735102),
    ),
    dark: (
      fill: Color(0xFF392B11),
      text: Color(0xFFEEEEEE),
      accent: Color(0xFFDFAF56),
    ),
  ),
  physicsLabDeadline(
    light: (
      fill: Color(0xFFC7E1FE),
      text: Color(0xFF262626),
      accent: Color(0xFF1A5998),
    ),
    dark: (
      fill: Color(0xFF1D2F44),
      text: Color(0xFFEEEEEE),
      accent: Color(0xFF81BCFE),
    ),
  ),
  lexue(
    light: (
      fill: Color(0xFFFFD3C2),
      text: Color(0xFF262626),
      accent: Color(0xFF8D3C18),
    ),
    dark: (
      fill: Color(0xFF41261B),
      text: Color(0xFFEEEEEE),
      accent: Color(0xFFF89D79),
    ),
  ),
  eclass(
    light: (
      fill: Color(0xFFEBD3FF),
      text: Color(0xFF262626),
      accent: Color(0xFF6C4289),
    ),
    dark: (
      fill: Color(0xFF35273F),
      text: Color(0xFFEEEEEE),
      accent: Color(0xFFCFA1F1),
    ),
  ),
  mooc(
    light: (
      fill: Color(0xFFB8ECD1),
      text: Color(0xFF262626),
      accent: Color(0xFF026947),
    ),
    dark: (
      fill: Color(0xFF163527),
      text: Color(0xFFEEEEEE),
      accent: Color(0xFF67CFA0),
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
  if (tone != null) {
    final values = theme.brightness == Brightness.dark ? tone.dark : tone.light;
    colors = (
      fill: values.fill.withValues(alpha: values.fill.a * fillAlpha),
      text: values.text.withValues(alpha: values.text.a * foregroundAlpha),
      accent: values.accent.withValues(alpha: values.accent.a * foregroundAlpha),
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
