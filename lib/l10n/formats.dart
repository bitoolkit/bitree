import 'package:flutter/material.dart' show ThemeMode;

import '../agenda/calendar.dart';
import '../agenda/deadline_clear_scope.dart';
import '../agenda/deadline_source.dart';
import '../agenda/model.dart';
import '../classrooms/model.dart';
import '../core/time.dart';
import '../mooc/controller.dart';
import '../mooc/errors.dart';
import '../schedule/model.dart';
import '../schedule/section_times.dart';
import '../school/controller.dart';
import '../sync/controller.dart';
import '../updates/release.dart';
import '../wencui/atlas.dart';
import '../wencui/place.dart';
import 'app_localizations.dart';
import 'schedule.dart';

export 'schedule.dart';

extension LocalizedThemeMode on ThemeMode {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    ThemeMode.system => l10n.followSystem,
    ThemeMode.light => l10n.themeLight,
    ThemeMode.dark => l10n.themeDark,
  };
}

String localizedWeekday(AppLocalizations l10n, int weekday) =>
    switch (weekday) {
      1 => l10n.weekdayMonday,
      2 => l10n.weekdayTuesday,
      3 => l10n.weekdayWednesday,
      4 => l10n.weekdayThursday,
      5 => l10n.weekdayFriday,
      6 => l10n.weekdaySaturday,
      7 => l10n.weekdaySunday,
      _ => '',
    };

String localizedShortWeekday(AppLocalizations l10n, int weekday) =>
    switch (weekday) {
      1 => l10n.weekdayShortMonday,
      2 => l10n.weekdayShortTuesday,
      3 => l10n.weekdayShortWednesday,
      4 => l10n.weekdayShortThursday,
      5 => l10n.weekdayShortFriday,
      6 => l10n.weekdayShortSaturday,
      7 => l10n.weekdayShortSunday,
      _ => '',
    };

String localizedNarrowWeekday(AppLocalizations l10n, int weekday) =>
    switch (weekday) {
      1 => l10n.weekdayNarrowMonday,
      2 => l10n.weekdayNarrowTuesday,
      3 => l10n.weekdayNarrowWednesday,
      4 => l10n.weekdayNarrowThursday,
      5 => l10n.weekdayNarrowFriday,
      6 => l10n.weekdayNarrowSaturday,
      7 => l10n.weekdayNarrowSunday,
      _ => '',
    };

List<String> _monthNames(AppLocalizations l10n) => l10n.monthNames.split(',');

String localizedMonth(AppLocalizations l10n, int month) =>
    _monthNames(l10n)[month - 1];

String localizedMonthDay(AppLocalizations l10n, int month, int day) =>
    l10n.monthDay(localizedMonth(l10n, month), day);

String localizedYearMonthDay(
  AppLocalizations l10n,
  int year,
  int month,
  int day,
) => l10n.yearMonthDay(localizedMonth(l10n, month), day, year);

String localizedAgendaDate(AppLocalizations l10n, DateTime date) {
  final day = calendarDate(date);
  final today = calendarDate(campusNow());
  final weekday = localizedShortWeekday(l10n, date.weekday);
  final dateLabel = date.year == today.year
      ? localizedMonthDay(l10n, date.month, date.day)
      : localizedYearMonthDay(l10n, date.year, date.month, date.day);
  final relative = switch (day.difference(today).inDays) {
    0 => l10n.today,
    1 => l10n.tomorrow,
    -1 => l10n.yesterday,
    _ => null,
  };
  return relative == null
      ? l10n.dateWithWeekday(weekday, dateLabel)
      : l10n.relativeDateWithWeekday(relative, weekday, dateLabel);
}

String localizedCourseSection(AppLocalizations l10n, Course course) {
  final start = course.startSection;
  if (start == null) return l10n.sectionPending;
  final end = course.endSection!;
  return start == end
      ? l10n.sectionSingle(start)
      : l10n.sectionRange(start, end);
}

String localizedCourseTime(AppLocalizations l10n, Course course) {
  final start = course.startSection;
  if (start == null) return l10n.timePending;
  return '${sectionTimes[start - 1].$1}–${sectionTimes[course.endSection! - 1].$2}';
}

String localizedWeeks(AppLocalizations l10n, Iterable<int> input) {
  final weeks = input.toSet().toList()..sort();
  if (weeks.isEmpty) return l10n.weeksPending;
  final ranges = <String>[];
  var start = weeks.first;
  var end = start;
  for (final week in weeks.skip(1)) {
    if (week == end + 1) {
      end = week;
    } else {
      ranges.add(start == end ? '$start' : '$start–$end');
      start = end = week;
    }
  }
  ranges.add(start == end ? '$start' : '$start–$end');
  return l10n.weekList(ranges.join(l10n.listSeparator));
}

extension LocalizedAgendaKind on AgendaKind {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    AgendaKind.event => l10n.agendaKindEvent,
    AgendaKind.deadline => l10n.agendaKindDeadline,
    AgendaKind.exam => l10n.agendaKindExam,
  };
}

extension LocalizedDeadlineSource on DeadlineSource {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    DeadlineSource.lexue => l10n.deadlineSourceLexue,
    DeadlineSource.eclass => l10n.deadlineSourceEclass,
    DeadlineSource.mooc => l10n.deadlineSourceMooc,
  };
}

extension LocalizedDeadlineScope on DeadlineClearScope {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    DeadlineClearScope.manual => l10n.deadlineManualScope,
    DeadlineClearScope.physicsLab => l10n.deadlinePhysicsLab,
    DeadlineClearScope.lexue => l10n.deadlineLexue,
    DeadlineClearScope.eclass => l10n.deadlineEclass,
    DeadlineClearScope.mooc => l10n.deadlineMooc,
  };
}

String localizedAgendaTime(AppLocalizations l10n, AgendaEntry entry) {
  if (entry.effectiveAllDay) return l10n.allDay;
  if (entry.isDeadline) {
    // Without a due date there is nothing to be due at; the opening time is
    // all this entry knows.
    if (entry.startOnly) {
      return l10n.agendaTimelineStarts(clockText(entry.startsAt));
    }
    return entry.hasAdjustedDeadline
        ? l10n.agendaCutoffAdjusted(clockText(entry.dueAt))
        : l10n.dueAt(clockText(entry.startsAt));
  }
  final end = entry.endsAt!;
  final endTime = calendarDate(entry.startsAt) == calendarDate(end)
      ? clockText(end)
      : '${localizedMonthDay(l10n, end.month, end.day)} ${clockText(end)}';
  return l10n.timeRange(clockText(entry.startsAt), endTime);
}

String localizedAgendaDateTime(AppLocalizations l10n, DateTime date) =>
    '${localizedAgendaDate(l10n, date)} ${clockText(date)}';

String localizedAgendaTitle(
  AppLocalizations l10n,
  AgendaEntry entry,
) => switch (entry.details) {
  PhysicsLabDeadlineDetails(:final kind, :final courseLabel) => switch (kind) {
    PhysicsLabDeadlineKind.preview => l10n.physicsLabPreviewReport(courseLabel),
    PhysicsLabDeadlineKind.report => l10n.physicsLabReport(courseLabel),
  },
  MoocDeadlineDetails(kind: MoocDeadlineKind.peerReview) =>
    l10n.moocPeerReviewTitle(entry.title),
  _ => entry.title,
};

String localizedAgendaNotes(AppLocalizations l10n, AgendaEntry entry) =>
    switch (entry.details) {
      null => entry.notes,
      PhysicsLabDeadlineDetails(:final classStartsAt, :final classEndsAt) =>
        l10n.physicsLabGeneratedNotes(
          localizedTerm(l10n, entry.term!),
          dateText(classStartsAt),
          '${clockText(classStartsAt)}–${clockText(classEndsAt)}',
        ),
      MoocDeadlineDetails(
        :final kind,
        :final spoc,
        :final releaseAt,
        :final submissionDueAt,
      ) =>
        [
          spoc ? l10n.moocCourseTypeSpoc : l10n.moocCourseTypeMooc,
          switch (kind) {
            MoocDeadlineKind.homework => l10n.moocTaskHomework,
            MoocDeadlineKind.quiz => l10n.moocTaskQuiz,
            MoocDeadlineKind.exam => l10n.moocTaskExam,
            MoocDeadlineKind.peerReview => l10n.moocTaskPeerReview,
          },
          if (releaseAt != null)
            kind == MoocDeadlineKind.peerReview
                ? l10n.moocStartedAt(localizedAgendaDateTime(l10n, releaseAt))
                : l10n.moocOpenedAt(localizedAgendaDateTime(l10n, releaseAt)),
          if (submissionDueAt != null)
            l10n.moocSubmissionDueAt(
              localizedAgendaDateTime(l10n, submissionDueAt),
            ),
        ].join(l10n.listSeparator),
      ExamAgendaDetails(:final seat, :final mode, :final teacher) => [
        if (seat.isNotEmpty) l10n.examSeat(seat),
        if (mode.isNotEmpty) mode,
        if (teacher.isNotEmpty) l10n.examTeacher(teacher),
      ].join('\n'),
    };

String localizedReleaseNotes(
  AppLocalizations l10n,
  AppReleaseNotes notes,
) => switch (notes) {
  ReleaseMarkdownNotes(:final markdown) => markdown,
  ReleaseChangeNotes(
    :final commits,
    :final totalCommits,
    :final comparisonUrl,
  ) =>
    [
      for (final commit in commits)
        '- ${commit.message} ([${commit.shortSha}](${commit.url}))',
      if (totalCommits > commits.length)
        '\n${l10n.releaseMoreChanges(totalCommits - commits.length, comparisonUrl.toString())}',
    ].join('\n'),
  ReleaseUnchangedNotes() => l10n.releaseNotesUnchanged,
  ReleaseUnavailableNotes() => l10n.releaseNotesUnavailable,
};

String localizedCalendarItemTime(AppLocalizations l10n, CalendarItem item) =>
    item.entry == null
    ? localizedCourseTime(l10n, item.course!)
    : localizedAgendaTime(l10n, item.entry!);

String localizedCalendarItemTitle(AppLocalizations l10n, CalendarItem item) =>
    item.entry == null
    ? item.course!.name
    : localizedAgendaTitle(l10n, item.entry!);

String localizedAgendaClock(AppLocalizations l10n, AgendaEntry entry) =>
    entry.effectiveAllDay ? l10n.allDay : clockText(entry.scheduledAt);

String localizedAgendaOverdueClock(AppLocalizations l10n, AgendaEntry entry) =>
    entry.effectiveAllDay
    ? l10n.allDay
    : clockText(entry.isDeadline ? entry.dueAt : entry.endsAt!);

String localizedAgendaTimeCaption(
  AppLocalizations l10n,
  AgendaEntry entry,
  DateTime now,
) {
  if (entry.done) return l10n.completed;
  if (entry.overdue(now)) return l10n.overdue;
  if (entry.isDeadline) {
    // Overdue is impossible without a due date, and calling the opening time
    // a due date would be wrong.
    if (entry.startOnly) return l10n.start;
    return l10n.due;
  }
  if (entry.allDay) return '';
  final end = entry.endsAt!;
  final endTime = calendarDate(entry.startsAt) == calendarDate(end)
      ? clockText(end)
      : '${localizedMonthDay(l10n, end.month, end.day)} ${clockText(end)}';
  return l10n.endsAt(endTime);
}

extension LocalizedClassroomPeriod on ClassroomPeriod {
  String localizedTime(AppLocalizations l10n) =>
      '${sectionTimes[start - 1].$1}–${sectionTimes[end - 1].$2}';

  String localizedSection(AppLocalizations l10n) => start == end
      ? l10n.sectionShort(start)
      : l10n.sectionRangeCompact(start, end);
}

extension LocalizedAccountStatus on AccountStatus {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    AccountStatus.unverified => l10n.accountUnverified,
    AccountStatus.signedIn => l10n.accountSignedIn,
    AccountStatus.signedOut => l10n.accountSignedOut,
    AccountStatus.expired => l10n.accountExpired,
    AccountStatus.smsRequired => l10n.accountSmsRequired,
    AccountStatus.imageRequired => l10n.accountImageRequired,
  };
}

extension LocalizedMoocStatus on MoocStatus {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    MoocStatus.connected => l10n.moocConnected,
    MoocStatus.signedOut => l10n.moocSignedOut,
    MoocStatus.expired => l10n.moocNeedsLogin,
  };
}

extension LocalizedSyncTarget on SyncTarget {
  String localizedTitle(AppLocalizations l10n) => switch (this) {
    SyncTarget.schedule => l10n.syncTargetSchedule,
    SyncTarget.exams => l10n.syncTargetExams,
    SyncTarget.grades => l10n.syncTargetGrades,
    SyncTarget.studyPlan => l10n.syncTargetStudyPlan,
    SyncTarget.lexue => l10n.syncTargetLexue,
    SyncTarget.eclass => l10n.syncTargetEclass,
    SyncTarget.mooc => l10n.syncTargetMooc,
    SyncTarget.physicsLab => l10n.syncTargetPhysicsLab,
  };

  String localizedAction(AppLocalizations l10n) => switch (this) {
    SyncTarget.schedule => l10n.syncActionSchedule,
    SyncTarget.exams => l10n.syncActionExams,
    SyncTarget.grades => l10n.syncActionGrades,
    SyncTarget.studyPlan => l10n.syncActionStudyPlan,
    SyncTarget.lexue => l10n.syncActionLexue,
    SyncTarget.eclass => l10n.syncActionEclass,
    SyncTarget.mooc => l10n.syncActionMooc,
    SyncTarget.physicsLab => l10n.syncActionPhysicsLab,
  };
}

String localizedWencuiWing(AppLocalizations l10n, WencuiWing wing) =>
    l10n.wencuiWing(wing.letter);

String localizedWencuiPlace(AppLocalizations l10n, WencuiPlace place) =>
    place.room == null ? localizedWencuiWing(l10n, place.wing) : place.label;

String localizedWencuiWingFloor(
  AppLocalizations l10n,
  WencuiWing wing,
  int floor,
) => l10n.wencuiWingFloor(localizedWencuiWing(l10n, wing), floor);

String localizedWencuiWingFloorRange(AppLocalizations l10n, WencuiWing wing) =>
    l10n.wencuiWingFloorRange(
      localizedWencuiWing(l10n, wing),
      wing.firstFloor,
      wing.lastFloor,
    );

String localizedWencuiFeatureLabel(
  AppLocalizations l10n,
  WencuiFeature feature,
) => switch (feature.kind) {
  WencuiFeatureKind.room => feature.label,
  WencuiFeatureKind.stairs => l10n.stairs,
  WencuiFeatureKind.lift => l10n.lift,
  WencuiFeatureKind.entrance => l10n.firstFloorEntrance,
  WencuiFeatureKind.restroom => switch (feature.restroomGender) {
    WencuiRestroomGender.male => l10n.maleRestroom,
    WencuiRestroomGender.female => l10n.femaleRestroom,
    WencuiRestroomGender.both || null => l10n.restroom,
  },
};

String localizedWencuiFeatureTitle(
  AppLocalizations l10n,
  WencuiFeature feature,
) {
  final label = localizedWencuiFeatureLabel(l10n, feature);
  if (feature.wing case final wing?) {
    return l10n.wencuiFeatureLocation(localizedWencuiWing(l10n, wing), label);
  }
  return l10n.wencuiFeatureLocation(l10n.currentFloor(feature.floor), label);
}

String localizedMoocFailure(AppLocalizations l10n, MoocFailure failure) =>
    switch (failure.issue) {
      MoocIssue.loginExpired => l10n.moocLoginExpired,
      MoocIssue.noSession => l10n.moocNoSession,
      MoocIssue.readAccountFailed => l10n.moocReadAccountFailed,
      MoocIssue.requestBusy => l10n.moocRequestBusy,
      MoocIssue.saveResultFailed => l10n.moocSaveResultFailed,
      null => failure.message ?? failure.toString(),
    };
