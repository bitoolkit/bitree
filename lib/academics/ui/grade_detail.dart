import 'package:flutter/material.dart';

import '../../app/controller.dart';
import '../../l10n/l10n.dart';
import '../../ui/app_dropdown_field.dart';
import '../../ui/design.dart';
import '../../ui/sheet_layout.dart';
import '../model.dart';
import 'grade_simulation_screen.dart';

Future<void> showGradeDetails(
  BuildContext pageContext,
  AppController controller,
  CourseGrade grade,
) => showModalBottomSheet<void>(
  context: pageContext,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (context) => ListenableBuilder(
    listenable: controller.academics,
    builder: (context, _) {
      final l10n = context.l10n;
      return SafeArea(
        top: false,
        child: SheetLayout(
          header: SheetHeader(
            title: Text(l10n.courseGradeTitle),
            actions: const [SheetCloseButton()],
          ),
          content: Padding(
            padding: appSheetContentPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SelectableText(
                  grade.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(grade.term, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 20),
                Text(
                  grade.result,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: grade.failed
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                for (final item in [
                  (l10n.courseNumber, grade.number),
                  (l10n.courseCredits, l10n.credits(creditText(grade.credits))),
                  (l10n.courseAttribute, grade.attribute),
                  (l10n.courseCategory, grade.category),
                  (l10n.examType, grade.examType),
                  (
                    l10n.courseGpa,
                    grade.countsForGpa
                        ? grade.points!.toStringAsFixed(1)
                        : l10n.notCounted,
                  ),
                ])
                  if (item.$2.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 112,
                            child: Text(
                              item.$1,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          Expanded(child: SelectableText(item.$2)),
                        ],
                      ),
                    ),
                const SizedBox(height: 16),
                AppDropdownField<String>(
                  label: l10n.creditReviewCategory,
                  value: controller.academics.record.categoryOf(grade),
                  entries: [
                    for (final category in {
                      controller.academics.record.categoryOf(grade),
                      ...controller.academics.record.categoryTargets.keys,
                      for (final course in controller.academics.record.grades)
                        controller.academics.record.categoryOf(course),
                    })
                      DropdownMenuEntry(value: category, label: category),
                  ],
                  onChanged: controller.academics.busy
                      ? null
                      : (category) {
                          final record = controller.academics.record;
                          final overrides = {
                            ...record.categoryOverrides,
                            grade.courseKey: category,
                          };
                          controller.academics.save(
                            record.copyWith(categoryOverrides: overrides),
                          );
                        },
                ),
              ],
            ),
          ),
          actions: Padding(
            padding: appSheetActionPadding,
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    pageContext,
                    MaterialPageRoute<void>(
                      builder: (_) => GradeSimulationScreen(
                        controller: controller,
                        retake: grade,
                      ),
                    ),
                  );
                },
                child: Text(l10n.simulateRetake),
              ),
            ),
          ),
        ),
      );
    },
  ),
);
