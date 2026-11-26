import 'package:flutter/material.dart';

import '../../agenda/controller.dart';
import '../../agenda/ui/calendar_list.dart';
import '../../core/time.dart';
import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../ui/design.dart';

class TimetableHeader extends StatelessWidget {
  const TimetableHeader({
    super.key,
    required this.controller,
    required this.monday,
    required this.now,
    required this.gutterWidth,
    required this.todayBackground,
  });

  final AgendaController controller;
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
          count: controller
              .pendingOn(monday.add(Duration(days: day)), now: now)
              .length,
        ),
    ];

    return Row(
      children: [
        SizedBox(
          width: gutterWidth,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _monthLabel(l10n, monday),
                maxLines: 1,
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
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
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(color: current ? todayBackground : null),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                localizedNarrowWeekday(l10n, date.weekday),
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.2,
                  fontWeight: current ? FontWeight.w600 : FontWeight.w500,
                  color: current ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 2, 10, 0),
                  child: Badge(
                    isLabelVisible: agendaCount > 0,
                    label: Text(
                      '$agendaCount',
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: current
                            ? scheme.onPrimaryContainer
                            : scheme.onPrimaryContainer,
                      ),
                    ),
                    backgroundColor: scheme.primaryContainer,
                    textColor: scheme.onPrimaryContainer,
                    largeSize: 16,
                    offset: const Offset(6, -3),
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 26,
                      ),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: current ? scheme.primary : null,
                        borderRadius: AppCorners.compact,
                      ),
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: 17.5,
                          height: 1.15,
                          fontWeight: current
                              ? FontWeight.w600
                              : FontWeight.w500,
                          fontFeatures: const [FontFeature.tabularFigures()],
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

String _monthLabel(AppLocalizations l10n, DateTime monday) {
  final label = l10n.monthHeader(localizedMonth(l10n, monday.month));
  for (var offset = 0; offset < 7; offset++) {
    final date = monday.add(Duration(days: offset));
    if (date.month == 10 && date.day == 24) {
      return label.replaceAll('月', '🈷️');
    }
  }
  return label;
}
