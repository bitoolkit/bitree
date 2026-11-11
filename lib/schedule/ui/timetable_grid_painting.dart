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
      for (final hour in [
        for (var h = 0; h <= TimetableAxis.morningEnd ~/ 60; h++) h,
        for (var h = TimetableAxis.eveningStart ~/ 60; h <= 24; h++) h,
      ]) {
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

/// Time labels stay centered on their mapped ticks. Only their size changes
/// when neighboring ticks are close together; midnight endpoints stay inside.
class _ExpandedTimeLabels extends StatelessWidget {
  const _ExpandedTimeLabels({required this.axis, required this.rowHeight});

  final TimetableAxis axis;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    final height = axis.length * rowHeight;
    final times = <int, ({String text, bool teaching})>{
      for (var hour = 0; hour <= TimetableAxis.morningEnd ~/ 60; hour++)
        hour * 60: (
          text: '${hour.toString().padLeft(2, '0')}:00',
          teaching: false,
        ),
      for (final period in sectionTimes)
        TimetableAxis.clockMinute(period.$1): (text: period.$1, teaching: true),
      for (var hour = TimetableAxis.eveningStart ~/ 60; hour <= 24; hour++)
        hour * 60: (text: '$hour:00', teaching: false),
    }.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final ticks = [
      for (final time in times)
        axis.offsetForMinute(time.key.toDouble()) * rowHeight,
    ];
    final labelHeights = [
      for (var index = 0; index < ticks.length; index++)
        math.min(
          times[index].value.teaching
              ? math.min(10.0 * scale, rowHeight * 0.4)
              : 10.0 * scale,
          math.min(
            index == 0 ? double.infinity : ticks[index] - ticks[index - 1],
            index == ticks.length - 1
                ? double.infinity
                : ticks[index + 1] - ticks[index],
          ),
        ),
    ];
    // Endpoints sit fully inside the grid; leave room for their neighbors
    // without moving either neighbor away from its time coordinate.
    labelHeights[0] = math.min(labelHeights[0], ticks[1] - labelHeights[1] / 2);
    final last = ticks.length - 1;
    labelHeights[last] = math.min(
      labelHeights[last],
      ticks[last] - ticks[last - 1] - labelHeights[last - 1] / 2,
    );

    double sectionNumberHeight(int section) {
      final start = axis.sectionStart(section) * rowHeight;
      final end = axis.sectionEnd(section) * rowHeight;
      final center = (start + end) / 2;
      var available = math.min(13.0 * scale, (end - start) * 0.4);
      for (var index = 0; index < ticks.length; index++) {
        available = math.min(
          available,
          math.max(
            0.0,
            (center - ticks[index]).abs() * 2 - labelHeights[index],
          ),
        );
      }
      return available;
    }

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          for (var index = 0; index < times.length; index++)
            Positioned(
              top: (ticks[index] - labelHeights[index] / 2)
                  .clamp(0.0, math.max(0.0, height - labelHeights[index]))
                  .toDouble(),
              height: labelHeights[index],
              left: 0,
              right: 0,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  times[index].value.text,
                  style: TextStyle(fontSize: 9, height: 1, color: color),
                ),
              ),
            ),
          for (var section = 1; section <= sectionTimes.length; section++)
            Positioned(
              top: axis.sectionStart(section) * rowHeight,
              height:
                  (axis.sectionEnd(section) - axis.sectionStart(section)) *
                  rowHeight,
              left: 0,
              right: 0,
              child: Semantics(
                label: context.l10n.sectionSemantics(
                  section,
                  sectionTimes[section - 1].$1,
                  sectionTimes[section - 1].$2,
                ),
                child: ExcludeSemantics(
                  child: Center(
                    child: SizedBox(
                      height: sectionNumberHeight(section),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$section',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1,
                            color: color,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
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
