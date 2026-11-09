part of 'lexue_deadlines.dart';

List<AgendaEntry> _mergeActivityDeadlines(
  List<AgendaEntry> calendar,
  List<AgendaEntry> activities,
) {
  final result = [...calendar];
  for (final activity in activities) {
    final index = result.indexWhere(
      (entry) => _sameLexueDeadline(entry, activity),
    );
    if (index < 0) {
      if (!result.any((entry) => entry.id == activity.id)) {
        result.add(activity);
      }
      continue;
    }
    final existing = result[index];
    result[index] = AgendaEntry(
      id: existing.id,
      title: activity.title,
      kind: activity.kind,
      startsAt: activity.startsAt,
      allDay: activity.allDay,
      notes: activity.notes,
      done: existing.done || activity.done,
      deleted: existing.deleted,
      local: existing.local,
      source: activity.source,
      course: activity.course,
      url: activity.url,
    );
  }
  return result;
}

bool _sameLexueDeadline(AgendaEntry left, AgendaEntry right) {
  final leftUrl = left.url;
  final rightUrl = right.url;
  if (leftUrl != null &&
      rightUrl != null &&
      leftUrl.host == rightUrl.host &&
      leftUrl.path == rightUrl.path &&
      leftUrl.queryParameters['id'] == rightUrl.queryParameters['id']) {
    return true;
  }
  return left.course == right.course &&
      left.title == right.title &&
      left.startsAt == right.startsAt &&
      left.allDay == right.allDay;
}
