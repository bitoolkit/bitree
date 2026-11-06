import 'model.dart';

/// Ephemeral overrides for generated/localized text. These never enter storage;
/// the normal metadata remains available for colors, links and detail views.
class AgendaPresentation extends AgendaEntry {
  AgendaPresentation(
    AgendaEntry entry, {
    this.titleOverride,
    this.notesOverride,
  }) : super(
         id: entry.id,
         title: entry.title,
         kind: entry.kind,
         startsAt: entry.startsAt,
         endsAt: entry.endsAt,
         allDay: entry.allDay,
         location: entry.location,
         notes: entry.notes,
         done: entry.done,
         deleted: entry.deleted,
         term: entry.term,
         local: entry.local,
         source: entry.source,
         course: entry.course,
         url: entry.url,
         details: entry.details,
         tailDays: entry.tailDays,
       );

  final String? titleOverride;
  final String? notesOverride;
}
