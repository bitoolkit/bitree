import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../agenda/controller.dart';
import '../../automation/controller.dart';
import '../../ui/swipe_pager.dart';
import '../controller.dart';
import '../height_mode.dart';
import 'timetable.dart';

class WeekPager extends StatefulWidget {
  const WeekPager({
    super.key,
    required this.timetable,
    required this.agenda,
    this.automation,
    required this.heightMode,
    this.active = true,
  });

  final TimetableController timetable;
  final AgendaController agenda;
  final AutomationController? automation;
  final ValueListenable<TimetableHeightMode> heightMode;
  final bool active;

  @override
  State<WeekPager> createState() => _WeekPagerState();
}

class _WeekPagerState extends State<WeekPager> {
  double _scrollOffset = 0;

  @override
  Widget build(BuildContext context) {
    final weeks = widget.timetable.weeks;
    return SwipePager(
      index: weeks.indexOf(widget.timetable.week),
      itemCount: weeks.length,
      onChanged: (page) => widget.timetable.selectWeek(weeks[page]),
      itemBuilder: (context, page) => Timetable(
        timetable: widget.timetable,
        agenda: widget.agenda,
        automation: widget.automation,
        heightMode: widget.heightMode,
        week: weeks[page],
        initialScrollOffset: _scrollOffset,
        onScroll: (offset) {
          // Retained neighboring weeks also restore after a height-mode change.
          // Only the selected week owns the offset reused by new pages.
          if (weeks[page] == widget.timetable.week) {
            _scrollOffset = offset;
          }
        },
        active: widget.active && weeks[page] == widget.timetable.week,
      ),
    );
  }
}
