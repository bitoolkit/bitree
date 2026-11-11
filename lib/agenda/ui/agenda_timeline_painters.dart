part of 'agenda_timeline.dart';

/// Keep laid-out labels across frames; dates outside the working set are freed.
class _TimelineText {
  _TimelineText(this.style, this.scaler);

  final TextStyle style;
  final TextScaler scaler;
  final _painters = <(String, bool), TextPainter>{};
  late final regularDigitWidth = _digitWidth(false);
  late final boldDigitWidth = _digitWidth(true);

  TextPainter painter(String text, {bool bold = false}) {
    final key = (text, bold);
    final cached = _painters.remove(key);
    if (cached != null) {
      _painters[key] = cached;
      return cached;
    }
    final result = TextPainter(
      text: TextSpan(
        text: text,
        style: style.copyWith(
          fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    if (_painters.length == 128) {
      _painters.remove(_painters.keys.first)!.dispose();
    }
    _painters[key] = result;
    return result;
  }

  double _digitWidth(bool bold) {
    var width = 0.0;
    for (var digit = 0; digit <= 9; digit++) {
      width = math.max(width, painter('$digit', bold: bold).width);
    }
    return width;
  }

  void dispose() {
    for (final painter in _painters.values) {
      painter.dispose();
    }
    _painters.clear();
  }
}

class _TimelineGridPainter extends CustomPainter {
  const _TimelineGridPainter({
    required this.center,
    required this.now,
    required this.pixelsPerHour,
    required this.cellWidth,
    required this.scheme,
    required this.text,
    required this.header,
    required this.l10n,
  });

  final DateTime center;
  final DateTime now;
  final double pixelsPerHour;
  final double cellWidth;
  final ColorScheme scheme;
  final _TimelineText text;
  final bool header;
  final AppLocalizations l10n;

  TextPainter _text(String label, {bool bold = false}) =>
      text.painter(label, bold: bold);

  double _textWidth(String text, {bool bold = false}) {
    final painter = _text(text, bold: bold);
    return painter.width;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    double x(DateTime time) =>
        size.width / 2 +
        time.difference(center).inMicroseconds /
            _microsecondsPerHour *
            pixelsPerHour;
    final left = center.subtract(
      Duration(
        microseconds: (size.width / 2 / pixelsPerHour * _microsecondsPerHour)
            .ceil(),
      ),
    );
    final right = center.add(
      Duration(
        microseconds: (size.width / 2 / pixelsPerHour * _microsecondsPerHour)
            .ceil(),
      ),
    );
    final today = calendarDate(now);
    final tomorrow = DateTime.utc(today.year, today.month, today.day + 1);
    final dayWidth = 24 * pixelsPerHour;
    canvas.drawRect(
      Rect.fromLTRB(x(today), 0, x(tomorrow), size.height),
      Paint()..color = scheme.primary.withValues(alpha: 0.06),
    );
    final gridPaint = Paint()
      ..strokeWidth = 1
      ..color = scheme.outlineVariant.withValues(alpha: 0.65);
    // Text density must not change the grid's one-day / one-hour endpoints.
    final hourStep = <int>[1, 2, 3, 6, 12, 24].firstWhere(
      (hours) => hours * pixelsPerHour >= cellWidth - 0.001,
      orElse: () => 24,
    );
    final showHours = hourStep < 24;
    var weekdayWidth = 0.0;
    if (header) {
      for (var day = 1; day <= 7; day++) {
        for (final weekday in [localizedShortWeekday(l10n, day)]) {
          weekdayWidth = math.max(
            weekdayWidth,
            _textWidth(weekday, bold: showHours),
          );
        }
      }
    }
    final dateTextWidth = header
        ? text.boldDigitWidth * 4 + _textWidth('/', bold: true)
        : 0.0;
    // Measure the full date/weekday group, or both independent rows, so labels
    // retain stable cell centers and cannot collide when weekday text is added.
    final dateLabelWidth = header
        ? (showHours
                  ? dateTextWidth + _textWidth(' ', bold: true) + weekdayWidth
                  : math.max(dateTextWidth, weekdayWidth)) +
              8
        : 0.0;
    final hourLabelWidth = header
        ? text.regularDigitWidth * 4 + _textWidth(':') + 8
        : 0.0;
    final dayStride = math.max(1, (dateLabelWidth / dayWidth).ceil());
    final hourLabelStride = math.max(
      1,
      (hourLabelWidth / (hourStep * pixelsPerHour)).ceil(),
    );
    // Include adjacent cells based on TEXT bounds, never just tick positions.
    // Date centers remain the original day's midpoint even at huge day widths.
    final extraDays = header
        ? (math.max(dateLabelWidth, hourLabelWidth) / 2 / dayWidth).ceil() + 1
        : 0;
    var day = DateTime.utc(left.year, left.month, left.day - extraDays);
    final lastDay = DateTime.utc(
      right.year,
      right.month,
      right.day + extraDays,
    );
    while (!day.isAfter(lastDay)) {
      final nextDay = DateTime.utc(day.year, day.month, day.day + 1);
      final dayX = x(day);
      canvas.drawLine(Offset(dayX, 0), Offset(dayX, size.height), gridPaint);
      // UTC calendar ordinals give a stable stride independent of panning/DST.
      final dayOrdinal = DateTime.utc(
        day.year,
        day.month,
        day.day,
      ).difference(DateTime.utc(1970)).inDays;
      if (header && dayOrdinal % dayStride == 0) {
        final dayCenter = (dayX + x(nextDay)) / 2;
        final weekday = localizedShortWeekday(l10n, day.weekday);
        final date = '${day.month}/${day.day}';
        _label(
          canvas,
          size,
          showHours ? '$date $weekday' : date,
          Offset(dayCenter, 1),
          bold: true,
        );
        if (!showHours) {
          _label(canvas, size, weekday, Offset(dayCenter, size.height / 2));
        }
      }
      for (var hour = 0; hour < 24; hour += hourStep) {
        final tick = DateTime.utc(day.year, day.month, day.day, hour);
        final tickX = x(tick);
        if (hour != 0) {
          canvas.drawLine(
            Offset(tickX, header ? size.height / 2 : 0),
            Offset(tickX, size.height),
            gridPaint,
          );
        }
        if (header &&
            showHours &&
            (dayOrdinal * (24 ~/ hourStep) + hour ~/ hourStep) %
                    hourLabelStride ==
                0) {
          final cellEnd = DateTime.utc(
            day.year,
            day.month,
            day.day,
            hour + hourStep,
          );
          _label(
            canvas,
            size,
            '${hour.toString().padLeft(2, '0')}:00',
            Offset((tickX + x(cellEnd)) / 2, size.height / 2),
          );
        }
      }
      day = nextDay;
    }
    if (header) {
      canvas.drawLine(
        Offset(0, size.height),
        Offset(size.width, size.height),
        gridPaint,
      );
    }
    canvas.restore();
  }

  void _label(
    Canvas canvas,
    Size viewport,
    String text,
    Offset centerTop, {
    bool bold = false,
  }) {
    final painter = _text(text, bold: bold);
    final offset = Offset(centerTop.dx - painter.width / 2, centerTop.dy);
    // Full intrinsic width, fixed cell center; only the viewport clips text.
    if ((offset & painter.size).overlaps(Offset.zero & viewport)) {
      painter.paint(canvas, offset);
    }
  }

  @override
  bool shouldRepaint(covariant _TimelineGridPainter oldDelegate) =>
      oldDelegate.center != center ||
      oldDelegate.now != now ||
      oldDelegate.pixelsPerHour != pixelsPerHour ||
      oldDelegate.cellWidth != cellWidth ||
      oldDelegate.scheme != scheme ||
      oldDelegate.text != text ||
      oldDelegate.header != header ||
      oldDelegate.l10n.localeName != l10n.localeName;
}

/// Foreground decoration across header and lanes; never participates in input.
class _TimelineNowPainter extends CustomPainter {
  const _TimelineNowPainter({
    required this.center,
    required this.now,
    required this.pixelsPerHour,
    required this.color,
  });

  final DateTime center;
  final DateTime now;
  final double pixelsPerHour;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final nowX =
        size.width / 2 +
        now.difference(center).inMicroseconds /
            _microsecondsPerHour *
            pixelsPerHour;
    if (nowX < 0 || nowX > size.width) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawLine(
      Offset(nowX, 0),
      Offset(nowX, size.height),
      Paint()
        ..color = color
        ..strokeWidth = 1.5,
    );
    canvas.restore();
  }

  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(covariant _TimelineNowPainter oldDelegate) =>
      oldDelegate.center != center ||
      oldDelegate.now != now ||
      oldDelegate.pixelsPerHour != pixelsPerHour ||
      oldDelegate.color != color;
}
