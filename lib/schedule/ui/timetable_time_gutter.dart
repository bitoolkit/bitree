import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../section_times.dart';
import '../timetable_axis.dart';

/// Shared teaching-period labels and hourly ticks for both timetable modes.
class TimetableTimeGutter extends StatelessWidget {
  const TimetableTimeGutter({
    super.key,
    required this.axis,
    required this.rowHeight,
  });

  final TimetableAxis axis;
  final double rowHeight;

  static const _numberStyle = TextStyle(
    fontSize: 13,
    height: 1.2,
    fontWeight: FontWeight.w500,
  );
  static const _clockStyle = TextStyle(fontSize: 10, height: 1.2);

  /// Leave enough width for labels at their real font sizes, including the
  /// user's font family and accessibility scaling.
  static double preferredWidth(BuildContext context) {
    double measure(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: DefaultTextStyle.of(context).style.merge(style),
        ),
        textScaler: MediaQuery.textScalerOf(context),
        textDirection: Directionality.of(context),
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final scale = MediaQuery.textScalerOf(context).scale(1);
    return math.max(
      30 * scale,
      math.max(measure('13', _numberStyle), measure('23:59', _clockStyle)) +
          4 * scale,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final height = axis.length * rowHeight;
    final minutes =
        <int>{
              if (axis.expanded) ...[
                axis.startMinute,
                axis.endMinute,
                for (
                  var hour = 0;
                  hour < TimetableAxis.periods.first.start ~/ 60;
                  hour++
                )
                  hour * 60,
                for (
                  var hour = TimetableAxis.eveningStart ~/ 60;
                  hour <= 24;
                  hour++
                )
                  hour * 60,
              ],
            }
            .where(
              (minute) =>
                  minute >= axis.startMinute &&
                  minute <= axis.endMinute &&
                  (minute < TimetableAxis.periods.first.start ||
                      minute >= TimetableAxis.eveningStart),
            )
            .toList()
          ..sort();
    final ticks = [
      for (final minute in minutes)
        axis.offsetForMinute(minute.toDouble()) * rowHeight,
    ];
    final labelHeights = [
      for (var index = 0; index < ticks.length; index++)
        math.min(
          math.min(scaler.scale(10) * 1.2, height),
          math.min(
            index == 0 ? double.infinity : ticks[index] - ticks[index - 1],
            index == ticks.length - 1
                ? double.infinity
                : ticks[index + 1] - ticks[index],
          ),
        ),
    ];
    if (ticks.length > 1) {
      if (ticks.first == 0) {
        labelHeights[0] = math.min(
          labelHeights[0],
          ticks[1] - labelHeights[1] / 2,
        );
      }
      if (ticks.last == height) {
        final last = ticks.length - 1;
        labelHeights[last] = math.min(
          labelHeights[last],
          height - ticks[last - 1] - labelHeights[last - 1] / 2,
        );
      }
    }
    final clocks = [
      for (var index = 0; index < minutes.length; index++)
        (
          minute: minutes[index],
          top: (ticks[index] - labelHeights[index] / 2)
              .clamp(0.0, math.max(0.0, height - labelHeights[index]))
              .toDouble(),
          height: labelHeights[index],
        ),
    ];

    // Keep boundary ticks clear of the neighboring teaching-period labels.
    ({double top, double height}) periodSpace(int section) {
      final start = axis.sectionStart(section) * rowHeight;
      final end = axis.sectionEnd(section) * rowHeight;
      var cursor = start;
      var bestTop = start;
      var bestHeight = 0.0;
      for (final clock in clocks) {
        final clockStart = clock.top - scaler.scale(1);
        final clockEnd = clock.top + clock.height + scaler.scale(1);
        if (clockEnd <= start || clockStart >= end) continue;
        if (clockStart - cursor > bestHeight) {
          bestTop = cursor;
          bestHeight = clockStart - cursor;
        }
        cursor = math.max(cursor, clockEnd).clamp(start, end).toDouble();
      }
      if (end - cursor > bestHeight) {
        bestTop = cursor;
        bestHeight = end - cursor;
      }
      return (top: bestTop, height: bestHeight);
    }

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          for (var section = 1; section <= sectionTimes.length; section++)
            if (axis.sectionEnd(section) > axis.sectionStart(section))
              Positioned(
                top: periodSpace(section).top,
                height: periodSpace(section).height,
                left: 0,
                right: 0,
                child: _PeriodLabel(
                  key: ValueKey(('timetable-period-label', section)),
                  section: section,
                ),
              ),
          for (final clock in clocks)
            Positioned(
              top: clock.top,
              height: clock.height,
              left: 0,
              right: 0,
              child: ClipRect(
                key: ValueKey(('timetable-hour-slot', clock.minute)),
                child: OverflowBox(
                  minHeight: 0,
                  maxHeight: double.infinity,
                  child: _ClockText(
                    key: ValueKey(('timetable-hour', clock.minute)),
                    text:
                        '${(clock.minute ~/ 60).toString().padLeft(2, '0')}:${(clock.minute % 60).toString().padLeft(2, '0')}',
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
  const _PeriodLabel({super.key, required this.section});

  final int section;

  @override
  Widget build(BuildContext context) {
    final time = sectionTimes[section - 1];
    final scaler = MediaQuery.textScalerOf(context);
    final spacing = scaler.scale(2);
    final compactHeight = (scaler.scale(13) + scaler.scale(10)) * 1.2 + spacing;
    final fullHeight = compactHeight + scaler.scale(10) * 1.2;
    return Semantics(
      label: context.l10n.sectionSemantics(section, time.$1, time.$2),
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showEnd = constraints.maxHeight >= fullHeight;
            final showNumber = constraints.maxHeight >= compactHeight;
            final number = Text(
              '$section',
              key: ValueKey(('timetable-period-number', section)),
              maxLines: 1,
              softWrap: false,
              style: TimetableTimeGutter._numberStyle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            );
            final start = _ClockText(
              key: ValueKey(('timetable-period-start', section)),
              text: time.$1,
            );
            return ClipRect(
              child: OverflowBox(
                minHeight: 0,
                maxHeight: double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showNumber) ...[number, SizedBox(height: spacing)],
                    start,
                    if (showEnd)
                      _ClockText(
                        key: ValueKey(('timetable-period-end', section)),
                        text: time.$2,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ClockText extends StatelessWidget {
  const _ClockText({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    maxLines: 1,
    softWrap: false,
    style: TimetableTimeGutter._clockStyle.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}
