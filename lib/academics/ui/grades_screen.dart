import 'package:flutter/material.dart';

import '../../app/controller.dart';
import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../sync/controller.dart';
import '../../sync/ui/sync.dart';
import '../../ui/app_dropdown_field.dart';
import '../model.dart';
import 'academic_common.dart';
import 'credit_progress_screen.dart';
import 'grade_detail.dart';

class GradesScreen extends StatefulWidget {
  const GradesScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  String? _term;
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
      final terms = record.grades.map((grade) => grade.term).toSet().toList()
        ..sort((a, b) => b.compareTo(a));
      final term = terms.contains(_term) ? _term : null;
      final grades =
          record.grades
              .where((grade) => term == null || grade.term == term)
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
      final stats = AcademicStats(grades);
      final l10n = context.l10n;
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
            AppDropdownField<String?>(
              label: l10n.settingsTerm,
              value: term,
              entries: [
                DropdownMenuEntry(value: null, label: l10n.allSemesters),
                for (final value in terms)
                  DropdownMenuEntry(value: value, label: value),
              ],
              onChanged: (value) => setState(() {
                _term = value;
                _onlyFailed = false;
              }),
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
              ],
            ),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(l10n.courseGrades)),
                ButtonSegment(value: true, label: Text(l10n.termPerformance)),
              ],
              selected: {_byTerm},
              showSelectedIcon: false,
              onSelectionChanged: (value) =>
                  setState(() => _byTerm = value.first),
            ),
            const SizedBox(height: 12),
            if (_byTerm)
              for (final value in terms.where(
                (value) => term == null || value == term,
              ))
                _TermPerformance(
                  term: value,
                  stats: AcademicStats(
                    record.grades.where((grade) => grade.term == value),
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
                        : term == null
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
                  child: Text(l10n.noGradesThisTerm),
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
