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
         color: entry.color,
         details: entry.details,
         tailDays: entry.tailDays,
         startOnly: entry.startOnly,
         deadlineCutoffWindow: entry.deadlineCutoffWindow,
       );

  final String? titleOverride;
  final String? notesOverride;
}
