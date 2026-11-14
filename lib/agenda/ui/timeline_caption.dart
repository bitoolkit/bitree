import '../../core/time.dart';
import '../../l10n/l10n.dart';
import '../model.dart';

/// Short `11/3` day marker shared by the wrapped timeline captions and the
/// timeline grid header.
String agendaTimelineShortDate(DateTime date) => '${date.month}/${date.day}';

/// Time caption of a timeline card, shared by every card style so a deadline,
/// exam and event describe their span with one set of wording.
///
/// Narrow cards wrap on purpose: the two-line forms keep both endpoints
/// readable at the smallest zoom, unlike the single-line list caption in
/// `localizedAgendaTime`.
String agendaTimelineCaption(AppLocalizations l10n, AgendaEntry entry) {
  if (entry.isDeadline) {
    // An open-ended deadline has no due time, so it reports when it opened.
    if (entry.startOnly) {
      return l10n.agendaTimelineStarts(clockText(entry.startsAt));
    }
    if (entry.hasAdjustedDeadline) {
      return '${clockText(entry.dueAt)} ${l10n.agendaAdjustedDeadline}';
    }
    return entry.effectiveAllDay
        ? l10n.allDayUntil
        : l10n.dueAt(clockText(entry.dueAt));
  }
  final end = entry.endsAt!;
  if (entry.allDay) {
    final lastDay = end.subtract(const Duration(days: 1));
    return calendarDate(lastDay) == calendarDate(entry.startsAt)
        ? l10n.allDay
        : '${agendaTimelineShortDate(entry.startsAt)}–'
              '${agendaTimelineShortDate(lastDay)}\n${l10n.allDay}';
  }
  if (calendarDate(entry.startsAt) == calendarDate(end)) {
    return '${clockText(entry.startsAt)}–${clockText(end)}';
  }
  return '${agendaTimelineShortDate(entry.startsAt)} '
      '${clockText(entry.startsAt)}\n'
      '→ ${agendaTimelineShortDate(end)} ${clockText(end)}';
}
