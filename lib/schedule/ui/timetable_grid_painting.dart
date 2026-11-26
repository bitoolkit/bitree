part of 'timetable_grid.dart';

class _TimetableBackground extends CustomPainter {
  const _TimetableBackground({
    required this.rowHeight,
    required this.surfaceColor,
    required this.todayColumn,
    required this.todayBackground,
  });

  final double rowHeight;
  final Color surfaceColor;
  final int? todayColumn;
  final Color todayBackground;

  @override
  void paint(Canvas canvas, Size size) {
    final columnWidth = size.width / 7;
    final paint = Paint();

    // Subtle alternating row bands so eyes can track periods across all 7 days.
    paint.color = surfaceColor.withValues(alpha: 0.032);
    for (var section = 1; section < sectionTimes.length; section += 2) {
      canvas.drawRect(
        Rect.fromLTWH(0, section * rowHeight, size.width, rowHeight),
        paint,
      );
    }

    if (todayColumn != null) {
      final column = Rect.fromLTWH(
        todayColumn! * columnWidth,
        0,
        columnWidth,
        size.height,
      );
      canvas.drawRect(column, paint..color = todayBackground);
    }

    final verticalLine = Paint()
      ..color = surfaceColor.withValues(alpha: 0.09)
      ..strokeWidth = 1;
    for (var day = 0; day < 7; day++) {
      final x = day * columnWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), verticalLine);
    }

    for (var section = 1; section < sectionTimes.length; section++) {
      final y = section * rowHeight;
      final isMajorBreak = section == 5 || section == 10;
      final linePaint = Paint()
        ..color = surfaceColor.withValues(alpha: isMajorBreak ? 0.20 : 0.09)
        ..strokeWidth = isMajorBreak ? 1.25 : 1;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(_TimetableBackground oldDelegate) =>
      rowHeight != oldDelegate.rowHeight ||
      surfaceColor != oldDelegate.surfaceColor ||
      todayColumn != oldDelegate.todayColumn ||
      todayBackground != oldDelegate.todayBackground;
}

class _PeriodLabel extends StatelessWidget {
  const _PeriodLabel({required this.section});

  final int section;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final time = sectionTimes[section - 1];
    return Semantics(
      label: l10n.sectionSemantics(section, time.$1, time.$2),
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(1);
            if (constraints.maxHeight < 44 * scale) {
              return FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$section\n${time.$1}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              );
            }
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$section',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${time.$1}\n${time.$2}',
                      softWrap: false,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9.5,
                        height: 1.2,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
