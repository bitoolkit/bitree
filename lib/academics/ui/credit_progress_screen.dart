import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/controller.dart';
import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../sync/controller.dart';
import '../../sync/ui/sync.dart';
import '../model.dart';
import 'academic_common.dart';
import 'credit_targets_sheet.dart';
import 'grade_detail.dart';

class CreditProgressScreen extends StatelessWidget {
  const CreditProgressScreen({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller.academics, controller.school]),
    builder: (context, _) {
      final record = controller.academics.record;
      final plan = record.plan;
      final stats = record.stats;
      final earned =
          plan?.completedCredits ??
          (record.gradesUpdatedAt == null ? null : stats.earnedCredits);
      final target = record.targetCredits ?? plan?.requiredCredits;
      final categories = {
        ...record.categoryTargets.keys,
        for (final grade in stats.courses) record.categoryOf(grade),
      }.toList()..sort();
      final theme = Theme.of(context);
      final l10n = context.l10n;
      return AcademicPage(
        title: l10n.creditProgressTitle,
        loading: controller.school.busy || controller.academics.busy,
        actions: [
          IconButton(
            tooltip: l10n.reviewCreditTargets,
            onPressed:
                controller.school.username == null || controller.academics.busy
                ? null
                : () => editCreditTargets(context, controller.academics),
            icon: const Icon(Icons.tune_rounded),
          ),
          AcademicImportButton(
            controller: controller,
            action: SyncTarget.studyPlan,
          ),
        ],
        children: [
          if (!controller.academics.ready)
            AcademicEmpty(
              title: l10n.academicReadFailed,
              label: l10n.reload,
              onPressed: () =>
                  controller.academics.load(controller.school.username),
            )
          else if (plan == null && record.gradesUpdatedAt == null)
            AcademicEmpty(
              title: l10n.noCreditRecords,
              label: SyncTarget.studyPlan.localizedAction(l10n),
              onPressed: () => startSync(
                context,
                controller,
                targets: {SyncTarget.studyPlan},
              ),
            )
          else ...[
            if (plan != null)
              Text(
                [
                  plan.year,
                  plan.major,
                ].where((text) => text.isNotEmpty).join('  '),
                style: theme.textTheme.titleMedium,
              ),
            AcademicSummary(
              values: [
                (
                  label: plan?.completedCredits == null
                      ? l10n.creditsFromGrades
                      : l10n.completedCreditsSchool,
                  value: earned == null
                      ? l10n.notAvailable
                      : creditText(earned),
                ),
                (
                  label: record.targetCredits == null
                      ? l10n.schoolRequiredCredits
                      : l10n.reviewTargetCredits,
                  value: target == null
                      ? l10n.notAvailable
                      : creditText(target),
                ),
                (
                  label: l10n.creditsRemaining,
                  value: target == null || earned == null
                      ? '—'
                      : creditText(math.max(0.0, target - earned)),
                ),
              ],
            ),
            if (target != null && target > 0 && earned != null)
              LinearProgressIndicator(
                value: (earned / target).clamp(0, 1).toDouble(),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            const SizedBox(height: 20),
            if (stats.failed
                    .where((grade) => grade.attribute.contains('必修'))
                    .toList()
                case final failed when failed.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.error_outline_rounded,
                  color: theme.colorScheme.error,
                ),
                title: Text(l10n.requiredCoursesPending(failed.length)),
                subtitle: Text(failed.map((grade) => grade.name).join('、')),
                onTap: () =>
                    _showCategory(context, l10n.pendingRequiredCourses, failed),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            Row(
              children: [
                Expanded(child: Text(l10n.reviewByCategory)),
                TextButton(
                  onPressed:
                      controller.school.username == null ||
                          controller.academics.busy
                      ? null
                      : () => editCreditTargets(context, controller.academics),
                  child: Text(l10n.setTargets),
                ),
              ],
            ),
            for (final category in categories)
              _CreditCategoryRow(
                name: category,
                grades: stats.courses
                    .where((grade) => record.categoryOf(grade) == category)
                    .toList(),
                target: record.categoryTargets[category],
                onTap: (grades) => _showCategory(context, category, grades),
              ),
            if (record.gradesUpdatedAt == null)
              TextButton.icon(
                onPressed: () => startSync(
                  context,
                  controller,
                  targets: {SyncTarget.grades},
                ),
                icon: const Icon(Icons.download_rounded),
                label: Text(l10n.syncGradesForCredit),
              ),
            const SizedBox(height: 20),
            Text(l10n.creditCategoryNote, style: theme.textTheme.bodySmall),
            if (record.planUpdatedAt ?? record.gradesUpdatedAt
                case final updatedAt?)
              AcademicUpdatedAt(updatedAt: updatedAt),
          ],
        ],
      );
    },
  );

  void _showCategory(
    BuildContext context,
    String category,
    List<CourseGrade> grades,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => AcademicPage(
          title: category,
          children: [
            if (grades.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(context.l10n.noCategoryGrades),
              ),
            for (final grade in grades)
              GradeListTile(
                grade: grade,
                onTap: () => showGradeDetails(context, controller, grade),
              ),
          ],
        ),
      ),
    );
  }
}

class _CreditCategoryRow extends StatelessWidget {
  const _CreditCategoryRow({
    required this.name,
    required this.grades,
    required this.target,
    required this.onTap,
  });
  final String name;
  final List<CourseGrade> grades;
  final double? target;
  final ValueChanged<List<CourseGrade>> onTap;

  @override
  Widget build(BuildContext context) {
    final earned = AcademicStats(grades).earnedCredits;
    final l10n = context.l10n;
    return InkWell(
      onTap: () => onTap(grades),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(name)),
                Text(
                  target == null
                      ? l10n.credits(creditText(earned))
                      : l10n.creditProgressValue(
                          creditText(earned),
                          creditText(target!),
                        ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, size: 18),
              ],
            ),
            if (target != null && target! > 0) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (earned / target!).clamp(0, 1).toDouble(),
                minHeight: 4,
                borderRadius: BorderRadius.circular(3),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              target == null
                  ? l10n.creditTargetNotSet
                  : l10n.creditsStillNeeded(
                      creditText(math.max(0.0, target! - earned)),
                    ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
