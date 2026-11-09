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
    const radius = Radius.circular(6);

    for (var section = 1; section < sectionTimes.length; section += 2) {
      paint.color = surfaceColor.withValues(alpha: 0.025);
      final band = Rect.fromLTWH(
        0,
        section * rowHeight + 2,
        size.width,
        math.max(0.0, rowHeight - 4),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(band, const Radius.circular(4)),
        paint,
      );
    }

    if (todayColumn != null) {
      final column = Rect.fromLTWH(
        todayColumn! * columnWidth + 2,
        0,
        math.max(0.0, columnWidth - 4),
        size.height,
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          column,
          bottomLeft: radius,
          bottomRight: radius,
        ),
        paint..color = todayBackground,
      );
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
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
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
                        fontSize: 10,
                        height: 1.2,
                        color: scheme.onSurfaceVariant,
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
