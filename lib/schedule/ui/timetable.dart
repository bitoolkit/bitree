import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../agenda/calendar.dart';
import '../../app/controller.dart';
import '../../core/time.dart';
import '../height_mode.dart';
import '../layout.dart';
import '../section_times.dart';
import '../time_position.dart';
import 'timetable_grid.dart';
import 'timetable_header.dart';

class Timetable extends StatefulWidget {
  const Timetable({
    super.key,
    required this.controller,
    required this.week,
    required this.initialScrollOffset,
    required this.onScroll,
    required this.active,
  });

  final AppController controller;
  final int week;
  final double initialScrollOffset;
  final ValueChanged<double> onScroll;
  final bool active;

  @override
  State<Timetable> createState() => _TimetableState();
}

class _TimetableState extends State<Timetable> with WidgetsBindingObserver {
  late final ScrollController _vertical;
  final _currentTime = ValueNotifier(campusNow());
  Timer? _timer;
  double _rowHeight = 0;
  bool _followingTime = true;
  bool _scrollingToTime = false;
  late double _normalScrollOffset;
  bool _restoringScroll = false;
  int _scrollRestoreGeneration = 0;

  bool get _fitToScreen =>
      widget.controller.settings.timetableHeightMode.value ==
      TimetableHeightMode.fit;

  void _heightModeChanged() {
    _restoringScroll = true;
    setState(() {});
    _restoreScrollAfterLayout();
  }

  void _restoreScrollAfterLayout() {
    final generation = ++_scrollRestoreGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _scrollRestoreGeneration) return;
      if (_vertical.hasClients && _vertical.position.hasContentDimensions) {
        final position = _vertical.position;
        final target = _fitToScreen ? 0.0 : _normalScrollOffset;
        _vertical.jumpTo(
          target.clamp(position.minScrollExtent, position.maxScrollExtent)
              .toDouble(),
        );
        if (!_fitToScreen) {
          _normalScrollOffset = position.pixels;
          widget.onScroll(_normalScrollOffset);
        }
      }
      _restoringScroll = false;
    });
  }

  bool get _active {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    return widget.active &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed);
  }

  @override
  void initState() {
    super.initState();
    _normalScrollOffset = widget.initialScrollOffset;
    widget.controller.settings.timetableHeightMode.addListener(_heightModeChanged);
    _vertical = ScrollController(
      initialScrollOffset: _fitToScreen ? 0 : widget.initialScrollOffset,
      keepScrollOffset: false,
    )..addListener(_rememberScroll);
    WidgetsBinding.instance.addObserver(this);
    if (_active) _startFollowingTime();
  }

  @override
  void didUpdateWidget(covariant Timetable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller.settings.timetableHeightMode !=
        widget.controller.settings.timetableHeightMode) {
      oldWidget.controller.settings.timetableHeightMode
          .removeListener(_heightModeChanged);
      widget.controller.settings.timetableHeightMode
          .addListener(_heightModeChanged);
      _restoringScroll = true;
      _restoreScrollAfterLayout();
    }
    if (!_active) {
      _timer?.cancel();
    } else if (!oldWidget.active || oldWidget.week != widget.week) {
      _startFollowingTime();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_active) {
      _startFollowingTime();
    } else {
      _timer?.cancel();
    }
  }

  void _startFollowingTime() {
    _followingTime = true;
    _updateTime();
    _scheduleTick();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_revealCurrentTime(force: true));
    });
  }

  void _updateTime() {
    final previous = _currentTime.value;
    final now = campusNow();
    _currentTime.value = now;
    if (calendarDate(previous) != calendarDate(now)) setState(() {});
  }

  void _scheduleTick() {
    _timer?.cancel();
    final now = campusNow();
    final delay =
        const Duration(minutes: 1) -
        Duration(
          seconds: now.second,
          milliseconds: now.millisecond,
          microseconds: now.microsecond,
        );
    _timer = Timer(delay, () {
      _updateTime();
      unawaited(_revealCurrentTime());
      _scheduleTick();
    });
  }

  Future<void> _revealCurrentTime({bool force = false}) async {
    final schedule = widget.controller.timetable.schedule;
    final now = _currentTime.value;
    if (_fitToScreen ||
        _restoringScroll ||
        !_active ||
        !_followingTime ||
        !_vertical.hasClients ||
        _rowHeight <= 0 ||
        schedule == null ||
        schedule.weekAt(now) != widget.week ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }

    final section = sectionOffsetAt(now);
    if (section == null ||
        !schedule
            .coursesAt(widget.week, weekday: now.weekday)
            .any((course) => course.endSection! > section)) {
      return;
    }

    final position = _vertical.position;
    if (!position.hasContentDimensions ||
        position.viewportDimension <= 0 ||
        position.isScrollingNotifier.value) {
      return;
    }

    final line = section * _rowHeight;
    final viewport = position.viewportDimension;
    // Follow only when the line leaves this band, leaving more room ahead.
    if (!force &&
        line >= position.pixels + viewport * 0.2 &&
        line <= position.pixels + viewport * 0.65) {
      return;
    }

    final target = (line - viewport / 3)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((target - position.pixels).abs() < 1) return;

    _scrollingToTime = true;
    try {
      if (force || MediaQuery.disableAnimationsOf(context)) {
        _vertical.jumpTo(target);
      } else {
        await _vertical.animateTo(
          target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
    } finally {
      _scrollingToTime = false;
    }
  }

  bool _onScroll(ScrollNotification notification) {
    if (_restoringScroll) return false;
    if (notification.depth == 0 &&
        ((notification is ScrollStartNotification &&
                (!_scrollingToTime || notification.dragDetails != null)) ||
            (notification is UserScrollNotification &&
                notification.direction != ScrollDirection.idle))) {
      _followingTime = false;
    }
    return false;
  }

  void _rememberScroll() {
    if (_fitToScreen || _restoringScroll) return;
    _normalScrollOffset = _vertical.offset;
    widget.onScroll(_normalScrollOffset);
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.settings.timetableHeightMode
        .removeListener(_heightModeChanged);
    _currentTime.dispose();
    _vertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final schedule = controller.timetable.schedule!;
    final monday = schedule.mondayAt(widget.week);
    final today = calendarDate(_currentTime.value);
    final currentWeek = schedule.weekAt(today) == widget.week;
    final todayColumn = currentWeek ? today.weekday - 1 : null;
    final theme = Theme.of(context);
    final todayBackground = theme.brightness == Brightness.dark
        ? theme.colorScheme.surfaceContainer
        : theme.colorScheme.primary.withValues(alpha: 0.08);
    final scale = MediaQuery.textScalerOf(context).scale(1);

    final days = [
      for (var day = 0; day < 7; day++)
        calendarItemsOn(
          monday.add(Duration(days: day)),
          schedule,
          controller.agenda.entries,
        ),
    ];
    final pinned = [
      for (var day = 0; day < 7; day++)
        days[day]
            .where(
              (item) =>
                  item.pinned ||
                  outsideTimetable(item, monday.add(Duration(days: day))),
            )
            .toList(),
    ];
    final layouts = [
      for (var day = 0; day < 7; day++)
        groupCalendarItems(
          days[day].where((item) => !pinned[day].contains(item)).toList(),
          monday.add(Duration(days: day)),
        ),
    ];

    final gutterWidth = 30.0 * scale;
    return Column(
      children: [
        TimetableHeader(
          controller: controller,
          monday: monday,
          now: _currentTime.value,
          gutterWidth: gutterWidth,
          todayBackground: todayBackground,
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final preferredRowHeight = 48.0 * scale;
              final availableRowHeight =
                  constraints.maxHeight / sectionTimes.length;
              // A tiny shortfall should compress the grid instead of creating
              // a distracting few-pixel vertical scroll.
              final rowHeight = _fitToScreen ||
                      availableRowHeight >= preferredRowHeight * 0.9
                  ? availableRowHeight
                  : preferredRowHeight;
              _rowHeight = rowHeight;

              return NotificationListener<ScrollMetricsNotification>(
                onNotification: (_) {
                  unawaited(_revealCurrentTime());
                  return false;
                },
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onScroll,
                  child: SingleChildScrollView(
                    controller: _vertical,
                    physics: _fitToScreen
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    child: RepaintBoundary(
                      child: TimetableGrid(
                        controller: controller,
                        monday: monday,
                        layouts: layouts,
                        gutterWidth: gutterWidth,
                        rowHeight: rowHeight,
                        todayColumn: todayColumn,
                        todayBackground: todayBackground,
                        currentTime: _currentTime,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
