import '../agenda/model.dart';
import 'legacy.dart';
import 'source.dart';

/// Applies one source read to the saved agenda. Manual rows and other source
/// instances are left untouched.
List<AgendaEntry> mergeAgendaSource({
  required Iterable<AgendaEntry> existing,
  required Iterable<AgendaEntry> incoming,
  required String sourceInstanceId,
  required SourceResource resource,
  bool replace = false,
  String? scope,
  Set<String> removedRemoteIds = const {},
}) {
  final result = <String, AgendaEntry>{
    for (final entry in existing) entry.id: entry,
  };
  final index = <String, String>{};
  for (final entry in existing) {
    final origin = _originFor(entry);
    if (origin != null) index[origin.key] = entry.id;
  }

  final seen = <String>{};
  for (final raw in incoming) {
    final origin =
        _originFor(raw)?.copyWith(
          sourceInstanceId: sourceInstanceId,
          resource: resource,
          scope: scope,
        ) ??
        RecordOrigin(
          sourceInstanceId: sourceInstanceId,
          resource: resource,
          remoteId: LegacyRecordIds.deadlineRemoteId(
            id: raw.id,
            source: raw.source?.name,
            url: raw.url,
          ),
          scope: scope,
        );
    final normalized = raw.copyWith(origin: origin);
    final existingId = index[origin.key];
    final saved = existingId == null ? null : result[existingId];
    if (saved == null) {
      result[normalized.id] = normalized;
      index[origin.key] = normalized.id;
      seen.add(origin.key);
      continue;
    }
    seen.add(origin.key);
    // The internal id never comes from the source. Keep the saved identity so
    // editors and tombstones continue to point at the same record.
    result[saved.id] = saved.applySource(normalized).copyWith(
      id: saved.id,
      deleted: saved.deleted || normalized.deleted,
      local: saved.local || saved.overrides.isNotEmpty,
    );
  }

  if (replace) {
    for (final entry in [...result.values]) {
      final origin = _originFor(entry);
      if (origin == null ||
          origin.sourceInstanceId != sourceInstanceId ||
          origin.resource != resource ||
          !_sameScope(origin.scope, scope) ||
          seen.contains(origin.key)) {
        continue;
      }
      final explicitlyRemoved = removedRemoteIds.contains(origin.remoteId);
      if (explicitlyRemoved || (!entry.isEdited && !entry.deleted)) {
        result.remove(entry.id);
      } else if (!entry.deleted) {
        result[entry.id] = entry.copyWith(
          sourceRemoved: true,
          local: true,
        );
      }
    }
  }

  return result.values.toList();
}

/// Assigns stable origins and collapses old duplicates after reading legacy
/// JSON. Records without a platform source remain manual.
List<AgendaEntry> normalizeAgendaOrigins(Iterable<AgendaEntry> entries) {
  final groups = <String, List<AgendaEntry>>{};
  final order = <({String? key, AgendaEntry entry})>[];
  final manual = <AgendaEntry>[];
  for (final entry in entries) {
    final origin = _originFor(entry);
    if (origin == null) {
      manual.add(entry);
      order.add((key: null, entry: entry));
    } else {
      groups.putIfAbsent(origin.key, () => []).add(
        entry.copyWith(origin: origin),
      );
      order.add((key: origin.key, entry: entry));
    }
  }
  final normalized = <String, AgendaEntry>{};
  for (final group in groups.values) {
    final edited = group.where((entry) => entry.isEdited).toList();
    final candidates = edited.isNotEmpty ? edited : group;
    final kept = candidates.reduce(
      (current, entry) =>
          _identityPreference(entry) > _identityPreference(current)
          ? entry
          : current,
    );
    final anyDone = group.any((entry) => entry.done);
    final allDeleted = group.every((entry) => entry.deleted);
    normalized[kept.origin!.key] =
      kept.copyWith(
        done: anyDone,
        deleted: allDeleted,
        local: group.any((entry) => entry.local),
      );
  }
  final result = <AgendaEntry>[];
  final seen = <String>{};
  var manualIndex = 0;
  for (final item in order) {
    if (item.key == null) {
      result.add(manual[manualIndex++]);
    } else if (seen.add(item.key!)) {
      result.add(normalized[item.key]!);
    }
  }
  return result;
}

/// Prefer the id form produced by the current source implementation when a
/// legacy calendar event and a module-page record collapse to one remote id.
int _identityPreference(AgendaEntry entry) =>
    entry.id.startsWith('lexue-cmid-') ? 2 : 1;

RecordOrigin? _originFor(AgendaEntry entry) {
  if (entry.origin != null) return entry.origin;
  if (entry.source != null) {
    return LegacyRecordIds.deadlineOrigin(
      id: entry.id,
      source: entry.source!.name,
      url: entry.url,
      resource: _resourceFor(entry.kind),
    );
  }
  if (entry.kind == AgendaKind.deadline &&
      entry.id.startsWith('physics-lab:')) {
    return LegacyRecordIds.physicsLabOrigin(entry.id);
  }
  if (entry.kind == AgendaKind.exam && entry.id.startsWith('exam-')) {
    return LegacyRecordIds.schoolExamOrigin(entry.id);
  }
  return null;
}

SourceResource _resourceFor(AgendaKind kind) => switch (kind) {
  AgendaKind.deadline => SourceResource.deadline,
  AgendaKind.event => SourceResource.event,
  AgendaKind.exam => SourceResource.exam,
};

bool _sameScope(String? left, String? right) =>
    left == null || right == null || left == right;

/// A helper for callers that need the normalized identity of a legacy row.
RecordOrigin? agendaOriginFor(AgendaEntry entry) => _originFor(entry);
