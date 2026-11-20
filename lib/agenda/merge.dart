part of 'controller.dart';

({List<AgendaEntry> entries, List<SkippedAgendaUpdate> skipped})
_mergeDeadlineEntries(
  List<AgendaEntry> savedEntries,
  List<AgendaEntry> incoming,
) {
  final unmatched = [...incoming];
  final matched = <AgendaEntry>[];
  final merged = <AgendaEntry>[];
  final skipped = <SkippedAgendaUpdate>[];
  for (final saved in savedEntries) {
    final index = unmatched.indexWhere(
      (entry) => _sameRemoteEntry(saved, entry),
    );
    if (index < 0) {
      if (matched.any((entry) => _sameRemoteEntry(saved, entry))) continue;
      merged.add(saved);
      continue;
    }
    final entry = unmatched.removeAt(index);
    matched.add(entry);
    final result = saved.local
        ? (saved.url == null && entry.url != null
              ? saved.copyWith(url: entry.url)
              : saved)
        : entry.copyWith(deleted: saved.deleted, tailDays: saved.tailDays);
    merged.add(result);
    if (saved.local && !saved.deleted) {
      final update = SkippedAgendaUpdate(saved: saved, incoming: entry);
      if (update.hasChanges) skipped.add(update);
    }
  }
  return (entries: [...merged, ...unmatched], skipped: skipped);
}

bool _sameRemoteEntry(AgendaEntry left, AgendaEntry right) {
  if (left.id == right.id && left.source == right.source) return true;
  if (left.kind != AgendaKind.deadline ||
      right.kind != AgendaKind.deadline ||
      left.source == null ||
      left.source != right.source) {
    return false;
  }

  final leftUrl = left.url;
  final rightUrl = right.url;
  if (leftUrl != null && rightUrl != null) {
    if (leftUrl.scheme != rightUrl.scheme ||
        leftUrl.host != rightUrl.host ||
        leftUrl.path != rightUrl.path) {
      return false;
    }
    final leftId = leftUrl.queryParameters['id'];
    final rightId = rightUrl.queryParameters['id'];
    if (leftUrl.path != '/course/view.php' &&
        (leftId != null || rightId != null)) {
      return leftId == rightId;
    }
    final leftActivity = leftUrl.fragment;
    final rightActivity = rightUrl.fragment;
    if (leftActivity.isNotEmpty && rightActivity.isNotEmpty) {
      return leftActivity == rightActivity;
    }
    return leftUrl.replace(fragment: '') == rightUrl.replace(fragment: '') &&
        _sameDeadlineMetadata(left, right);
  }

  return _sameDeadlineMetadata(left, right);
}

bool _sameDeadlineMetadata(AgendaEntry left, AgendaEntry right) {
  return left.course == right.course &&
      left.title == right.title &&
      left.startsAt == right.startsAt &&
      left.allDay == right.allDay &&
      // When IDs differ, an opening time is not equivalent to a due time.
      left.startOnly == right.startOnly;
}
