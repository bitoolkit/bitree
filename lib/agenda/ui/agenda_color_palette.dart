import 'package:flutter/material.dart';

import '../agenda_color.dart';

typedef AgendaColorValues = ({Color fill, Color text, Color accent});

AgendaColorValues agendaColorValues(ColorScheme scheme, AgendaColor color) {
  final dark = scheme.brightness == Brightness.dark;
  final preset = switch (color.id) {
    'blue' =>
      dark
          ? (
              fill: const Color(0xFF1D2F44),
              text: const Color(0xFFEEEEEE),
              accent: const Color(0xFF81BCFE),
            )
          : (
              fill: const Color(0xFFC7E1FE),
              text: const Color(0xFF262626),
              accent: const Color(0xFF1A5998),
            ),
    'coral' =>
      dark
          ? (
              fill: const Color(0xFF41261B),
              text: const Color(0xFFEEEEEE),
              accent: const Color(0xFFF89D79),
            )
          : (
              fill: const Color(0xFFFFD3C2),
              text: const Color(0xFF262626),
              accent: const Color(0xFF8D3C18),
            ),
    'violet' =>
      dark
          ? (
              fill: const Color(0xFF35273F),
              text: const Color(0xFFEEEEEE),
              accent: const Color(0xFFCFA1F1),
            )
          : (
              fill: const Color(0xFFEBD3FF),
              text: const Color(0xFF262626),
              accent: const Color(0xFF6C4289),
            ),
    'green' =>
      dark
          ? (
              fill: const Color(0xFF163527),
              text: const Color(0xFFEEEEEE),
              accent: const Color(0xFF67CFA0),
            )
          : (
              fill: const Color(0xFFB8ECD1),
              text: const Color(0xFF262626),
              accent: const Color(0xFF026947),
            ),
    'amber' =>
      dark
          ? (
              fill: const Color(0xFF392B11),
              text: const Color(0xFFEEEEEE),
              accent: const Color(0xFFDFAF56),
            )
          : (
              fill: const Color(0xFFF4DAAE),
              text: const Color(0xFF262626),
              accent: const Color(0xFF735102),
            ),
    'teal' =>
      dark
          ? (
              fill: const Color(0xFF17332F),
              text: const Color(0xFFEEEEEE),
              accent: const Color(0xFF6CCDBF),
            )
          : (
              fill: const Color(0xFFBDEBE6),
              text: const Color(0xFF202525),
              accent: const Color(0xFF146C60),
            ),
    'rose' =>
      dark
          ? (
              fill: const Color(0xFF3D2029),
              text: const Color(0xFFEEEEEE),
              accent: const Color(0xFFF19AB4),
            )
          : (
              fill: const Color(0xFFF8D4DE),
              text: const Color(0xFF2A2225),
              accent: const Color(0xFF8F3854),
            ),
    'slate' =>
      dark
          ? (
              fill: const Color(0xFF29313A),
              text: const Color(0xFFEEEEEE),
              accent: const Color(0xFFA9B8C8),
            )
          : (
              fill: const Color(0xFFDDE3EA),
              text: const Color(0xFF24272B),
              accent: const Color(0xFF4F5D6E),
            ),
    _ => null,
  };
  if (preset != null) return preset;

  final source = Color(color.value);
  final hsl = HSLColor.fromColor(source);
  final accent = hsl
      .withLightness(
        dark
            ? hsl.lightness.clamp(0.58, 0.82).toDouble()
            : hsl.lightness.clamp(0.24, 0.48).toDouble(),
      )
      .toColor();
  final base = dark ? scheme.surfaceContainer : scheme.surfaceContainerLowest;
  return (
    fill: Color.alphaBlend(accent.withValues(alpha: dark ? 0.28 : 0.16), base),
    text: scheme.onSurface,
    accent: accent,
  );
}
