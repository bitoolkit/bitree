import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../ui/design.dart';
import '../../ui/selection_controls.dart';
import '../../ui/sheet_layout.dart';
import '../model.dart';

Future<GradeScope?> showGradeScopeSheet(
  BuildContext context, {
  required AcademicRecord record,
  required GradeScope scope,
}) => showAppSheet<GradeScope>(
  context: context,
  builder: (_) => _GradeScopeSheet(record: record, scope: scope),
);

class _GradeScopeSheet extends StatefulWidget {
  const _GradeScopeSheet({required this.record, required this.scope});

  final AcademicRecord record;
  final GradeScope scope;

  @override
  State<_GradeScopeSheet> createState() => _GradeScopeSheetState();
}

class _GradeScopeSheetState extends State<_GradeScopeSheet> {
  late GradeScope _scope = widget.scope;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Set<String> get _terms => widget.record.grades
      .map((grade) => grade.term)
      .where((term) => term.isNotEmpty)
      .toSet();

  Set<String> get _attributes => widget.record.grades
      .map((grade) => grade.attribute)
      .where((attribute) => attribute.isNotEmpty)
      .toSet();

  Set<String> get _categories =>
      widget.record.grades.map(widget.record.categoryOf).toSet();

  List<CourseGrade> _courseChoices(GradeScope scope) {
    final dimensions = scope.copyWith(courseKeys: const {});
    return highestGrades(
      widget.record.grades.where(
        (grade) => widget.record.matchesScope(grade, dimensions),
      ),
    )..sort((a, b) => a.name.compareTo(b.name));
  }

  void _update(GradeScope next) {
    final availableKeys = {
      for (final grade in _courseChoices(next)) grade.courseKey,
    };
    setState(() {
      _scope = next.copyWith(
        courseKeys: next.courseKeys.intersection(availableKeys),
      );
    });
  }

  Set<String> _toggle(Set<String> values, String value, bool selected) {
    final next = Set<String>.of(values);
    if (selected) {
      next.remove(value);
    } else {
      next.add(value);
    }
    return next;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final search = _search.text.trim().toLowerCase();
    final choices = _courseChoices(_scope)
        .where(
          (grade) =>
              search.isEmpty ||
              grade.name.toLowerCase().contains(search) ||
              grade.number.toLowerCase().contains(search),
        )
        .toList();

    return SheetLayout(
      header: SheetHeader(
        title: Text(l10n.gradeScope),
        actions: const [SheetCloseButton()],
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ChoiceGroup(
            title: l10n.settingsTerm,
            values: _terms,
            selected: _scope.terms,
            onChanged: (terms) => _update(_scope.copyWith(terms: terms)),
          ),
          if (_attributes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            _ChoiceGroup(
              title: l10n.courseAttribute,
              values: _attributes,
              selected: _scope.attributes,
              onChanged: (attributes) =>
                  _update(_scope.copyWith(attributes: attributes)),
            ),
          ],
          if (_categories.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            _ChoiceGroup(
              title: l10n.courseCategory,
              values: _categories,
              selected: _scope.categories,
              onChanged: (categories) =>
                  _update(_scope.copyWith(categories: categories)),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          Text(l10n.course, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const Key('grade-scope-course-search'),
            controller: _search,
            decoration: InputDecoration(
              labelText: l10n.searchCourses,
              prefixIcon: const Icon(Icons.search_rounded),
            ),
            textInputAction: TextInputAction.search,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppSelectionTile(
            key: const Key('grade-scope-all-courses'),
            value: _scope.courseKeys.isEmpty,
            title: Text(l10n.allCourses),
            onChanged: (_) =>
                _update(_scope.copyWith(courseKeys: const <String>{})),
          ),
          for (final grade in choices)
            AppSelectionTile(
              key: ValueKey('grade-scope-course-${grade.courseKey}'),
              value: _scope.courseKeys.contains(grade.courseKey),
              title: Text(grade.name),
              subtitle: Text(
                [
                  grade.term,
                  widget.record.categoryOf(grade),
                ].where((value) => value.isNotEmpty).join(' · '),
              ),
              onChanged: (_) => _update(
                _scope.copyWith(
                  courseKeys: _toggle(
                    _scope.courseKeys,
                    grade.courseKey,
                    _scope.courseKeys.contains(grade.courseKey),
                  ),
                ),
              ),
            ),
          if (choices.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Text(
                search.isEmpty ? l10n.noCoursesInScope : l10n.noMatchingCourses,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
      actions: SheetActionBar.split(
        leading: TextButton(
          onPressed: () => _update(const GradeScope()),
          child: Text(l10n.clearSelection),
        ),
        primary: FilledButton(
          onPressed: () => Navigator.pop(context, _scope),
          child: Text(l10n.apply),
        ),
      ),
    );
  }
}

class _ChoiceGroup extends StatelessWidget {
  const _ChoiceGroup({
    required this.title,
    required this.values,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final Set<String> values;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final values = this.values.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            AppSelectionButton.compact(
              selected: selected.isEmpty,
              onPressed: () => onChanged(const {}),
              child: Text(context.l10n.all),
            ),
            for (final value in values)
              AppSelectionButton.compact(
                selected: selected.contains(value),
                onPressed: () => onChanged(
                  _toggleValue(selected, value, selected.contains(value)),
                ),
                child: Text(value),
              ),
          ],
        ),
      ],
    );
  }

  Set<String> _toggleValue(Set<String> source, String value, bool selected) {
    final next = Set<String>.of(source);
    if (selected) {
      next.remove(value);
    } else {
      next.add(value);
    }
    return next;
  }
}
