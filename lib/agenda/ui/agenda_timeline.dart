import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../core/time.dart';
import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../controller.dart';
import '../model.dart';
import '../timeline_layout.dart';
import 'agenda_detail.dart';
import 'timeline_entry.dart';

part 'agenda_timeline_painters.dart';

const _microsecondsPerHour = Duration.microsecondsPerSecond * 3600;
const _minimumEventWidth = 2.0;

/// A viewport-sized timeline: panning changes a date, not a giant scroll offset.
class AgendaTimeline extends StatefulWidget {
  const AgendaTimeline({
    super.key,
    required this.controller,
    required this.entries,
    required this.now,
    this.filter = (kind: null, term: null),
    this.active = true,
    this.visible = true,
  });

  final AgendaController controller;
  final List<AgendaEntry> entries;
  final DateTime now;

  /// Changing filters resets the vertical range, without changing the date.
  final ({AgendaKind? kind, String? term}) filter;

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
  Drag? _verticalDrag;
  ScrollHoldController? _verticalHold;
  double? _retainedLaneExtent;
  double? _laneViewportHeight;
  double _lastHorizontal = 0;
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
  Duration? _cachedDeadlineCardSpan;
  double? _cachedZoom;
  List<AgendaTimelinePlacement> _cachedPlacements = const [];
  final Map<String, DateTime> _nextStartById = {};
  final Map<String, AgendaTimelineEntry> _cards = {};
  _TimelineText? _gridText;
  late double _fontScale;
  late double _headerHeight;
  late double _laneHeight;

  List<AgendaTimelinePlacement> _layout(
    Duration minimumEventSpan,
    Duration deadlineCardSpan,
  ) {
    if (!identical(_cachedEntries, widget.entries) ||
        _cachedMinimumEventSpan != minimumEventSpan ||
        _cachedDeadlineCardSpan != deadlineCardSpan ||
        _cachedZoom != _zoom) {
      _cachedEntries = widget.entries;
      _cachedMinimumEventSpan = minimumEventSpan;
      _cachedDeadlineCardSpan = deadlineCardSpan;
      _cachedZoom = _zoom;
      _cards.clear();
      _cachedPlacements = layoutAgendaTimeline(
        widget.entries,
        minimumEventSpan: minimumEventSpan,
        deadlineCardSpan: deadlineCardSpan,
        zoom: _zoom,
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
    _horizontalFling = AnimationController.unbounded(vsync: this)
      ..addListener(_tickHorizontal);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = Theme.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    _fontScale = math.max(1.0, textScaler.scale(14) / 14);
    final baseStyle =
        theme.textTheme.labelMedium ?? const TextStyle(fontSize: 12);
    final headerStyle = baseStyle.copyWith(
      fontSize: (baseStyle.fontSize ?? 12) * 5 / 6,
      height: 1,
      color: theme.colorScheme.onSurfaceVariant,
    );
    _gridText?.dispose();
    _gridText = _TimelineText(headerStyle, textScaler);

    double textHeight(double fontSize, double height) {
      final measure = TextPainter(
        text: TextSpan(
          text: '${context.l10n.agendaTitle} Ag',
          style: TextStyle(fontSize: fontSize, height: height),
        ),
        textScaler: textScaler,
        textDirection: TextDirection.ltr,
      )..layout();
      final result = measure.height;
      measure.dispose();
      return result;
    }

    _headerHeight = math.max(
      24.0 * _fontScale,
      textHeight(headerStyle.fontSize!, 1) * 2 + 4,
    );
    _laneHeight =
        math.max(
          56.0 * _fontScale,
          textHeight(14, 1.2) +
              math.max(textHeight(12, 1.2) * 2, 13 * _fontScale) +
              10,
        ) +
        12;
  }

  void _stopMotion({bool holdVertical = false}) {
    _horizontalFling.stop();
    final drag = _verticalDrag;
    _verticalDrag = null;
    drag?.cancel();
    if (_lanes.hasClients && _verticalHold == null) {
      _verticalHold = _lanes.position.hold(() => _verticalHold = null);
    }
    if (!holdVertical) _releaseVerticalHold();
  }

  void _releaseVerticalHold() {
    final hold = _verticalHold;
    _verticalHold = null;
    hold?.cancel();
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

  bool get _canFling =>
      widget.active &&
      widget.visible &&
      !_gestureHadMultiplePointers &&
      !_gestureScaled &&
      !_gestureTrackpad;

  void _startFling(Offset velocity, double pixelsPerHour) {
    if (!_canFling) return;
    _flingPixelsPerHour = pixelsPerHour;
    // Vertical flings and edge springs belong to the ScrollPosition.
    if (velocity.dx.abs() >= 50) {
      _lastHorizontal = 0;
      _horizontalFling.value = 0;
      _horizontalFling.animateWith(FrictionSimulation(0.135, 0, velocity.dx));
    }
  }

  @override
  void didUpdateWidget(covariant AgendaTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter != widget.filter) {
      _retainedLaneExtent = null;
    }
    if (oldWidget.visible != widget.visible) {
      _stopMotion(holdVertical: true);
      _gestureAnchor = null;
      _downPointers.clear();
      _panZoomPointers.clear();
    }
    if (oldWidget.active != widget.active) {
      _stopMotion(holdVertical: true);
      _gestureAnchor = null;
      _downPointers.clear();
      _panZoomPointers.clear();
      if (widget.active) {
        _center = calendarDate(widget.now).add(const Duration(hours: 12));
      }
    }
    if (widget.active &&
        widget.visible &&
        (oldWidget.active != widget.active ||
            oldWidget.visible != widget.visible)) {
      _releaseVerticalHold();
    }
  }

  @override
  void deactivate() {
    _stopMotion(holdVertical: true);
    _gestureAnchor = null;
    _downPointers.clear();
    _panZoomPointers.clear();
    super.deactivate();
  }

  @override
  void dispose() {
    _stopMotion(holdVertical: true);
    _horizontalFling.dispose();
    _releaseVerticalHold();
    _lanes.dispose();
    _gridText?.dispose();
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
    _releaseVerticalHold();
    _lanes.position.pointerScroll(delta);
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
        final laneHeight = _laneHeight;
        final deadlineCardWidth = 144.0 * _fontScale;
        final deadlineCardSpan = Duration(
          microseconds: (deadlineCardWidth / baseline * _microsecondsPerHour)
              .ceil(),
        );
        final minimumEventSpan = Duration(
          // The visual floor is fixed and does not scale with accessibility text.
          microseconds: (_minimumEventWidth / baseline * _microsecondsPerHour)
              .ceil(),
        );
        final placements = _layout(minimumEventSpan, deadlineCardSpan);
        final left = _timeAt(0, width, pixelsPerHour);
        final right = _timeAt(width, width, pixelsPerHour);
        final painter = _TimelineGridPainter(
          center: _center,
          now: widget.now,
          pixelsPerHour: pixelsPerHour,
          cellWidth: cellWidth,
          scheme: theme.colorScheme,
          text: _gridText!,
          header: true,
          l10n: l10n,
        );

        return Listener(
          onPointerDown: (_) => _stopMotion(holdVertical: true),
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
                    _stopMotion(holdVertical: true);
                    if (_downPointers.isEmpty) {
                      _gestureHadMultiplePointers = false;
                    }
                    _downPointers.add(event.pointer);
                    if (_downPointers.length > 1) {
                      _gestureHadMultiplePointers = true;
                    }
                  },
                  onPointerUp: (event) {
                    _downPointers.remove(event.pointer);
                    if (_downPointers.isEmpty) _releaseVerticalHold();
                  },
                  onPointerCancel: (event) {
                    _downPointers.remove(event.pointer);
                    _panZoomPointers.remove(event.pointer);
                    _gestureHadMultiplePointers = true;
                    _stopMotion();
                  },
                  onPointerPanZoomStart: (event) {
                    _stopMotion(holdVertical: true);
                    if (_panZoomPointers.isEmpty && _downPointers.isEmpty) {
                      _gestureHadMultiplePointers = false;
                    }
                    _panZoomPointers.add(event.pointer);
                  },
                  onPointerPanZoomEnd: (event) {
                    _panZoomPointers.remove(event.pointer);
                    if (_panZoomPointers.isEmpty) _releaseVerticalHold();
                  },
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
                      _stopMotion(holdVertical: true);
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
                      if (!_gestureHadMultiplePointers && _lanes.hasClients) {
                        _verticalDrag = _lanes.position.drag(
                          DragStartDetails(
                            globalPosition: details.focalPoint,
                            localPosition: details.localFocalPoint,
                          ),
                          () => _verticalDrag = null,
                        );
                      }
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
                      final center = anchor.subtract(
                        Duration(
                          microseconds:
                              ((details.localFocalPoint.dx - width / 2) /
                                      (baseline * next) *
                                      _microsecondsPerHour)
                                  .round(),
                        ),
                      );
                      if (next != _zoom || center != _center) {
                        setState(() {
                          _zoom = next;
                          _center = center;
                        });
                      }
                      if ((_gestureTrackpad || details.pointerCount <= 1) &&
                          !_gestureHadMultiplePointers &&
                          !_gestureScaled) {
                        _verticalDrag?.update(
                          DragUpdateDetails(
                            delta: Offset(0, details.focalPointDelta.dy),
                            primaryDelta: details.focalPointDelta.dy,
                            globalPosition: details.focalPoint,
                            localPosition: details.localFocalPoint,
                          ),
                        );
                      } else {
                        final drag = _verticalDrag;
                        _verticalDrag = null;
                        drag?.cancel();
                      }
                    },
                    onScaleEnd: (details) {
                      final hadAnchor = _gestureAnchor != null;
                      _gestureAnchor = null;
                      final drag = _verticalDrag;
                      _verticalDrag = null;
                      drag?.end(
                        DragEndDetails(
                          velocity: Velocity(
                            pixelsPerSecond: Offset(
                              0,
                              _canFling
                                  ? details.velocity.pixelsPerSecond.dy
                                  : 0,
                            ),
                          ),
                          primaryVelocity: _canFling
                              ? details.velocity.pixelsPerSecond.dy
                              : 0,
                        ),
                      );
                      _releaseVerticalHold();
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
                            height: _headerHeight,
                            width: width,
                            child: CustomPaint(painter: painter),
                          ),
                          Expanded(
                            child: ListenableBuilder(
                              listenable: _lanes,
                              builder: (context, _) => LayoutBuilder(
                                builder: (context, laneConstraints) {
                                  final height = laneConstraints.maxHeight;
                                  if (_laneViewportHeight != height) {
                                    _laneViewportHeight = height;
                                    _retainedLaneExtent = null;
                                  }
                                  final previousOffset = _lanes.hasClients
                                      ? _lanes.offset
                                      : 0.0;
                                  final placementsInTime = placements
                                      .where(
                                        (placement) =>
                                            placement.paintEnd.isAfter(left) &&
                                            placement.paintStart.isBefore(
                                              right,
                                            ),
                                      )
                                      .toList(growable: false);
                                  final displayedLaneCount = placementsInTime
                                      .fold<int>(
                                        0,
                                        (count, placement) =>
                                            math.max(count, placement.lane + 1),
                                      );
                                  final contentExtent = math.max(
                                    0.0,
                                    (displayedLaneCount + 1) * laneHeight +
                                        12 -
                                        height,
                                  );
                                  // Keep an old lower position when the date changes.
                                  // Scrolling up releases it, leaving one spare lane.
                                  _retainedLaneExtent = math.max(
                                    contentExtent,
                                    math.min(
                                      _retainedLaneExtent ?? contentExtent,
                                      math.max(0.0, previousOffset),
                                    ),
                                  );
                                  final contentHeight =
                                      height + _retainedLaneExtent!;
                                  // Filtering and resizing may clamp the offset
                                  // in this frame. Cull at that new position.
                                  final offset = previousOffset
                                      .clamp(0.0, _retainedLaneExtent!)
                                      .toDouble();
                                  final visible = placementsInTime
                                      .where(
                                        (placement) =>
                                            (placement.lane + 1) * laneHeight >=
                                                offset &&
                                            placement.lane * laneHeight + 12 <=
                                                offset + height,
                                      )
                                      .toList(growable: false);
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
                                          text: _gridText!,
                                          header: false,
                                          l10n: l10n,
                                        ),
                                      ),
                                      ScrollConfiguration(
                                        behavior: ScrollConfiguration.of(
                                          context,
                                        ).copyWith(scrollbars: false),
                                        // Preserve overscroll when horizontal
                                        // panning changes the content height.
                                        child: CustomScrollView(
                                          key: const ValueKey(
                                            'agenda-timeline-lanes',
                                          ),
                                          controller: _lanes,
                                          physics: const BouncingScrollPhysics(
                                            parent:
                                                NeverScrollableScrollPhysics(),
                                          ),
                                          slivers: [
                                            SliverToBoxAdapter(
                                              child: SizedBox(
                                                height: contentHeight,
                                                width: width,
                                                child: Stack(
                                                  clipBehavior: Clip.hardEdge,
                                                  children: [
                                                    for (final placement
                                                        in visible)
                                                      _buildEntry(
                                                        context,
                                                        placement,
                                                        width,
                                                        pixelsPerHour,
                                                        laneHeight,
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
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
  ) {
    final entry = placement.entry;
    double x(DateTime time) =>
        width / 2 +
        time.difference(_center).inMicroseconds /
            _microsecondsPerHour *
            pixelsPerHour;
    final actualRight = x(placement.paintEnd);
    final actualLeft = x(placement.paintStart);
    // Crop long ordinary events before creating widgets; no huge canvas/boxes.
    final left = entry.isDeadline ? actualLeft : math.max(0.0, actualLeft);
    final right = entry.isDeadline ? actualRight : math.min(width, actualRight);
    double spanWidth(DateTime start, DateTime end) =>
        end.difference(start).inMicroseconds /
        _microsecondsPerHour *
        pixelsPerHour;
    final barWidth = entry.isDeadline
        ? spanWidth(placement.paintStart, placement.paintEnd)
        : math.max(0.0, right - left);
    final cardWidth = entry.isDeadline
        ? spanWidth(placement.start, placement.layoutEnd)
        : barWidth;
    final nextStart = _nextStartById[entry.id];
    final availableWidth = nextStart == null
        ? double.infinity
        : math.max(
            0.0,
            entry.isDeadline
                ? spanWidth(placement.paintStart, nextStart)
                : x(nextStart) - left,
          );
    final tapWidth = math.min(math.max(24.0, barWidth), availableWidth);
    var card = _cards[entry.id];
    if (card == null ||
        card.entry != entry ||
        card.now != widget.now ||
        card.barWidth != barWidth ||
        card.cardWidth != cardWidth) {
      card = AgendaTimelineEntry(
        entry: entry,
        now: widget.now,
        barWidth: barWidth,
        cardWidth: cardWidth,
        onTap: () => showAgendaEntry(context, widget.controller, entry),
      );
      _cards[entry.id] = card;
    }
    return Positioned(
      key: ValueKey(entry.id),
      left: left,
      top: placement.lane * laneHeight + 12,
      width: tapWidth,
      height: laneHeight - 12,
      child: RepaintBoundary(child: card),
    );
  }
}
