import '../../l10n/app_localizations.dart';
import '../../l10n/formats.dart';
import '../../mooc/progress.dart';
import '../controller.dart';

String syncProgressText(
  AppLocalizations l10n,
  SyncController controller,
  SyncTarget target,
) {
  if (controller.results[target] case final result?) {
    return _syncResultText(l10n, result, target);
  }
  if (controller.isRunning(target)) {
    if (controller.cancelled) return l10n.cancelling;
    if (target == SyncTarget.mooc) {
      final progress = switch (controller.moocProgress) {
        MoocCourseListProgress(:final isSpoc) =>
          isSpoc ? l10n.moocReadingSpocCourses : l10n.moocReadingCourses,
        MoocCourseReadProgress(:final index, :final total, :final course) =>
          l10n.moocReadingCourse(index, total, course),
        null => null,
      };
      if (progress != null) return progress;
    }
    return l10n.syncing;
  }
  return target.usesSchoolSession && controller.waitingForSchool
      ? l10n.waitingForSchool
      : l10n.waitingToSync;
}

String _syncResultText(
  AppLocalizations l10n,
  SyncResult result,
  SyncTarget target,
) {
  final detail = result.detail?.trim();
  return switch (result.outcome) {
    SyncOutcome.synced => switch (result.count) {
      null => l10n.synced,
      final count when target == SyncTarget.physicsLab => l10n.updatedDdlCount(
        count,
      ),
      final count => l10n.syncedDdlCount(count),
    },
    SyncOutcome.failed => [
      if (result.count case final count? when count > 0)
        target == SyncTarget.physicsLab
            ? l10n.updatedDdlCount(count)
            : l10n.syncedDdlCount(count),
      if (detail != null && detail.isNotEmpty)
        localizedKnownError(l10n, detail) ?? detail
      else
        l10n.syncNotFinished,
    ].join('\n'),
    SyncOutcome.needsLogin =>
      target == SyncTarget.mooc
          ? l10n.moocLoginRequired
          : l10n.schoolLoginRequired,
    SyncOutcome.needsVerification => l10n.syncVerificationRequired,
    SyncOutcome.cancelled => l10n.cancelled,
    SyncOutcome.noSchedule => l10n.noScheduleAvailable,
    SyncOutcome.saveFailed => l10n.physicsLabSaveFailed,
  };
}
