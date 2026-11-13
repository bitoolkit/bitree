import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/controller.dart';
import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../sync/controller.dart';
import '../../sync/ui/sync.dart';
import '../../ui/selection_controls.dart';
import '../model.dart';
import 'academic_common.dart';
import 'credit_progress_screen.dart';
import 'grade_detail.dart';
import 'grade_scope_sheet.dart';

class GradesScreen extends StatefulWidget {
  const GradesScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  GradeScope _scope = const GradeScope();
  bool _byTerm = false;
  bool _onlyFailed = false;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.controller.academics,
      widget.controller.school,
    ]),
    builder: (context, _) {
      final controller = widget.controller;
      final record = controller.academics.record;
      final grades =
          record.grades
              .where((grade) => record.matchesScope(grade, _scope))
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
      final stats = AcademicStats(grades);
      final terms = stats.courses.map((course) => course.term).toSet().toList()
        ..sort((a, b) => b.compareTo(a));
      final singleTerm = _scope.terms.length == 1 ? _scope.terms.single : null;
      final scopeFiltered =
          _scope.terms.isNotEmpty ||
          _scope.attributes.isNotEmpty ||
          _scope.categories.isNotEmpty ||
          _scope.courseKeys.isNotEmpty;
      final l10n = context.l10n;
      final percentFormat = NumberFormat.percentPattern(
        Localizations.localeOf(context).toString(),
      )..maximumFractionDigits = 1;
      final atLeast80 = stats.coursesAtLeast80Ratio == null
          ? '—'
          : percentFormat.format(stats.coursesAtLeast80Ratio);
      return AcademicPage(
        title: l10n.gradesAndAcademics,
        loading: controller.school.busy,
        actions: [
          IconButton(
            tooltip: l10n.gpaRules,
            onPressed: () => showGpaRules(context),
            icon: const Icon(Icons.help_outline_rounded),
          ),
          AcademicImportButton(
            controller: controller,
            action: SyncTarget.grades,
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
          else if (record.gradesUpdatedAt == null)
            AcademicEmpty(
              title: l10n.noSyncedGrades,
              label: SyncTarget.grades.localizedAction(l10n),
              onPressed: () =>
                  startSync(context, controller, targets: {SyncTarget.grades}),
            )
          else ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('grade-scope-button'),
                onPressed: () async {
                  final scope = await showGradeScopeSheet(
                    context,
                    record: record,
                    scope: _scope,
                  );
                  if (scope == null || !mounted) return;
                  setState(() {
                    _scope = scope;
                    _onlyFailed = false;
                  });
                },
                icon: const Icon(Icons.tune_rounded),
                label: Text(
                  scopeFiltered ? l10n.gradeScopeFiltered : l10n.gradeScope,
                ),
              ),
            ),
            AcademicSummary(
              values: [
                (
                  label: l10n.averageGpa,
                  value: stats.gpa?.toStringAsFixed(2) ?? '—',
                ),
                (
                  label: l10n.weightedAverageScore,
                  value: stats.averageScore?.toStringAsFixed(1) ?? '—',
                ),
                (
                  label: l10n.earnedCredits,
                  value: creditText(stats.earnedCredits),
                ),
                (
                  label: l10n.scoredCourses,
                  value: l10n.courseCount(stats.scoredCourseCount),
                ),
                (
                  label: l10n.coursesAtLeast80,
                  value: l10n.courseCount(stats.coursesAtLeast80),
                ),
                (label: l10n.atLeast80Ratio, value: atLeast80),
              ],
            ),
            AppSegmentedControl<bool>(
              options: {false: l10n.courseGrades, true: l10n.termPerformance},
              value: _byTerm,
              onChanged: (value) => setState(() => _byTerm = value),
            ),
            const SizedBox(height: 12),
            if (_byTerm)
              for (final value in terms)
                _TermPerformance(
                  term: value,
                  stats: AcademicStats(
                    grades.where((grade) => grade.term == value),
                  ),
                )
            else ...[
              if (stats.failed.isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.error_outline_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    _onlyFailed
                        ? l10n.onlyFailedCourses
                        : singleTerm == null
                        ? l10n.coursesNotPassed(stats.failed.length)
                        : l10n.termCoursesNotPassed(stats.failed.length),
                  ),
                  trailing: Text(_onlyFailed ? l10n.showAll : l10n.view),
                  onTap: () => setState(() => _onlyFailed = !_onlyFailed),
                ),
              for (final grade in _onlyFailed ? stats.failed : grades)
                GradeListTile(
                  grade: grade,
                  onTap: () => showGradeDetails(context, controller, grade),
                ),
              if (grades.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l10n.noCoursesInScope),
                ),
            ],
            const Divider(height: 32),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.creditProgress),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => CreditProgressScreen(controller: controller),
                ),
              ),
            ),
            if (record.gradesUpdatedAt case final updatedAt?)
              AcademicUpdatedAt(updatedAt: updatedAt),
          ],
        ],
      );
    },
  );
}

class _TermPerformance extends StatelessWidget {
  const _TermPerformance({required this.term, required this.stats});
  final String term;
  final AcademicStats stats;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(term)),
            Text(stats.gpa?.toStringAsFixed(2) ?? '—'),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: (stats.gpa ?? 0) / 4,
          minHeight: 5,
          borderRadius: BorderRadius.circular(3),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.weightedAverageValue(
            stats.averageScore?.toStringAsFixed(1) ?? '—',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}
