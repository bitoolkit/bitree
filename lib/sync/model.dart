import '../agenda/deadline_source.dart';

enum SyncTarget {
  schedule,
  exams,
  grades,
  studyPlan,
  lexue(DeadlineSource.lexue),
  eclass(DeadlineSource.eclass),
  mooc(DeadlineSource.mooc),
  physicsLab;

  const SyncTarget([this.source]);
  final DeadlineSource? source;

  bool get usesSchoolSession => switch (this) {
    schedule || exams || grades || studyPlan || lexue || eclass => true,
    mooc || physicsLab => false,
  };

  SyncCategory get category => switch (this) {
    schedule || exams || grades || studyPlan => SyncCategory.schoolData,
    lexue || eclass || mooc || physicsLab => SyncCategory.deadlineData,
  };

  bool get isAcademicRecord => this == grades || this == studyPlan;
}

enum SyncCategory { schoolData, deadlineData }

enum SyncOutcome {
  synced,
  failed,
  needsLogin,
  needsVerification,
  cancelled,
  noSchedule,
  saveFailed,
}

class SyncResult {
  const SyncResult(this.outcome, {this.count, this.detail});

  final SyncOutcome outcome;
  final int? count;
  final Object? detail;
}
