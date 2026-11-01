import '../core/json.dart';

sealed class AgendaEntryDetails {
  const AgendaEntryDetails();

  factory AgendaEntryDetails.fromJson(Map<String, dynamic> json) =>
      switch (jsonStringField(json, 'type')) {
        'physicsLab' => PhysicsLabDeadlineDetails.fromJson(json),
        'mooc' => MoocDeadlineDetails.fromJson(json),
        'exam' => ExamAgendaDetails.fromJson(json),
        final type => throw FormatException('details.type 格式不正确：$type'),
      };

  Map<String, Object?> toJson();
}

enum PhysicsLabDeadlineKind { preview, report }

final class PhysicsLabDeadlineDetails extends AgendaEntryDetails {
  PhysicsLabDeadlineDetails({
    required this.kind,
    required this.courseLabel,
    required this.classStartsAt,
    required this.classEndsAt,
  }) {
    if (courseLabel.trim().isEmpty || !classEndsAt.isAfter(classStartsAt)) {
      throw const FormatException('大物实验日程详情格式不正确');
    }
  }

  factory PhysicsLabDeadlineDetails.fromJson(Map<String, dynamic> json) =>
      PhysicsLabDeadlineDetails(
        kind:
            PhysicsLabDeadlineKind.values
                .where((value) => value.name == jsonStringField(json, 'kind'))
                .firstOrNull ??
            (throw const FormatException('details.kind 格式不正确')),
        courseLabel: jsonStringField(json, 'courseLabel'),
        classStartsAt: jsonDateTime('classStartsAt', json['classStartsAt']),
        classEndsAt: jsonDateTime('classEndsAt', json['classEndsAt']),
      );

  final PhysicsLabDeadlineKind kind;
  final String courseLabel;
  final DateTime classStartsAt;
  final DateTime classEndsAt;

  @override
  Map<String, Object?> toJson() => {
    'type': 'physicsLab',
    'kind': kind.name,
    'courseLabel': courseLabel,
    'classStartsAt': classStartsAt.toIso8601String(),
    'classEndsAt': classEndsAt.toIso8601String(),
  };
}

enum MoocDeadlineKind { homework, quiz, exam, peerReview }

final class MoocDeadlineDetails extends AgendaEntryDetails {
  MoocDeadlineDetails({
    required this.kind,
    required this.spoc,
    this.releaseAt,
    this.submissionDueAt,
  }) {
    if (kind != MoocDeadlineKind.peerReview && submissionDueAt != null) {
      throw const FormatException('非互评任务不能包含提交截止时间');
    }
  }

  factory MoocDeadlineDetails.fromJson(Map<String, dynamic> json) =>
      MoocDeadlineDetails(
        kind:
            MoocDeadlineKind.values
                .where((value) => value.name == jsonStringField(json, 'kind'))
                .firstOrNull ??
            (throw const FormatException('details.kind 格式不正确')),
        spoc: jsonBoolField(json, 'spoc'),
        releaseAt: jsonDateTimeOrNull('releaseAt', json['releaseAt']),
        submissionDueAt: jsonDateTimeOrNull(
          'submissionDueAt',
          json['submissionDueAt'],
        ),
      );

  final MoocDeadlineKind kind;
  final bool spoc;
  final DateTime? releaseAt;
  final DateTime? submissionDueAt;

  @override
  Map<String, Object?> toJson() => {
    'type': 'mooc',
    'kind': kind.name,
    'spoc': spoc,
    'releaseAt': releaseAt?.toIso8601String(),
    'submissionDueAt': submissionDueAt?.toIso8601String(),
  };
}

final class ExamAgendaDetails extends AgendaEntryDetails {
  const ExamAgendaDetails({this.seat = '', this.mode = '', this.teacher = ''});

  factory ExamAgendaDetails.fromJson(Map<String, dynamic> json) =>
      ExamAgendaDetails(
        seat: jsonStringField(json, 'seat'),
        mode: jsonStringField(json, 'mode'),
        teacher: jsonStringField(json, 'teacher'),
      );

  final String seat;
  final String mode;
  final String teacher;

  @override
  Map<String, Object?> toJson() => {
    'type': 'exam',
    'seat': seat,
    'mode': mode,
    'teacher': teacher,
  };
}
