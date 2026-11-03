import '../schedule/model.dart';
import 'model.dart';

bool agendaEntryMatchesTerm(
  AgendaEntry entry,
  String term,
  Iterable<SemesterSchedule> schedules,
) {
  final explicitTerm = entry.term?.trim();
  if (explicitTerm != null && explicitTerm.isNotEmpty) {
    return explicitTerm == term;
  }

  for (final schedule in schedules) {
    if (schedule.term != term) continue;
    final week = schedule.weekAt(entry.startsAt);
    if (week >= schedule.firstWeek && week <= schedule.lastWeek) {
      return true;
    }
  }
  return false;
}

List<AgendaEntry> filterAgendaByTerm(
  Iterable<AgendaEntry> entries,
  String? term,
  Iterable<SemesterSchedule> schedules,
) => term == null
    ? entries.toList()
    : entries
          .where((entry) => agendaEntryMatchesTerm(entry, term, schedules))
          .toList();
