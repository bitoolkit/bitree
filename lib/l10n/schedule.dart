import '../schedule/model.dart';
import 'app_localizations.dart';

String localizedTerm(AppLocalizations l10n, SemesterSchedule schedule) {
  final parts = schedule.term.split('-');
  if (parts.length != 3 || !const {'1', '2'}.contains(parts[2])) {
    return schedule.term;
  }
  final years = '${parts[0]}–${parts[1]}';
  return parts[2] == '1' ? l10n.termFall(years) : l10n.termSpring(years);
}
