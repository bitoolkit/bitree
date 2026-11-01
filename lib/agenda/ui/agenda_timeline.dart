import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../app/controller.dart';
import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../schedule/model.dart';
import '../model.dart';
import '../timeline_layout.dart';
import 'agenda_detail.dart';
import 'timeline_entry.dart';

const _microsecondsPerHour = Duration.microsecondsPerSecond * 3600;
const _minimumEventWidth = 2.0;

/// A viewport-sized timeline: panning changes a date, not a giant scroll offset.
class AgendaTimeline extends StatefulWidget {
  const AgendaTimeline({
    super.key,
    required this.controller,
    required this.entries,
    required this.now,
    this.active = true,
    this.visible = true,
  });

  final AppController controller;
  final List<AgendaEntry> entries;
  final DateTime now;

  /// Reset the date on page re-entry, not when changing list/timeline mode.
  final bool active;

  /// Stop motion when list mode hides this retained timeline, without resetting.
  final bool visible;

  @override
  State<AgendaTimeline> createState() => _AgendaTimelineState();
}

class _AgendaTimelineState extends State<AgendaTimeline>
    with TickerProviderStateMixin {
  final ScrollController _lanes = ScrollController();
  late final AnimationController _horizontalFling;
  late final AnimationController _verticalFling;
  double _lastHorizontal = 0;
  double _lastVertical = 0;
  double _flingPixelsPerHour = 1;
  bool _gestureHadMultiplePointers = false;
  bool _gestureScaled = false;
  bool _gestureTrackpad = false;
  final Set<int> _downPointers = <int>{};
  final Set<int> _panZoomPointers = <int>{};
  late DateTime _center;
  double _zoom = 1;
  double _gestureZoom = 1;
  int _gesturePointers = 0;
  DateTime? _gestureAnchor;
  List<AgendaEntry>? _cachedEntries;
  Duration? _cachedMinimumEventSpan;
  List<AgendaTimelinePlacement> _cachedPlacements = const [];
  final Map<String, DateTime> _nextStartById = {};

  List<AgendaTimelinePlacement> _layout(Duration minimumEventSpan) {
    if (!identical(_cachedEntries, widget.entries) ||
        _cachedMinimumEventSpan != minimumEventSpan) {
      _cachedEntries = widget.entries;
      _cachedMinimumEventSpan = minimumEventSpan;
      _cachedPlacements = layoutAgendaTimeline(
        widget.entries,
        minimumEventSpan: minimumEventSpan,
      );
      _nextStartById.clear();
      final nextByLane = <int, DateTime>{};
      for (final placement in _cachedPlacements.reversed) {
        final next = nextByLane[placement.lane];
        if (next != null) _nextStartById[placement.entry.id] = next;
        nextByLane[placement.lane] = placement.start;
      }
    }
    return _cachedPlacements;
  }

  @override
  void initState() {
    super.initState();
    _center = calendarDate(widget.now).add(const Duration(hours: 12));
    _lanes.addListener(_laneChanged);
    _horizontalFling = AnimationController.unbounded(vsync: this)
      ..addListener(_tickHorizontal);
    _verticalFling = AnimationController.unbounded(vsync: this)
      ..addListener(_tickVertical);
  }

  void _stopMotion() {
    _horizontalFling.stop();
    _verticalFling.stop();
  }

  void _tickHorizontal() {
    final delta = _horizontalFling.value - _lastHorizontal;
    _lastHorizontal = _horizontalFling.value;
    if (!mounted || !widget.active || !widget.visible) return;
    setState(() {
      _center = _center.subtract(
        Duration(
          microseconds: (delta / _flingPixelsPerHour * _microsecondsPerHour)
              .round(),
        ),
      );
    });
  }

  void _tickVertical() {
    final delta = _verticalFling.value - _lastVertical;
    _lastVertical = _verticalFling.value;
    if (!_lanes.hasClients || !widget.active || !widget.visible) {
      _verticalFling.stop();
      return;
    }
    final target = _lanes.offset - delta;
    _scrollLanes(-delta);
    if (target <= 0 || target >= _lanes.position.maxScrollExtent) {
      _verticalFling.stop();
    }
  }

  void _startFling(Offset velocity, double pixelsPerHour) {
    if (!widget.active ||
        !widget.visible ||
        _gestureHadMultiplePointers ||
        _gestureScaled ||
        _gestureTrackpad) {
      return;
    }
    _flingPixelsPerHour = pixelsPerHour;
    // Framework friction supplies both axes; only the viewport/date is moved.
    if (velocity.dx.abs() >= 50) {
      _lastHorizontal = 0;
      _horizontalFling.value = 0;
      _horizontalFling.animateWith(FrictionSimulation(0.135, 0, velocity.dx));
    }
    if (velocity.dy.abs() >= 50 && _lanes.hasClients) {
      _lastVertical = 0;
      _verticalFling.value = 0;
      _verticalFling.animateWith(FrictionSimulation(0.135, 0, velocity.dy));
    }
  }

  @override
  void didUpdateWidget(covariant AgendaTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible) {
      _stopMotion();
      _gestureAnchor = null;
      _downPointers.clear();
      _panZoomPointers.clear();
    }
    if (oldWidget.active != widget.active) {
      _stopMotion();
      _gestureAnchor = null;
      _downPointers.clear();
      _panZoomPointers.clear();
      if (widget.active) {
        _center = calendarDate(widget.now).add(const Duration(hours: 12));
      }
    }
  }

  @override
  void deactivate() {
    _stopMotion();
    _gestureAnchor = null;
    _downPointers.clear();
    _panZoomPointers.clear();
    super.deactivate();
  }

  void _laneChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _stopMotion();
    _horizontalFling.dispose();
    _verticalFling.dispose();
    _lanes.removeListener(_laneChanged);
    _lanes.dispose();
    super.dispose();
  }

  DateTime _timeAt(double x, double width, double pixelsPerHour) => _center.add(
    Duration(
      microseconds: ((x - width / 2) / pixelsPerHour * _microsecondsPerHour)
          .round(),
    ),
  );

  void _scrollLanes(double delta) {
    if (!_lanes.hasClients) return;
    _lanes.jumpTo(
      (_lanes.offset + delta)
          .clamp(0.0, _lanes.position.maxScrollExtent)
          .toDouble(),
    );
  }

  void _zoomAt(double zoom, double x, double width, double baseline) {
    _stopMotion();
    final anchor = _timeAt(x, width, baseline * _zoom);
    final next = zoom.clamp(1.0, 24.0).toDouble();
    setState(() {
      _zoom = next;
      _center = anchor.subtract(
        Duration(
          microseconds:
              ((x - width / 2) / (baseline * next) * _microsecondsPerHour)
                  .round(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final fontScale = math.max(1.0, textScaler.scale(14) / 14);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cellWidth = (width / 5).clamp(80.0, 140.0).toDouble() * 0.6;
        final baseline = cellWidth / 24;
        final pixelsPerHour = baseline * _zoom;
        final hoursPerCell = 24 / _zoom;
        final scaleLabel = _zoom == 1
            ? l10n.agendaTimelineOneDay
            : _zoom == 24
            ? l10n.agendaTimelineOneHour
            : l10n.agendaTimelineHours(hoursPerCell.toStringAsFixed(1));
        double textHeight(double fontSize, double height) {
          final measure = TextPainter(
            text: TextSpan(
              text: '${l10n.agendaTitle} Ag',
              style: TextStyle(fontSize: fontSize, height: height),
            ),
            textScaler: textScaler,
            textDirection: TextDirection.ltr,
          )..layout();
          final result = measure.height;
          measure.dispose();
          return result;
        }

        final baseHeaderStyle =
            theme.textTheme.labelMedium ?? const TextStyle(fontSize: 12);
        final headerStyle = baseHeaderStyle.copyWith(
          fontSize: (baseHeaderStyle.fontSize ?? 12) * 5 / 6,
          height: 1,
        );
        final headerHeight = math.max(
          24.0 * fontScale,
          textHeight(headerStyle.fontSize!, 1) * 2 + 4,
        );
        final barHeight = math.max(
          56.0 * fontScale,
          textHeight(14, 1.2) +
              math.max(textHeight(12, 1.2) * 2, 13 * fontScale) +
              10,
        );
        final laneHeight = barHeight + 12;
        // Width is set by the MINIMUM zoom, never by the current zoom.
        final deadlineWidth = cellWidth * 3.75;
        final deadlineDuration = Duration(
          microseconds: (deadlineWidth / pixelsPerHour * _microsecondsPerHour)
              .ceil(),
        );
        final minimumEventSpan = Duration(
          // The visual floor is fixed and does not scale with accessibility text.
          microseconds:
              (_minimumEventWidth / pixelsPerHour * _microsecondsPerHour)
                  .ceil(),
        );
        final placements = _layout(minimumEventSpan);
        final laneCount = placements.fold<int>(
          0,
          (count, placement) => math.max(count, placement.lane + 1),
        );
        final left = _timeAt(0, width, pixelsPerHour);
        final right = _timeAt(width, width, pixelsPerHour);
        final painter = _TimelineGridPainter(
          center: _center,
          now: widget.now,
          pixelsPerHour: pixelsPerHour,
          cellWidth: cellWidth,
          scheme: theme.colorScheme,
          textStyle: headerStyle,
          textScaler: textScaler,
          header: true,
          l10n: l10n,
        );

        return Listener(
          onPointerDown: (_) => _stopMotion(),
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) _stopMotion();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        _stopMotion();
                        setState(() {
                          _center = calendarDate(widget.now)
                              .add(const Duration(hours: 12));
                        });
                      },
                      icon: const Icon(Icons.today_outlined, size: 18),
                      label: Text(l10n.today),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Tooltip(
                        message: l10n.agendaTimelineZoom,
                        child: Slider(
                          value: _zoom,
                          min: 1,
                          max: 24,
                          semanticFormatterCallback: (_) => scaleLabel,
                          onChanged: (value) =>
                              _zoomAt(value, width / 2, width, baseline),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Listener(
                  onPointerDown: (event) {
                    _stopMotion();
                    if (_downPointers.isEmpty) {
                      _gestureHadMultiplePointers = false;
                    }
                    _downPointers.add(event.pointer);
                    if (_downPointers.length > 1) {
                      _gestureHadMultiplePointers = true;
                    }
                  },
                  onPointerUp: (event) => _downPointers.remove(event.pointer),
                  onPointerCancel: (event) {
                    _downPointers.remove(event.pointer);
                    _panZoomPointers.remove(event.pointer);
                    _gestureHadMultiplePointers = true;
                    _stopMotion();
                  },
                  onPointerPanZoomStart: (event) {
                    _stopMotion();
                    if (_panZoomPointers.isEmpty && _downPointers.isEmpty) {
                      _gestureHadMultiplePointers = false;
                    }
                    _panZoomPointers.add(event.pointer);
                  },
                  onPointerPanZoomEnd: (event) =>
                      _panZoomPointers.remove(event.pointer),
                  onPointerSignal: (event) {
                    if (event is! PointerScrollEvent) return;
                    _stopMotion();
                    GestureBinding.instance.pointerSignalResolver.register(
                      event,
                      (resolved) {
                        final scroll = resolved as PointerScrollEvent;
                        final keys =
                            HardwareKeyboard.instance.logicalKeysPressed;
                        final control =
                            keys.contains(LogicalKeyboardKey.controlLeft) ||
                            keys.contains(LogicalKeyboardKey.controlRight);
                        final shift =
                            keys.contains(LogicalKeyboardKey.shiftLeft) ||
                            keys.contains(LogicalKeyboardKey.shiftRight);
                        final delta = scroll.scrollDelta.dy != 0
                            ? scroll.scrollDelta.dy
                            : scroll.scrollDelta.dx;
                        if (control) {
                          _zoomAt(
                            _zoom * math.exp(-delta / 350),
                            scroll.localPosition.dx,
                            width,
                            baseline,
                          );
                        } else if (shift) {
                          _scrollLanes(delta);
                        } else {
                          setState(() {
                            _center = _center.add(
                              Duration(
                                microseconds:
                                    ((scroll.scrollDelta.dx +
                                                scroll.scrollDelta.dy) /
                                            pixelsPerHour *
                                            _microsecondsPerHour)
                                        .round(),
                              ),
                            );
                          });
                        }
                      },
                    );
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: (details) {
                      _stopMotion();
                      _gestureTrackpad = _panZoomPointers.isNotEmpty;
                      _gestureHadMultiplePointers =
                          _gestureHadMultiplePointers ||
                          (!_gestureTrackpad &&
                              (details.pointerCount > 1 ||
                                  _downPointers.length > 1));
                      _gestureScaled = false;
                      _gesturePointers = details.pointerCount;
                      _gestureZoom = _zoom;
                      _gestureAnchor = _timeAt(
                        details.localFocalPoint.dx,
                        width,
                        pixelsPerHour,
                      );
                    },
                    onScaleUpdate: (details) {
                      if (!_gestureTrackpad && details.pointerCount > 1) {
                        _gestureHadMultiplePointers = true;
                      }
                      // Pan/zoom events identify trackpads, regardless of whether
                      // the recognizer reports zero or virtual multiple pointers.
                      // Native trackpad momentum must never get a second fling.
                      if ((details.scale - 1).abs() > 0.0001) {
                        _gestureScaled = true;
                      }
                      // Adding/removing a finger changes the focal point. Rebase so
                      // that transition does not jump to another calendar time.
                      if (_gesturePointers != details.pointerCount) {
                        _gestureAnchor = _timeAt(
                          details.localFocalPoint.dx,
                          width,
                          baseline * _zoom,
                        );
                        _gestureZoom = _zoom / details.scale;
                        _gesturePointers = details.pointerCount;
                      }
                      final next = (_gestureZoom * details.scale)
                          .clamp(1.0, 24.0)
                          .toDouble();
                      final anchor = _gestureAnchor;
                      if (anchor == null) return;
                      setState(() {
                        _zoom = next;
                        _center = anchor.subtract(
                          Duration(
                            microseconds:
                                ((details.localFocalPoint.dx - width / 2) /
                                        (baseline * next) *
                                        _microsecondsPerHour)
                                    .round(),
                          ),
                        );
                      });
                      if ((_gestureTrackpad || details.pointerCount <= 1) &&
                          !_gestureHadMultiplePointers &&
                          !_gestureScaled) {
                        _scrollLanes(-details.focalPointDelta.dy);
                      }
                    },
                    onScaleEnd: (details) {
                      final hadAnchor = _gestureAnchor != null;
                      _gestureAnchor = null;
                      if (hadAnchor) {
                        _startFling(
                          details.velocity.pixelsPerSecond,
                          baseline * _zoom,
                        );
                      }
                    },
                    child: CustomPaint(
                      foregroundPainter: _TimelineNowPainter(
                        center: _center,
                        now: widget.now,
                        pixelsPerHour: pixelsPerHour,
                        color: theme.colorScheme.error,
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            height: headerHeight,
                            width: width,
                            child: CustomPaint(painter: painter),
                          ),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, laneConstraints) {
                                final height = laneConstraints.maxHeight;
                                final contentHeight = math.max(
                                  height,
                                  laneCount * laneHeight + 24,
                                );
                                final offset = _lanes.hasClients
                                    ? _lanes.offset
                                    : 0.0;
                                final visible = placements.where(
                                  (placement) =>
                                      placement.layoutEnd.isAfter(left) &&
                                      (placement.entry.isDeadline
                                              ? placement.end.subtract(
                                                  deadlineDuration,
                                                )
                                              : placement.start)
                                          .isBefore(right) &&
                                      (placement.lane + 1) * laneHeight >=
                                          offset &&
                                      placement.lane * laneHeight + 12 <=
                                          offset + height,
                                );
                                return Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CustomPaint(
                                      painter: _TimelineGridPainter(
                                        center: _center,
                                        now: widget.now,
                                        pixelsPerHour: pixelsPerHour,
                                        cellWidth: cellWidth,
                                        scheme: theme.colorScheme,
                                        textStyle: headerStyle,
                                        textScaler: textScaler,
                                        header: false,
                                        l10n: l10n,
                                      ),
                                    ),
                                    ScrollConfiguration(
                                      behavior: ScrollConfiguration.of(context)
                                          .copyWith(scrollbars: false),
                                      child: SingleChildScrollView(
                                        controller: _lanes,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        child: SizedBox(
                                          height: contentHeight,
                                          width: width,
                                          child: Stack(
                                            clipBehavior: Clip.hardEdge,
                                            children: [
                                              for (final placement in visible)
                                                _buildEntry(
                                                  context,
                                                  placement,
                                                  width,
                                                  pixelsPerHour,
                                                  laneHeight,
                                                  deadlineWidth,
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (widget.entries.isEmpty)
                                      Center(
                                        child: IgnorePointer(
                                          child: Padding(
                                            padding: const EdgeInsets.all(24),
                                            child: Text(
                                              l10n.agendaTimelineEmpty,
                                              textAlign: TextAlign.center,
                                              style: theme.textTheme.bodyLarge
                                                  ?.copyWith(
                                                    color: theme
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEntry(
    BuildContext context,
    AgendaTimelinePlacement placement,
    double width,
    double pixelsPerHour,
    double laneHeight,
    double deadlineWidth,
  ) {
    final entry = placement.entry;
    double x(DateTime time) =>
        width / 2 +
        time.difference(_center).inMicroseconds /
            _microsecondsPerHour *
            pixelsPerHour;
    final actualRight = x(placement.layoutEnd);
    final actualLeft = entry.isDeadline
        ? actualRight - deadlineWidth
        : x(placement.start);
    // Crop long ordinary events before creating widgets; no huge canvas/boxes.
    final left = entry.isDeadline ? actualLeft : math.max(0.0, actualLeft);
    final right = entry.isDeadline ? actualRight : math.min(width, actualRight);
    final barWidth = math.max(0.0, right - left);
    final nextStart = _nextStartById[entry.id];
    final availableWidth = nextStart == null
        ? double.infinity
        : math.max(0.0, x(nextStart) - left);
    final tapWidth = math.min(math.max(24.0, barWidth), availableWidth);
    return Positioned(
      left: left,
      top: placement.lane * laneHeight + 12,
      width: tapWidth,
      height: laneHeight - 12,
      child: AgendaTimelineEntry(
        entry: entry,
        now: widget.now,
        barWidth: barWidth,
        deadlineWidth: deadlineWidth,
        onTap: () => showAgendaEntry(context, widget.controller, entry),
      ),
    );
  }
}

class _TimelineGridPainter extends CustomPainter {
  const _TimelineGridPainter({
    required this.center,
    required this.now,
    required this.pixelsPerHour,
    required this.cellWidth,
    required this.scheme,
    required this.textStyle,
    required this.textScaler,
    required this.header,
    required this.l10n,
  });

  final DateTime center;
  final DateTime now;
  final double pixelsPerHour;
  final double cellWidth;
  final ColorScheme scheme;
  final TextStyle textStyle;
  final TextScaler textScaler;
  final bool header;
  final AppLocalizations l10n;

  TextPainter _text(String text, {bool bold = false}) => TextPainter(
    text: TextSpan(
      text: text,
      style: textStyle.copyWith(
        color: scheme.onSurfaceVariant,
        fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
      ),
    ),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
    maxLines: 1,
  )..layout();

  double _textWidth(String text, {bool bold = false}) {
    final painter = _text(text, bold: bold);
    final width = painter.width;
    painter.dispose();
    return width;
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
    double maxDigitWidth(bool bold) {
      var width = 0.0;
      for (var digit = 0; digit <= 9; digit++) {
        width = math.max(width, _textWidth('$digit', bold: bold));
      }
      return width;
    }

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
        ? maxDigitWidth(true) * 4 + _textWidth('/', bold: true)
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
        ? maxDigitWidth(false) * 4 + _textWidth(':') + 8
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
    painter.dispose();
  }

  @override
  bool shouldRepaint(covariant _TimelineGridPainter oldDelegate) =>
      oldDelegate.center != center ||
      oldDelegate.now != now ||
      oldDelegate.pixelsPerHour != pixelsPerHour ||
      oldDelegate.cellWidth != cellWidth ||
      oldDelegate.scheme != scheme ||
      oldDelegate.textStyle != textStyle ||
      oldDelegate.textScaler != textScaler ||
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
