import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../app/controller.dart';
import '../../core/time.dart';
import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../model.dart';
import '../timeline_layout.dart';
import 'adjusted_deadline_painter.dart';
import 'agenda_detail.dart';
import 'event_timeline_entry.dart';
import 'timeline_caption.dart';
import 'timeline_entry.dart';

part 'agenda_timeline_painters.dart';

const _microsecondsPerHour = Duration.microsecondsPerSecond * 3600;
const _minimumEventWidth = 2.0;

/// Keep genuine user overscroll, but retire an in-range position immediately
/// when filtering or resizing makes its old content range invalid.
class _TimelineScrollPhysics extends BouncingScrollPhysics {
  const _TimelineScrollPhysics({super.parent});

  @override
  _TimelineScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _TimelineScrollPhysics(parent: buildParent(ancestor));

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    if (newPosition.maxScrollExtent < oldPosition.maxScrollExtent &&
        !oldPosition.outOfRange) {
      return newPosition.pixels
          .clamp(newPosition.minScrollExtent, newPosition.maxScrollExtent)
          .toDouble();
    }
    return super.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: newPosition,
      isScrolling: isScrolling,
      velocity: velocity,
    );
  }
}

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

  final AppController controller;
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
  double? _lastContentExtent;
  double? _lastViewportHeight;
  double _lastHorizontal = 0;
  double _flingPixelsPerHour = 1;
  bool _gestureHadMultiplePointers = false;
  bool _gestureScaled = false;
  bool _gestureTrackpad = false;
  final Set<int> _downPointers = <int>{};
  final Set<int> _panZoomPointers = <int>{};
  late final ValueNotifier<DateTime> _visibleCenter;
  DateTime get _center => _visibleCenter.value;
  double _zoom = 1;
  double _gestureZoom = 1;
  int _gesturePointers = 0;
  DateTime? _gestureAnchor;
  List<AgendaEntry>? _cachedEntries;
  DeadlineCutoffWindow? _cachedCutoff;
  int? _cachedLayoutDays;
  bool? _cachedEventInfoBar;
  Duration? _cachedMinimumEventSpan;
  Duration? _cachedDeadlineCardSpan;
  double? _cachedZoom;
  AgendaTimelineLayout? _laneLayout;
  List<AgendaTimelinePlacement> _cachedPlacements = const [];
  final Map<String, AgendaTimelineEntry> _plainCards = {};

  _TimelineText? _gridText;
  late double _fontScale;
  late double _headerHeight;
  late double _laneHeight;

  List<AgendaTimelinePlacement> _layout(
    Duration minimumEventSpan,
    Duration deadlineCardSpan,
  ) {
    final cutoff = widget.controller.settings.deadlineCutoff.value;
    final layoutDays = widget.controller.settings.agendaLayoutDays.value;
    final eventInfoBar = widget.controller.settings.agendaEventInfoBar.value;
    if (!identical(_cachedEntries, widget.entries) ||
        _cachedCutoff != cutoff ||
        _cachedLayoutDays != layoutDays ||
        _cachedEventInfoBar != eventInfoBar ||
        _cachedMinimumEventSpan != minimumEventSpan ||
        _cachedDeadlineCardSpan != deadlineCardSpan) {
      _cachedEntries = widget.entries;
      _cachedCutoff = cutoff;
      _cachedLayoutDays = layoutDays;
      _cachedEventInfoBar = eventInfoBar;
      _cachedMinimumEventSpan = minimumEventSpan;
      _cachedDeadlineCardSpan = deadlineCardSpan;
      _cachedZoom = null;
      _plainCards.clear();
      _laneLayout = AgendaTimelineLayout(
        widget.entries.map((entry) => entry.withDeadlineCutoff(cutoff)),
        minimumEventSpan: minimumEventSpan,
        deadlineCardSpan: deadlineCardSpan,
        layoutDays: layoutDays,
        reserveEventInformation: eventInfoBar,
      );
    }
    if (_cachedZoom != _zoom) {
      _cachedZoom = _zoom;
      _cachedPlacements = _laneLayout!.atZoom(_zoom);
    }
    return _cachedPlacements;
  }

  @override
  void initState() {
    super.initState();
    _visibleCenter = ValueNotifier(
      calendarDate(widget.now).add(const Duration(hours: 12)),
    );
    widget.controller.settings.deadlineCutoff.addListener(_settingsChanged);
    widget.controller.settings.agendaLayoutDays.addListener(_settingsChanged);
    widget.controller.settings.agendaEventInfoBar.addListener(_settingsChanged);
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
    _visibleCenter.value = _center.subtract(
      Duration(
        microseconds: (delta / _flingPixelsPerHour * _microsecondsPerHour)
            .round(),
      ),
    );
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
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.settings.deadlineCutoff.removeListener(
        _settingsChanged,
      );
      oldWidget.controller.settings.agendaLayoutDays.removeListener(
        _settingsChanged,
      );
      oldWidget.controller.settings.agendaEventInfoBar.removeListener(
        _settingsChanged,
      );
      widget.controller.settings.deadlineCutoff.addListener(_settingsChanged);
      widget.controller.settings.agendaLayoutDays.addListener(_settingsChanged);
      widget.controller.settings.agendaEventInfoBar.addListener(
        _settingsChanged,
      );
      _cachedEntries = null;
    }
    if (oldWidget.filter != widget.filter) {
      _cachedEntries = null;
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
        _visibleCenter.value = calendarDate(widget.now)
            .add(const Duration(hours: 12));
      }
    }
    if (widget.active &&
        widget.visible &&
        (oldWidget.active != widget.active ||
            oldWidget.visible != widget.visible)) {
      _releaseVerticalHold();
    }
  }

  void _settingsChanged() {
    if (!mounted) return;
    _stopMotion();
    setState(() => _cachedEntries = null);
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
    widget.controller.settings.deadlineCutoff.removeListener(_settingsChanged);
    widget.controller.settings.agendaLayoutDays.removeListener(
      _settingsChanged,
    );
    widget.controller.settings.agendaEventInfoBar.removeListener(
      _settingsChanged,
    );
    _horizontalFling.dispose();
    _releaseVerticalHold();
    _lanes.dispose();
    _visibleCenter.dispose();
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
    final next = zoom.clamp(1.0, 24.0).toDouble();
    if (next == _zoom) return;
    final anchor = _timeAt(x, width, baseline * _zoom);
    setState(() => _zoom = next);
    _visibleCenter.value = anchor.subtract(
      Duration(
        microseconds:
            ((x - width / 2) / (baseline * next) * _microsecondsPerHour)
                .round(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
        final deadlineCardWidth =
            cellWidth *
            (widget.controller.settings.agendaLayoutDays.value - .25);
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Listener(
              onPointerDown: (_) => _stopMotion(),
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) _stopMotion();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        _stopMotion();
                        _visibleCenter.value = calendarDate(widget.now)
                            .add(const Duration(hours: 12));
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
                  GestureBinding.instance.pointerSignalResolver.register(
                    event,
                    (resolved) {
                      final scroll = resolved as PointerScrollEvent;
                      final keys = HardwareKeyboard.instance.logicalKeysPressed;
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
                        _stopMotion();
                        _scrollLanes(delta);
                      } else {
                        _stopMotion();
                        _visibleCenter.value = _center.add(
                          Duration(
                            microseconds:
                                ((scroll.scrollDelta.dx +
                                            scroll.scrollDelta.dy) /
                                        pixelsPerHour *
                                        _microsecondsPerHour)
                                    .round(),
                          ),
                        );
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
                    if (next != _zoom) setState(() => _zoom = next);
                    _visibleCenter.value = center;
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
                            _canFling ? details.velocity.pixelsPerSecond.dy : 0,
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
                  child: ListenableBuilder(
                    listenable: _visibleCenter,
                    builder: (context, _) => _buildViewport(
                      context,
                      placements: placements,
                      width: width,
                      cellWidth: cellWidth,
                      pixelsPerHour: pixelsPerHour,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildViewport(
    BuildContext context, {
    required List<AgendaTimelinePlacement> placements,
    required double width,
    required double cellWidth,
    required double pixelsPerHour,
  }) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final laneHeight = _laneHeight;
    final left = _timeAt(0, width, pixelsPerHour);
    final right = _timeAt(width, width, pixelsPerHour);
    final placementsInTime = <AgendaTimelinePlacement>[];
    final laneCount = placements.fold<int>(
      0,
      (count, placement) => math.max(count, placement.lane + 1),
    );
    for (final placement in placements) {
      if (placement.paintEnd.isAfter(left) &&
          placement.paintStart.isBefore(right)) {
        placementsInTime.add(placement);
      }
    }
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
    return CustomPaint(
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
                  final contentHeight = math.max(
                    height,
                    laneCount * laneHeight + 12,
                  );
                  final extent = contentHeight - height;
                  final previousOffset = _lanes.hasClients
                      ? _lanes.offset
                      : 0.0;
                  // Bounce overscroll belongs to ScrollPosition. Only a changed
                  // range/viewport invalidates a previously valid culling offset.
                  final dimensionsChanged =
                      _lastContentExtent != extent ||
                      _lastViewportHeight != height;
                  _lastContentExtent = extent;
                  _lastViewportHeight = height;
                  final offset = dimensionsChanged
                      ? previousOffset.clamp(0.0, extent).toDouble()
                      : previousOffset;
                  final visible = placementsInTime.where(
                    (placement) =>
                        (placement.lane + 1) * laneHeight >= offset &&
                        placement.lane * laneHeight + 12 <= offset + height,
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
                          text: _gridText!,
                          header: false,
                          l10n: l10n,
                        ),
                      ),
                      ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context)
                            .copyWith(scrollbars: false),
                        // Preserve overscroll when horizontal
                        // panning changes the content height.
                        child: CustomScrollView(
                          key: const ValueKey('agenda-timeline-lanes'),
                          controller: _lanes,
                          physics: const _TimelineScrollPhysics(
                            parent: NeverScrollableScrollPhysics(),
                          ),
                          slivers: [
                            SliverToBoxAdapter(
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
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
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
    final cellWidth = (width / 5).clamp(80.0, 140.0).toDouble() * .6;
    final deadlineWidth =
        cellWidth *
        (entry.effectiveLayoutDays(
              widget.controller.settings.agendaLayoutDays.value,
            ) -
            .25);
    double x(DateTime time) =>
        width / 2 +
        time.difference(_center).inMicroseconds /
            _microsecondsPerHour *
            pixelsPerHour;
    if (!entry.isDeadline &&
        widget.controller.settings.agendaEventInfoBar.value) {
      final start = x(entry.startsAt);
      final end = x(entry.endsAt!);
      final informationLeft = start - deadlineWidth;
      final left = math.max(0.0, informationLeft);
      final right = math.min(width, end);
      return Positioned(
        key: ValueKey(('agenda-timeline-entry', entry.id)),
        left: left,
        top: placement.lane * laneHeight + 12,
        width: math.max(0.0, right - left),
        height: laneHeight - 12,
        child: EventTimelineEntry(
          entry: entry,
          now: widget.now,
          informationWidth: deadlineWidth,
          geometry: EventTimelineGeometry(
            informationLeft: informationLeft - left,
            startX: start - left,
            endX: end - left,
          ),
          onTap: () => showAgendaEntry(
            context,
            widget.controller.agenda,
            entry,
            automation: widget.controller.automation,
          ),
        ),
      );
    }
    if (entry.hasDeadlineCutoff) {
      final effective = x(entry.dueAt);
      final real = x(entry.realDueAt);
      final bodyLeft = effective - deadlineWidth;
      // The extension may be enormous in time coordinates. Only allocate its
      // intersection with this viewport, while retaining the body's true origin.
      final left = math.max(0.0, bodyLeft);
      final right = math.min(width, real);
      return Positioned(
        key: ValueKey(('agenda-timeline-entry', entry.id)),
        left: left,
        top: placement.lane * laneHeight + 12,
        width: math.max(0.0, right - left),
        height: laneHeight - 12,
        child: AgendaTimelineEntry(
          entry: entry,
          now: widget.now,
          barWidth: deadlineWidth,
          deadlineWidth: deadlineWidth,
          adjustedGeometry: AdjustedDeadlineGeometry(
            bodyLeft: bodyLeft - left,
            effectiveX: effective - left,
            realX: real - left,
          ),
          onTap: () => showAgendaEntry(
            context,
            widget.controller.agenda,
            entry,
            automation: widget.controller.automation,
          ),
        ),
      );
    }
    // A start-only deadline keeps the usual painted width but grows rightwards
    // from its opening time, so its right edge is derived instead of its left.
    final actualRight = entry.isDeadline && entry.startOnly
        ? x(placement.start) + deadlineWidth
        : x(placement.layoutEnd);
    final actualLeft = entry.isDeadline
        ? actualRight - deadlineWidth
        : x(placement.start);
    // Crop long ordinary events before creating widgets; no huge canvas/boxes.
    final left = entry.isDeadline ? actualLeft : math.max(0.0, actualLeft);
    final barWidth = entry.isDeadline
        ? deadlineWidth
        : math.max(0.0, math.min(width, actualRight) - left);
    final tapWidth = math.max(24.0, barWidth);
    var card = _plainCards[entry.id];
    if (card == null ||
        card.entry != entry ||
        card.now != widget.now ||
        card.barWidth != barWidth ||
        card.deadlineWidth != deadlineWidth) {
      card = AgendaTimelineEntry(
        entry: entry,
        now: widget.now,
        barWidth: barWidth,
        deadlineWidth: deadlineWidth,
        onTap: () => showAgendaEntry(
          context,
          widget.controller.agenda,
          entry,
          automation: widget.controller.automation,
        ),
      );
      _plainCards[entry.id] = card;
    }
    return Positioned(
      key: ValueKey(('agenda-timeline-entry', entry.id)),
      left: left,
      top: placement.lane * laneHeight + 12,
      width: tapWidth,
      height: laneHeight - 12,
      child: card,
    );
  }
}
