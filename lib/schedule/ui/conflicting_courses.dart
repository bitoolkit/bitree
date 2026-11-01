import 'package:flutter/material.dart';

import '../../app/controller.dart';
import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../ui/design.dart';
import '../../ui/sheet_layout.dart';
import '../../ui/theme.dart';
import '../model.dart';
import 'course_detail.dart';

class ConflictingCourses extends StatelessWidget {
  const ConflictingCourses({
    super.key,
    required this.courses,
    required this.controller,
    required this.isToday,
    this.date,
  });

  final List<Course> courses;
  final AppController controller;
  final bool isToday;
  final DateTime? date;

  Future<void> _selectCourse(BuildContext context) async {
    final l10n = context.l10n;
    final selected = await showAppSheet<Course>(
      context: context,
      builder: (context) => SheetLayout(
        header: SheetHeader(
          title: Text(l10n.chooseCourse),
          actions: const [SheetCloseButton()],
        ),
        contentPadding: appSheetListPadding,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final course in courses)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                leading: Container(
                  width: 4,
                  height: 44,
                  decoration: BoxDecoration(
                    color: courseColors(context, course).accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                title: Text(course.name),
                subtitle: Text(
                  [
                    '${localizedCourseSection(l10n, course)} '
                        '(${localizedCourseTime(l10n, course)})',
                    if (course.room.isNotEmpty) course.room,
                    if (course.teacher.isNotEmpty) course.teacher,
                  ].join('\n'),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () => Navigator.pop(context, course),
              ),
          ],
        ),
      ),
    );
    if (selected != null && context.mounted) {
      await showCourse(context, controller, selected, date: date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final fill = isToday
        ? Color.lerp(scheme.primaryContainer, scheme.primary, 0.12)!
        : scheme.primaryContainer;
    final summary = courses
        .map(
          (course) =>
              '${course.name}${l10n.listSeparator}'
              '${localizedCourseSection(l10n, course)}',
        )
        .join('\n');

    return Semantics(
      button: true,
      label: l10n.coursesOverlap(courses.length, summary),
      child: ExcludeSemantics(
        child: Tooltip(
          triggerMode: TooltipTriggerMode.manual,
          message: summary,
          child: Material(
            color: fill,
            shape: RoundedRectangleBorder(
              borderRadius: AppCorners.compact,
              side: isToday
                  ? BorderSide(color: scheme.primary, width: 1.5)
                  : BorderSide.none,
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _selectCourse(context),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final scaler = MediaQuery.textScalerOf(context);
                  final titleHeight = scaler.scale(12) * 1.25;
                  final sectionHeight = scaler.scale(10) * 1.25;
                  final available = constraints.maxHeight - sectionHeight - 12;
                  final showSections =
                      available >= titleHeight + sectionHeight + 3;
                  final sectionSpace = showSections ? sectionHeight + 3 : 0;
                  final shownCount =
                      available >= (titleHeight * 2 + sectionSpace) * 2 + 4
                      ? 2
                      : 1;
                  final titleLines =
                      ((available - (shownCount - 1) * 4) / shownCount -
                          sectionSpace) ~/
                      titleHeight;

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 4,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.courseOverlapCount(courses.length),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i = 0; i < shownCount; i++) ...[
                                if (i > 0) const SizedBox(height: 4),
                                Text(
                                  courses[i].name,
                                  textAlign: TextAlign.center,
                                  maxLines: titleLines.clamp(1, 3),
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.25,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onPrimaryContainer,
                                  ),
                                ),
                                if (showSections) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    localizedCourseSection(l10n, courses[i]),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      height: 1.25,
                                      color: scheme.onPrimaryContainer,
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
