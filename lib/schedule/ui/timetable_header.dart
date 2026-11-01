import 'package:flutter/material.dart';

import '../../agenda/ui/calendar_list.dart';
import '../../app/controller.dart';
import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../ui/design.dart';
import '../model.dart';

class TimetableHeader extends StatelessWidget {
  const TimetableHeader({
    super.key,
    required this.controller,
    required this.monday,
    required this.now,
    required this.gutterWidth,
    required this.todayBackground,
  });

  final AppController controller;
  final DateTime monday;
  final DateTime now;
  final double gutterWidth;
  final Color todayBackground;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final today = calendarDate(now);
    final dayCounts = [
      for (var day = 0; day < 7; day++)
        (
          date: monday.add(Duration(days: day)),
          count: controller.agenda
              .pendingOn(monday.add(Duration(days: day)), now: now)
              .length,
        ),
    ];

    return Row(
      children: [
        SizedBox(
          width: gutterWidth,
          child: Center(
            child: Text(
              l10n.monthHeader(localizedMonth(l10n, monday.month)),
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ),
        ),
        for (final day in dayCounts)
          Expanded(
            child: InkWell(
              onTap: () => showAgendaDay(context, controller, day.date),
              child: _DateHeading(
                date: day.date,
                today: today,
                todayBackground: todayBackground,
                agendaCount: day.count,
              ),
            ),
          ),
      ],
    );
  }
}

class _DateHeading extends StatelessWidget {
  const _DateHeading({
    required this.date,
    required this.today,
    required this.todayBackground,
    required this.agendaCount,
  });

  final DateTime date;
  final DateTime today;
  final Color todayBackground;
  final int agendaCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final current = date == today;
    return Semantics(
      label: l10n.timetableDaySemantics(
        localizedMonthDay(l10n, date.month, date.day),
        localizedShortWeekday(l10n, date.weekday),
        current ? l10n.timetableTodaySuffix : '',
        agendaCount > 0 ? l10n.timetableAgendaSuffix(agendaCount) : '',
      ),
      child: ExcludeSemantics(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: current ? todayBackground : null,
            borderRadius: const BorderRadius.vertical(
              top: AppCorners.controlRadius,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                localizedNarrowWeekday(l10n, date.weekday),
                style: TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  color: current ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: Badge(
                    isLabelVisible: agendaCount > 0,
                    label: Text('$agendaCount'),
                    backgroundColor: scheme.primaryContainer,
                    textColor: scheme.onPrimaryContainer,
                    textStyle: const TextStyle(fontSize: 10, height: 1.2),
                    largeSize: 16,
                    offset: const Offset(4, -4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: current ? scheme.primary : null,
                        borderRadius: AppCorners.control,
                      ),
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: 20,
                          height: 1.15,
                          fontWeight: current
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: current ? scheme.onPrimary : scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
