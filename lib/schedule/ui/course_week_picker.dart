import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../../ui/selection_controls.dart';

enum _WeekPreset {
  summer,
  regular;

  Set<int> weeksIn(List<int> weeks) => switch (this) {
    summer => weeks.where((week) => week < 0).toSet(),
    regular => weeks.where((week) => week > 0).toSet(),
  };

  String label(AppLocalizations l10n) => switch (this) {
    summer => l10n.weekSelectionSummer,
    regular => l10n.weekSelectionRegular,
  };
}

class CourseWeekPicker extends StatefulWidget {
  const CourseWeekPicker({
    super.key,
    required this.weeks,
    required this.selectedWeeks,
    required this.enabled,
    required this.onChanged,
    required this.onManageRange,
  });

  final List<int> weeks;
  final Set<int> selectedWeeks;
  final bool enabled;
  final ValueChanged<Set<int>> onChanged;
  final VoidCallback onManageRange;

  @override
  State<CourseWeekPicker> createState() => _CourseWeekPickerState();
}

class _CourseWeekPickerState extends State<CourseWeekPicker> {
  static const _spacing = 4.0;
  final _grid = GlobalKey();
  ({int start, int end, Set<int> before})? _range;
  Offset? _dragPosition;
  EdgeDraggingAutoScroller? _autoScroller;

  @override
  void didUpdateWidget(covariant CourseWeekPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _endRange();
  }

  @override
  void dispose() {
    _endRange();
    super.dispose();
  }

  ({int columns, double width, double height}) _dimensions(double width) {
    final fontSize = MediaQuery.textScalerOf(context).scale(14);
    final minimumWidth = math.max(48.0, fontSize * 2 + 16);
    final columns = ((width + _spacing) / (minimumWidth + _spacing))
        .floor()
        .clamp(1, 7);
    return (
      columns: columns,
      width: (width - (columns - 1) * _spacing) / columns,
      height: math.max(48.0, fontSize * 1.4 + 16),
    );
  }

  int _indexAt(Offset globalPosition) {
    final box = _grid.currentContext!.findRenderObject()! as RenderBox;
    final local = box.globalToLocal(globalPosition);
    final dimensions = _dimensions(box.size.width);
    final x = Directionality.of(context) == TextDirection.ltr
        ? local.dx
        : box.size.width - local.dx;
    final column = (x / (dimensions.width + _spacing)).floor().clamp(
      0,
      dimensions.columns - 1,
    );
    final row = (local.dy / (dimensions.height + _spacing)).floor();
    return row * dimensions.columns + column;
  }

  void _startRange(Offset position) {
    final index = _indexAt(position);
    if (index < 0 || index >= widget.weeks.length) return;

    _range = (start: index, end: index, before: {...widget.selectedWeeks});
    _dragPosition = position;
    _autoScroller = EdgeDraggingAutoScroller(
      Scrollable.of(context),
      velocityScalar: 20,
      onScrollViewScrolled: () {
        final position = _dragPosition;
        if (position != null) _dragRange(position);
      },
    );
    HapticFeedback.selectionClick();
    widget.onChanged({widget.weeks[index]});
  }

  void _updateRange(Offset position) {
    final range = _range;
    if (range == null) return;
    final end = _indexAt(position).clamp(0, widget.weeks.length - 1);
    if (end == range.end) return;

    _range = (start: range.start, end: end, before: range.before);
    final first = math.min(range.start, end);
    final last = math.max(range.start, end);
    widget.onChanged(widget.weeks.sublist(first, last + 1).toSet());
    HapticFeedback.selectionClick();
  }

  void _dragRange(Offset position) {
    if (_range == null) return;
    _dragPosition = position;
    _updateRange(position);
    _autoScroller!.startAutoScrollIfNecessary(
      Rect.fromCenter(center: position, width: 1, height: 1),
    );
  }

  void _endRange() {
    _autoScroller?.stopAutoScroll();
    _autoScroller = null;
    _dragPosition = null;
    _range = null;
  }

  void _finishRange(Offset position) {
    _updateRange(position);
    _endRange();
  }

  void _cancelRange() {
    final before = _range?.before;
    _endRange();
    if (before != null) widget.onChanged(before);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final weeks = widget.weeks;
    final selectedWeeks = widget.selectedWeeks;
    final enabled = widget.enabled;
    final onChanged = widget.onChanged;
    final hasSummerWeeks = weeks.any((week) => week < 0);
    final hasRegularWeeks = weeks.any((week) => week > 0);
    final selectedCount = weeks.where(selectedWeeks.contains).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.courseEditorWeeks,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton.icon(
              onPressed: enabled ? widget.onManageRange : null,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                textStyle: theme.textTheme.labelMedium,
              ),
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: Text(l10n.weekManagement),
            ),
          ],
        ),
        AppSelectionBar(
          selectedCount: selectedCount,
          totalCount: weeks.length,
          summary: l10n.selectedItems(selectedCount),
          enabled: enabled,
          onSelectAll: () => onChanged(weeks.toSet()),
          onClear: () => onChanged({}),
        ),
        if (hasSummerWeeks || hasRegularWeeks) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final preset in _WeekPreset.values)
                if ((preset == _WeekPreset.summer && hasSummerWeeks) ||
                    (preset == _WeekPreset.regular && hasRegularWeeks))
                  ActionChip(
                    label: Text(preset.label(l10n)),
                    onPressed: enabled
                        ? () => onChanged(preset.weeksIn(weeks))
                        : null,
                  ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final dimensions = _dimensions(constraints.maxWidth);
            return GestureDetector(
              supportedDevices: const {PointerDeviceKind.mouse},
              behavior: HitTestBehavior.opaque,
              dragStartBehavior: DragStartBehavior.down,
              onPanStart: enabled
                  ? (details) => _startRange(details.globalPosition)
                  : null,
              onPanUpdate: enabled
                  ? (details) => _dragRange(details.globalPosition)
                  : null,
              onPanEnd: enabled
                  ? (details) => _finishRange(details.globalPosition)
                  : null,
              onPanCancel: enabled ? _cancelRange : null,
              child: GestureDetector(
                key: _grid,
                supportedDevices: const {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.stylus,
                  PointerDeviceKind.invertedStylus,
                  PointerDeviceKind.trackpad,
                },
                behavior: HitTestBehavior.opaque,
                onLongPressStart: enabled
                    ? (details) => _startRange(details.globalPosition)
                    : null,
                onLongPressMoveUpdate: enabled
                    ? (details) => _dragRange(details.globalPosition)
                    : null,
                onLongPressEnd: enabled
                    ? (details) => _finishRange(details.globalPosition)
                    : null,
                onLongPressCancel: enabled ? _cancelRange : null,
                child: GridView.builder(
                  shrinkWrap: true,
                  primary: false,
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: dimensions.columns,
                    crossAxisSpacing: _spacing,
                    mainAxisSpacing: _spacing,
                    mainAxisExtent: dimensions.height,
                  ),
                  itemCount: weeks.length,
                  itemBuilder: (context, index) {
                    final week = weeks[index];
                    final selected = selectedWeeks.contains(week);
                    return AppSelectionButton(
                      selected: selected,
                      minimumSize: Size(0, dimensions.height),
                      padding: EdgeInsets.zero,
                      onPressed: !enabled
                          ? null
                          : () {
                              final weeks = {...selectedWeeks};
                              if (selected) {
                                weeks.remove(week);
                              } else {
                                weeks.add(week);
                              }
                              onChanged(weeks);
                            },
                      child: Text(
                        '$week',
                        semanticsLabel: l10n.weekNumber(week),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
