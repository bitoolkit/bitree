import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../agenda/ui/calendar_block.dart';
import '../../app/controller.dart';
import '../../app/ui/add_menu.dart';
import '../../l10n/l10n.dart';
import '../../ui/design.dart';
import '../../ui/theme.dart';
import '../layout.dart';
import '../model.dart';
import '../selection.dart';
import 'current_time_indicator.dart';

class TimetableGrid extends StatefulWidget {
  const TimetableGrid({
    super.key,
    required this.controller,
    required this.monday,
    required this.layouts,
    required this.gutterWidth,
    required this.rowHeight,
    required this.todayColumn,
    required this.todayBackground,
    required this.currentTime,
  });

  final AppController controller;
  final DateTime monday;
  final List<List<CalendarBlock>> layouts;
  final double gutterWidth;
  final double rowHeight;
  final int? todayColumn;
  final Color todayBackground;
  final ValueListenable<DateTime> currentTime;

  @override
  State<TimetableGrid> createState() => _TimetableGridState();
}

class _TimetableGridState extends State<TimetableGrid> {
  final _grid = GlobalKey();
  final _addMenu = MenuController();
  bool _closedMenuOnPointerDown = false;
  ({int day, int anchor, int end})? _selection;
  Offset? _dragPosition;
  EdgeDraggingAutoScroller? _autoScroller;

  @override
  void dispose() {
    _dragPosition = null;
    _autoScroller?.stopAutoScroll();
    _autoScroller = null;
    super.dispose();
  }

  ({int day, int section}) _cellAt(Offset position) {
    final box = _grid.currentContext!.findRenderObject()! as RenderBox;
    final local = box.globalToLocal(position);

    return (
      day: (local.dx / (box.size.width / 7)).floor().clamp(0, 6),
      section:
          (local.dy / widget.rowHeight).floor().clamp(
            0,
            sectionTimes.length - 1,
          ) +
          1,
    );
  }

  bool _beginSelection(Offset position) {
    if (_closedMenuOnPointerDown || widget.controller.timetable.busy) {
      return false;
    }
    final cell = _cellAt(position);

    setState(() {
      _selection = (day: cell.day, anchor: cell.section, end: cell.section);
    });
    return true;
  }

  void _extendSelection(Offset position) {
    final selection = _selection;
    if (selection == null) return;

    final target = _cellAt(position).section;
    if (target != selection.end) {
      setState(() {
        _selection = (
          day: selection.day,
          anchor: selection.anchor,
          end: target,
        );
      });
    }
  }

  void _startDrag(Offset position) {
    if (!_beginSelection(position)) return;

    _autoScroller = EdgeDraggingAutoScroller(
      Scrollable.of(context),
      velocityScalar: 20,
      onScrollViewScrolled: () {
        final position = _dragPosition;
        if (position != null) _dragSelection(position);
      },
    );
    HapticFeedback.selectionClick();
    _dragSelection(position);
  }

  void _dragSelection(Offset position) {
    final scroller = _autoScroller;
    if (scroller == null) return;
    _dragPosition = position;
    _extendSelection(position);

    // Start scrolling within 36 pixels of either viewport edge.
    final targetHeight = math.min(
      72.0,
      scroller.scrollable.position.viewportDimension,
    );
    scroller.startAutoScrollIfNecessary(
      Rect.fromCenter(center: position, width: 1, height: targetHeight),
    );
  }

  void _stopDrag() {
    final scroller = _autoScroller;
    _dragPosition = null;
    _autoScroller = null;
    scroller?.stopAutoScroll();
    if (scroller != null) {
      final position = scroller.scrollable.position;
      if (position.isScrollingNotifier.value) {
        // stopAutoScroll stops the loop, but its current animation still runs.
        position.jumpTo(position.pixels);
      }
    }
  }

  void _cancelDrag() {
    if (_autoScroller != null) _cancelSelection();
  }

  void _finishDrag(Offset position) {
    if (_autoScroller == null) return;
    _extendSelection(position);
    _finishSelection(position);
  }

  void _cancelSelection() {
    _stopDrag();
    if (mounted) setState(() => _selection = null);
  }

  void _finishSelection(Offset position) {
    _stopDrag();
    if (_closedMenuOnPointerDown || _selection == null) return;

    // Rebuild the menu with the selected date and sections before opening it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selection = _selection;
      if (!mounted || selection == null) return;
      final box = _grid.currentContext!.findRenderObject()! as RenderBox;
      // The range stays in its initial day even if a long drag drifts sideways.
      _addMenu.open(
        position: Offset(
          (selection.day + 0.5) * box.size.width / 7,
          box.globalToLocal(position).dy,
        ),
      );
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _menuClosed() {
    // MenuItemButton runs its action after the frame, using this selection.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_addMenu.isOpen) _cancelSelection();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rowHeight = widget.rowHeight;
    final gridHeight = rowHeight * sectionTimes.length;
    final selection = _selection;
    final menuSelection = selection == null
        ? null
        : TimetableSelection(
            date: widget.monday.add(Duration(days: selection.day)),
            startSection: math.min(selection.anchor, selection.end),
            endSection: math.max(selection.anchor, selection.end),
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidth = (constraints.maxWidth - widget.gutterWidth) / 7;
        final blocks = [
          for (var day = 0; day < 7; day++)
            for (final block in widget.layouts[day])
              (
                day: day,
                block: block,
                course: block.items.length == 1
                    ? block.items.single.course
                    : null,
                bounds: Rect.fromLTWH(
                  day * columnWidth + 2,
                  block.start * rowHeight + 2,
                  columnWidth - 4,
                  (block.end - block.start) * rowHeight - 4,
                ),
              ),
        ];
        final masks = [
          for (final layout in blocks)
            (
              shape: AppCorners.compact.toRRect(layout.bounds),
              color: switch (layout.course) {
                final course? => courseColors(context, course).accent,
                null => scheme.primary,
              },
            ),
        ];

        return SizedBox(
          height: gridHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: widget.gutterWidth,
                child: Column(
                  children: [
                    for (
                      var section = 1;
                      section <= sectionTimes.length;
                      section++
                    )
                      SizedBox(
                        height: rowHeight,
                        child: _PeriodLabel(section: section),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: AddMenu(
                  controller: widget.controller,
                  menuController: _addMenu,
                  selection: menuSelection,
                  onClose: _menuClosed,
                  child: GestureDetector(
                    supportedDevices: const {PointerDeviceKind.mouse},
                    dragStartBehavior: DragStartBehavior.down,
                    onPanStart: (details) => _startDrag(details.globalPosition),
                    onPanUpdate: (details) =>
                        _dragSelection(details.globalPosition),
                    onPanEnd: (details) => _finishDrag(details.globalPosition),
                    onPanCancel: _cancelDrag,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) {
                        if (_beginSelection(details.globalPosition)) {
                          _finishSelection(details.globalPosition);
                        }
                      },
                      onLongPressStart: (details) =>
                          _startDrag(details.globalPosition),
                      onLongPressMoveUpdate: (details) =>
                          _dragSelection(details.globalPosition),
                      onLongPressEnd: (details) =>
                          _finishDrag(details.globalPosition),
                      child: Listener(
                        onPointerDown: (_) {
                          _closedMenuOnPointerDown = _addMenu.isOpen;
                          if (_closedMenuOnPointerDown) _addMenu.close();
                        },
                        onPointerCancel: (_) => _cancelDrag(),
                        child: Stack(
                          key: _grid,
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _TimetableBackground(
                                  rowHeight: rowHeight,
                                  surfaceColor: scheme.onSurface,
                                  todayColumn: widget.todayColumn,
                                  todayBackground: widget.todayBackground,
                                ),
                              ),
                            ),
                            for (final layout in blocks)
                              Positioned.fromRect(
                                key: ValueKey((layout.day, layout.block.start)),
                                rect: layout.bounds,
                                child: ValueListenableBuilder<DateTime>(
                                  valueListenable: widget.currentTime,
                                  builder: (context, now, _) {
                                    double? progress;
                                    final block = layout.block;
                                    if (layout.course case final course?) {
                                      final item = block.items.single;
                                      final elapsed = TimetableSelection(
                                        date: item.startsAt,
                                        startSection: course.startSection!,
                                        endSection: course.endSection!,
                                      ).progressAt(now);
                                      if (elapsed != null) {
                                        final section =
                                            block.start +
                                            elapsed * (block.end - block.start);
                                        final center =
                                            CurrentTimeIndicator.centerAt(
                                              section,
                                              rowHeight,
                                            );
                                        progress =
                                            (center - layout.bounds.top) /
                                            layout.bounds.height;
                                      }
                                    }
                                    return CalendarBlockTile(
                                      items: block.items,
                                      controller: widget.controller,
                                      isToday: layout.day == widget.todayColumn,
                                      courseProgress: progress,
                                    );
                                  },
                                ),
                              ),
                            Positioned.fill(
                              child: ValueListenableBuilder<DateTime>(
                                valueListenable: widget.currentTime,
                                builder: (context, now, _) =>
                                    CurrentTimeIndicator(
                                      now: now,
                                      monday: widget.monday,
                                      columnWidth: columnWidth,
                                      rowHeight: rowHeight,
                                      cards: masks,
                                    ),
                              ),
                            ),
                            if (_selection case final selection?)
                              Positioned(
                                left: selection.day * columnWidth + 2,
                                width: columnWidth - 4,
                                top:
                                    (math.min(selection.anchor, selection.end) -
                                            1) *
                                        rowHeight +
                                    2,
                                height:
                                    ((selection.end - selection.anchor).abs() +
                                            1) *
                                        rowHeight -
                                    4,
                                child: IgnorePointer(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: scheme.primary.withValues(
                                        alpha: 0.18,
                                      ),
                                      border: Border.all(
                                        color: scheme.primary,
                                        width: 1.5,
                                      ),
                                      borderRadius: AppCorners.compact,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
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
}

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
        rowHeight - 4,
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
        columnWidth - 4,
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$section',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 2),
            Text(
              '${time.$1}\n${time.$2}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                height: 1.2,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
