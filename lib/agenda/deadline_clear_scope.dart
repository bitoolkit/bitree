import 'deadline_source.dart';
import 'model.dart';
import 'physics_lab_deadlines.dart';

/// Disjoint origin groups, independent of the local-edit protection flag.
/// Clearing includes completed entries and soft-deleted records.
enum DeadlineClearScope {
  manual,
  physicsLab,
  lexue,
  eclass,
  mooc;

  bool includes(AgendaEntry entry) =>
      entry.isDeadline &&
      (switch (this) {
        DeadlineClearScope.manual =>
          entry.source == null && !isPhysicsLabDeadline(entry),
        DeadlineClearScope.physicsLab => isPhysicsLabDeadline(entry),
        DeadlineClearScope.lexue => entry.source == DeadlineSource.lexue,
        DeadlineClearScope.eclass => entry.source == DeadlineSource.eclass,
        DeadlineClearScope.mooc => entry.source == DeadlineSource.mooc,
      });
}
