import 'package:flutter/material.dart';

import '../../app/controller.dart';
import '../../l10n/l10n.dart';
import '../../sync/controller.dart';
import '../../ui/app_dialog.dart';
import '../../ui/section_label.dart';
import '../../ui/selection_controls.dart';
import '../model.dart';
import 'academic_common.dart';
import 'projected_course_dialog.dart';

class GradeSimulationScreen extends StatefulWidget {
  const GradeSimulationScreen({
    super.key,
    required this.controller,
    this.retake,
  });
  final AppController controller;
  final CourseGrade? retake;

  @override
  State<GradeSimulationScreen> createState() => _GradeSimulationScreenState();
}

class _GradeSimulationScreenState extends State<GradeSimulationScreen> {
  final _courses = <ProjectedCourse>[];
  final _target = TextEditingController(text: '3.60');
  bool _targetMode = false;
  bool _replaceRetakes = true;

  @override
  void initState() {
    super.initState();
    if (widget.retake case final grade?) {
      _courses.add(
        ProjectedCourse(
          id: 'simulation-retake',
          name: grade.name,
          credits: grade.credits,
          score: 85,
          replaces: grade.courseKey,
        ),
      );
    }
  }

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  Future<void> _edit([ProjectedCourse? course]) async {
    final next = await showDialog<ProjectedCourse>(
      context: context,
      builder: (_) => ProjectedCourseDialog(
        grades: widget.controller.academics.record.grades,
        courses: widget.controller.timetable.schedule?.courses ?? const [],
        course: course,
      ),
    );
    if (next == null || !mounted) return;
    setState(() {
      final index = _courses.indexWhere((item) => item.id == next.id);
      if (index < 0) {
        _courses.add(next);
      } else {
        _courses[index] = next;
      }
    });
  }

  Future<void> _remove(ProjectedCourse course) async {
    final l10n = context.l10n;
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.removeSimulatedCourseQuestion,
      body: course.name,
      confirmLabel: l10n.removeAction,
    );
    if (confirmed && mounted) setState(() => _courses.remove(course));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.controller.academics,
      widget.controller.timetable,
      widget.controller.school,
    ]),
    builder: (context, _) {
      final grades = widget.controller.academics.record.grades;
      final original = AcademicStats(grades);
      final result = projectGrades(
        grades,
        _courses,
        replaceRetakes: _replaceRetakes,
      );
      final target = double.tryParse(_target.text);
      final validTarget =
          target != null && target.isFinite && target >= 0 && target <= 4;
      final needed = validTarget
          ? scoreForTarget(
              grades,
              _courses,
              target: target,
              replaceRetakes: _replaceRetakes,
            )
          : null;
      final theme = Theme.of(context);
      final l10n = context.l10n;
      return AcademicPage(
        title: l10n.gradeSimulation,
        loading: widget.controller.school.busy,
        actions: [
          IconButton(
            tooltip: l10n.gpaRules,
            onPressed: () => showGpaRules(context),
            icon: const Icon(Icons.help_outline_rounded),
          ),
          AcademicImportButton(
            controller: widget.controller,
            action: SyncTarget.grades,
          ),
        ],
        children: [
          Text(
            l10n.currentGpaCredits(
              creditText(original.gpaCredits),
              original.gpa?.toStringAsFixed(2) ?? '—',
            ),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text(l10n.simulateByCourse)),
              ButtonSegment(
                value: true,
                label: Text(l10n.targetBackCalculation),
              ),
            ],
            selected: {_targetMode},
            showSelectedIcon: false,
            onSelectionChanged: (value) =>
                setState(() => _targetMode = value.first),
          ),
          if (_targetMode) ...[
            const SizedBox(height: 20),
            TextField(
              controller: _target,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: l10n.targetCumulativeGpa,
                errorText: validTarget ? null : l10n.enterGpaRange,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _targetMode
                      ? l10n.requiredPerCourse
                      : l10n.projectedCumulativeGpa,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  _courses.isEmpty
                      ? l10n.addSimulatedCourseFirst
                      : _targetMode
                      ? !validTarget
                            ? '—'
                            : needed == null
                            ? l10n.targetUnreachable
                            : l10n.scoreValue('$needed')
                      : result.gpa?.toStringAsFixed(2) ?? '—',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!_targetMode &&
                    result.gpa != null &&
                    original.gpa != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.gpaChange(
                      '${(result.gpa! - original.gpa!) >= 0 ? '+' : ''}'
                      '${(result.gpa! - original.gpa!).toStringAsFixed(2)}',
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          AppSectionHeader(
            l10n.simulatedCourses,
            trailing: TextButton.icon(
              onPressed: _edit,
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.addCourse),
            ),
          ),
          for (final course in _courses)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(course.name),
              subtitle: Text(
                [
                  l10n.credits(creditText(course.credits)),
                  if (course.replaces != null) l10n.retake,
                ].join('  '),
              ),
              onTap: () => _edit(course),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => _edit(course),
                    child: Text(
                      _targetMode
                          ? l10n.editAction
                          : l10n.scoreValue(creditText(course.score)),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.removeSimulatedCourse,
                    onPressed: () => _remove(course),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
            ),
          AppToggleTile(
            title: Text(l10n.retakeUsesHighest),
            value: _replaceRetakes,
            onChanged: (value) => setState(() => _replaceRetakes = value),
          ),
          Text(
            _replaceRetakes
                ? l10n.simulationDoesNotChange
                : l10n.simulationIncludesBoth,
            style: theme.textTheme.bodySmall,
          ),
        ],
      );
    },
  );
}
