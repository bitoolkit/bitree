import 'package:flutter/material.dart';

import '../../app/controller.dart';
import '../../ui/swipe_pager.dart';
import 'timetable.dart';

class WeekPager extends StatefulWidget {
  const WeekPager({super.key, required this.controller, this.active = true});

  final AppController controller;
  final bool active;

  @override
  State<WeekPager> createState() => _WeekPagerState();
}

class _WeekPagerState extends State<WeekPager> {
  double _scrollOffset = 0;

  @override
  Widget build(BuildContext context) {
    final weeks = widget.controller.timetable.weeks;
    return SwipePager(
      index: weeks.indexOf(widget.controller.timetable.week),
      itemCount: weeks.length,
      onChanged: (page) => widget.controller.timetable.selectWeek(weeks[page]),
      itemBuilder: (context, page) => Timetable(
        controller: widget.controller,
        week: weeks[page],
        initialScrollOffset: _scrollOffset,
        onScroll: (offset) {
          // Retained neighboring weeks also restore after a height-mode change.
          // Only the selected week owns the offset reused by new pages.
          if (weeks[page] == widget.controller.timetable.week) {
            _scrollOffset = offset;
          }
        },
        active:
            widget.active && weeks[page] == widget.controller.timetable.week,
      ),
    );
  }
}
