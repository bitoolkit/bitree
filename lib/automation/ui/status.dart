import '../../l10n/l10n.dart';
import '../controller.dart';

/// One-line summary of the active display rules for the settings entry.
String displayRulesSummary(
  AutomationController controller,
  AppLocalizations l10n,
) {
  if (controller.error != null) return l10n.automationFailedSummary;
  final rules = controller.rules;
  final active = [
    if (rules?.courseAliases.isNotEmpty ?? false) l10n.automationCourseAliases,
    if (rules?.hiddenDeadlineSources.isNotEmpty ?? false)
      l10n.automationHideSources,
    if (rules?.examTitlePrefix.isNotEmpty ?? false) l10n.automationExamPrefix,
    if (controller.scriptEnabled) l10n.automationCustomScript,
  ];
  return active.isEmpty
      ? l10n.automationNotSet
      : active.join(l10n.listSeparator);
}

/// Result of the last run, shown while editing a script.
String automationStatusText(
  AutomationController controller,
  AppLocalizations l10n,
) {
  final duration = controller.executionDuration;
  if (controller.running || duration == null) return l10n.automationRunning;
  final changes = controller.changes;
  final summary = [
    if (changes.added > 0) l10n.automationAdded(changes.added),
    if (changes.deleted > 0) l10n.automationDeleted(changes.deleted),
    if (changes.modified > 0) l10n.automationModified(changes.modified),
  ].join(' ');
  return l10n.automationApplied(
    (duration.inMicroseconds / 1000).toStringAsFixed(1),
    summary.isEmpty ? l10n.automationUnchanged : summary,
  );
}
