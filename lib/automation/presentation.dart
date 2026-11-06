import '../agenda/presentation.dart';
import '../schedule/model.dart';

/// Script-created rows have no persisted record for edit or completion actions.
abstract interface class ScriptGenerated {}

class ScriptCourse extends Course implements ScriptGenerated {
  ScriptCourse(Course course)
    : super(
        id: course.id,
        name: course.name,
        teacher: course.teacher,
        room: course.room,
        campus: course.campus,
        number: course.number,
        description: course.description,
        weekday: course.weekday,
        startSection: course.startSection,
        endSection: course.endSection,
        weeks: course.weeks,
        local: course.local,
      );
}

class ScriptAgendaEntry extends AgendaPresentation implements ScriptGenerated {
  ScriptAgendaEntry(super.entry);
}
