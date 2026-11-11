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
      if (axis.sectionEnd(section + 1) <= axis.sectionStart(section + 1)) {
        continue;
      }
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
        for (var h = 0; h < TimetableAxis.periods.first.start ~/ 60; h++) h,
        for (var h = TimetableAxis.eveningStart ~/ 60; h <= 24; h++) h,
      ]) {
        if (hour * 60 < axis.startMinute || hour * 60 > axis.endMinute) {
          continue;
        }
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
      axis.startMinute != oldDelegate.axis.startMinute ||
      axis.endMinute != oldDelegate.axis.endMinute ||
      surfaceColor != oldDelegate.surfaceColor ||
      todayColumn != oldDelegate.todayColumn ||
      todayBackground != oldDelegate.todayBackground;
}
