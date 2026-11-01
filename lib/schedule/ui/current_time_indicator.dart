import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/time.dart';
import '../section_times.dart';
import '../time_position.dart';

/// One non-interactive line over the grid, with a masked current-day segment.
class CurrentTimeIndicator extends StatelessWidget {
  const CurrentTimeIndicator({
    super.key,
    required this.now,
    required this.monday,
    required this.columnWidth,
    required this.rowHeight,
    required this.cards,
  });

  static const _lineHeight = 2.0;
  static const _horizontalInset = 3.0;

  final DateTime now;
  final DateTime monday;
  final double columnWidth;
  final double rowHeight;
  final List<({RRect shape, Color color})> cards;

  /// Shared grid-space center for the time line and the elapsed course fill.
  static double centerAt(double section, double rowHeight) {
    final gridHeight = rowHeight * sectionTimes.length;
    return (section * rowHeight - _lineHeight / 2)
            .clamp(0.0, gridHeight - _lineHeight)
            .toDouble() +
        _lineHeight / 2;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final position = timeIndicatorPositionAt(now);
    final day = calendarDate(position.time)
        .difference(calendarDate(monday))
        .inDays;
    final gridHeight = rowHeight * sectionTimes.length;
    if (day < 0 ||
        day >= 7 ||
        columnWidth <= _horizontalInset * 2 ||
        gridHeight < _lineHeight) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: ExcludeSemantics(
        child: CustomPaint(
          painter: _TimeLinePainter(
            center: centerAt(position.section, rowHeight),
            day: day,
            columnWidth: columnWidth,
            color: theme.colorScheme.primary,
            cardBlendMode: theme.brightness == Brightness.dark
                ? BlendMode.screen
                : BlendMode.multiply,
            cards: cards,
          ),
        ),
      ),
    );
  }
}

class _TimeLinePainter extends CustomPainter {
  const _TimeLinePainter({
    required this.center,
    required this.day,
    required this.columnWidth,
    required this.color,
    required this.cardBlendMode,
    required this.cards,
  });

  final double center;
  final int day;
  final double columnWidth;
  final Color color;
  final BlendMode cardBlendMode;
  final List<({RRect shape, Color color})> cards;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = CurrentTimeIndicator._horizontalInset;
    final currentLine = Rect.fromLTWH(
      day * columnWidth + inset,
      center - 1,
      columnWidth - inset * 2,
      2,
    );
    final paint = Paint()..color = color.withValues(alpha: 0.42);
    // The faint line sits directly over every other day's cards. Do not mix it
    // into the strong segment or expose strong-colour stubs in the card insets.
    canvas.drawRect(
      Rect.fromLTRB(0, center - 0.5, currentLine.left, center + 0.5),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTRB(currentLine.right, center - 0.5, size.width, center + 0.5),
      paint,
    );
    final crossed = cards
        .where((card) => card.shape.outerRect.overlaps(currentLine))
        .toList();
    final outlines = Path();
    for (final card in crossed) {
      outlines.addRRect(card.shape);
    }

    // Keep the original colour around the current card's rounded corners.
    canvas.save();
    canvas.clipPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(currentLine),
        outlines,
      ),
    );
    canvas.drawRect(currentLine, paint..color = color);
    canvas.restore();

    // Darken light cards and lighten dark cards while retaining their text.
    for (final card in crossed) {
      canvas.save();
      canvas.clipRRect(card.shape);
      canvas.drawRect(
        currentLine,
        paint
          ..color = card.color
          ..blendMode = cardBlendMode,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_TimeLinePainter oldDelegate) =>
      center != oldDelegate.center ||
      day != oldDelegate.day ||
      columnWidth != oldDelegate.columnWidth ||
      color != oldDelegate.color ||
      cardBlendMode != oldDelegate.cardBlendMode ||
      !listEquals(cards, oldDelegate.cards);
}
