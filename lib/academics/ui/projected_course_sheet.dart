import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../schedule/model.dart';
import '../../ui/app_dropdown_field.dart';
import '../../ui/design.dart';
import '../../ui/editor_sheet.dart';
import '../../ui/sheet_layout.dart';
import '../model.dart';

Future<ProjectedCourse?> showProjectedCourseSheet(
  BuildContext context, {
  required List<CourseGrade> grades,
  required Iterable<Course> courses,
  ProjectedCourse? course,
}) => showAppSheet<ProjectedCourse>(
  context: context,
  builder: (_) =>
      _ProjectedCourseSheet(grades: grades, courses: courses, course: course),
);

class _ProjectedCourseSheet extends StatefulWidget {
  const _ProjectedCourseSheet({
    required this.grades,
    required this.courses,
    this.course,
  });
  final List<CourseGrade> grades;
  final Iterable<Course> courses;
  final ProjectedCourse? course;

  @override
  State<_ProjectedCourseSheet> createState() => _ProjectedCourseSheetState();
}

class _ProjectedCourseSheetState extends State<_ProjectedCourseSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.course?.name);
  late final _credits = TextEditingController(
    text: widget.course == null ? '' : creditText(widget.course!.credits),
  );
  late final _score = TextEditingController(
    text: creditText(widget.course?.score ?? 85),
  );
  late String? _selection = widget.course?.replaces;

  @override
  void dispose() {
    _name.dispose();
    _credits.dispose();
    _score.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final course = widget.course;
    final choices =
        <String, ({String name, double? credits, String? replaces})>{
          for (final grade in highestGrades(widget.grades))
            grade.courseKey: (
              name: grade.name,
              credits: grade.credits,
              replaces: grade.courseKey,
            ),
        };
    for (final course in widget.courses) {
      final key = course.number.isEmpty ? course.name : course.number;
      choices.putIfAbsent(
        key,
        () => (name: course.name, credits: null, replaces: null),
      );
    }
    Navigator.pop(
      context,
      ProjectedCourse(
        id: course?.id ?? 'simulation-${DateTime.now().microsecondsSinceEpoch}',
        name: _name.text.trim(),
        credits: double.parse(_credits.text),
        score: double.parse(_score.text),
        replaces: choices[_selection]?.replaces,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final choices =
        <String, ({String name, double? credits, String? replaces})>{
          for (final grade in highestGrades(widget.grades))
            grade.courseKey: (
              name: grade.name,
              credits: grade.credits,
              replaces: grade.courseKey,
            ),
        };
    for (final course in widget.courses) {
      final key = course.number.isEmpty ? course.name : course.number;
      choices.putIfAbsent(
        key,
        () => (name: course.name, credits: null, replaces: null),
      );
    }
    return EditorSheet(
      title: widget.course == null
          ? l10n.addProjectedCourse
          : l10n.editProjectedCourse,
      formKey: _form,
      saving: false,
      onSave: _save,
      saveLabel: Text(l10n.save),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (choices.isNotEmpty) ...[
            AppDropdownField<String?>(
              label: l10n.selectCourseOptional,
              value: choices.containsKey(_selection) ? _selection : null,
              entries: [
                DropdownMenuEntry(value: null, label: l10n.manualEntry),
                for (final choice in choices.entries)
                  DropdownMenuEntry(
                    value: choice.key,
                    label: choice.value.replaces == null
                        ? choice.value.name
                        : l10n.retakeSuffix(choice.value.name),
                  ),
              ],
              onChanged: (key) {
                setState(() {
                  final choice = choices[key];
                  _selection = key;
                  if (choice != null) {
                    _name.text = choice.name;
                    _credits.text = choice.credits == null
                        ? ''
                        : creditText(choice.credits!);
                  }
                });
              },
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          TextFormField(
            controller: _name,
            decoration: InputDecoration(labelText: l10n.courseName),
            validator: (value) => value == null || value.trim().isEmpty
                ? l10n.enterCourseName
                : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _credits,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l10n.courseCredits),
            validator: (text) {
              final value = double.tryParse(text ?? '');
              return value == null || !value.isFinite || value <= 0
                  ? l10n.enterPositiveCredits
                  : null;
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _score,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l10n.expectedScore),
            validator: (text) {
              final value = double.tryParse(text ?? '');
              return value == null ||
                      !value.isFinite ||
                      value < 0 ||
                      value > 100
                  ? l10n.enterScoreRange
                  : null;
            },
          ),
        ],
      ),
    );
  }
}
