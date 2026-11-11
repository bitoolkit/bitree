part of 'timetable_grid.dart';

class _TimetableBackground extends CustomPainter {
  const _TimetableBackground({
    required this.rowHeight,
    required this.axis,
    required this.surfaceColor,
    required this.todayColumn,
    required this.todayBackground,
  });

  final double rowHeight;
  final TimetableAxis axis;
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
        axis.sectionStart(section + 1) * rowHeight + 2,
        size.width,
        math.max(
          0.0,
          (axis.sectionEnd(section + 1) - axis.sectionStart(section + 1)) *
                  rowHeight -
              4,
        ),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(band, const Radius.circular(4)),
        paint,
      );
    }

    if (axis.expanded) {
      paint
        ..color = surfaceColor.withValues(alpha: 0.1)
        ..strokeWidth = 0.5;
      for (final hour in [for (var h = 0; h <= 8; h++) h, 21, 22, 23, 24]) {
        final y = (axis.offsetForMinute(hour * 60.0) * rowHeight)
            .clamp(0.5, math.max(0.5, size.height - 0.5))
            .toDouble();
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
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
      axis.expanded != oldDelegate.axis.expanded ||
      surfaceColor != oldDelegate.surfaceColor ||
      todayColumn != oldDelegate.todayColumn ||
      todayBackground != oldDelegate.todayBackground;
}

/// Hour labels keep their order without colliding near midnight. Short leader
/// lines connect displaced labels to their actual non-linear tick positions.
class _HourLabels extends StatelessWidget {
  const _HourLabels({
    required this.axis,
    required this.rowHeight,
    required this.first,
    required this.last,
  });

  final TimetableAxis axis;
  final double rowHeight;
  final int first;
  final int last;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final count = last - first + 1;
      final height = constraints.maxHeight;
      final labelHeight = math.min(10.0 * scale, height / count);
      final origin = axis.offsetForMinute(first * 60.0) * rowHeight;
      final ticks = [
        for (var hour = first; hour <= last; hour++)
          axis.offsetForMinute(hour * 60.0) * rowHeight - origin,
      ];
      final tops = <double>[];
      for (final tick in ticks) {
        tops.add(
          math.max(
            tick - labelHeight / 2,
            tops.isEmpty ? 0.0 : tops.last + labelHeight,
          ),
        );
      }
      for (var index = count - 1; index >= 0; index--) {
        tops[index] = math.min(
          tops[index],
          index == count - 1
              ? height - labelHeight
              : tops[index + 1] - labelHeight,
        );
      }
      final color = Theme.of(context).colorScheme.onSurfaceVariant;
      return CustomPaint(
        painter: _HourLabelLeaders(
          ticks: ticks,
          centers: [for (final top in tops) top + labelHeight / 2],
          color: color.withValues(alpha: 0.35),
        ),
        child: Stack(
          children: [
            for (var index = 0; index < count; index++)
              Positioned(
                top: tops[index],
                height: labelHeight,
                left: 0,
                right: 6,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${(first + index).toString().padLeft(2, '0')}:00',
                    style: TextStyle(fontSize: 9, height: 1, color: color),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _HourLabelLeaders extends CustomPainter {
  const _HourLabelLeaders({
    required this.ticks,
    required this.centers,
    required this.color,
  });

  final List<double> ticks;
  final List<double> centers;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;
    for (var index = 0; index < ticks.length; index++) {
      canvas.drawLine(
        Offset(math.max(0, size.width - 5), centers[index]),
        Offset(size.width, ticks[index].clamp(0, size.height).toDouble()),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HourLabelLeaders oldDelegate) =>
      color != oldDelegate.color ||
      !listEquals(ticks, oldDelegate.ticks) ||
      !listEquals(centers, oldDelegate.centers);
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
