import 'package:flutter/material.dart';

import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../ui/design.dart';
import '../../ui/sheet_layout.dart';
import '../controller.dart';
import '../model.dart';
import 'course_colors.dart';
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
  final TimetableController controller;
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
        child: Material(
          color: scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: AppCorners.compact,
            side: BorderSide(
              color: isToday ? scheme.primary : scheme.outlineVariant,
              width: isToday ? 1.5 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _selectCourse(context),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final scale = MediaQuery.textScalerOf(context).scale(1);
                if (constraints.maxHeight < courses.length * 12 * scale ||
                    constraints.maxWidth < 20) {
                  return Tooltip(
                    message: summary,
                    child:
                        constraints.maxHeight < 10 || constraints.maxWidth < 10
                        ? const SizedBox.expand()
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Text(
                                l10n.courseOverlapCount(courses.length),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                          ),
                  );
                }
                final showHeader =
                    constraints.maxWidth >= 24 &&
                    constraints.maxHeight >= 30 * scale &&
                    constraints.maxHeight >=
                        18 * scale + courses.length * 12 * scale;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showHeader)
                      ColoredBox(
                        color: isToday
                            ? scheme.primaryContainer
                            : scheme.surfaceContainer,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(4, 3, 4, 3),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 11,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  l10n.courseOverlapCount(courses.length),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 9,
                                    height: 1.1,
                                    fontWeight: FontWeight.w700,
                                    color: isToday
                                        ? scheme.onPrimaryContainer
                                        : scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Expanded(
                      child: Column(
                        children: [
                          for (final (index, course) in courses.indexed) ...[
                            if (index > 0) const SizedBox(height: 1),
                            Expanded(
                              child: _ConflictCourseRow(
                                key: ValueKey('conflict-course-${course.id}'),
                                course: course,
                                section: localizedCourseSection(l10n, course),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ConflictCourseRow extends StatelessWidget {
  const _ConflictCourseRow({
    super.key,
    required this.course,
    required this.section,
  });

  final Course course;
  final String section;

  @override
  Widget build(BuildContext context) {
    final location = course.room.trim();
    final colors = courseColors(context, course);
    return ColoredBox(
      color: colors.fill,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 3, 2),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final inline = constraints.maxWidth >= 88;
            final showDetails = constraints.maxHeight >= (inline ? 25 : 36);
            final name = Text(
              course.name,
              maxLines: inline ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                height: 1.08,
                fontWeight: FontWeight.w600,
                color: colors.text,
              ),
            );
            final locationText = location.isEmpty
                ? null
                : Text(
                    location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 8.5,
                      height: 1.05,
                      color: colors.secondaryText,
                    ),
                  );
            final sectionText = Text(
              section,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 8.5,
                height: 1.05,
                fontWeight: FontWeight.w500,
                color: colors.secondaryText,
              ),
            );
            final details = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                name,
                if (showDetails && locationText != null) ...[
                  const SizedBox(height: 1),
                  locationText,
                ],
              ],
            );
            final content = inline
                ? Row(
                    children: [
                      Expanded(child: details),
                      if (showDetails) ...[
                        const SizedBox(width: 3),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 72),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.text.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                                vertical: 1,
                              ),
                              child: sectionText,
                            ),
                          ),
                        ),
                      ],
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      details,
                      if (showDetails) ...[
                        const SizedBox(height: 1),
                        sectionText,
                      ],
                    ],
                  );
            return Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: SizedBox(width: constraints.maxWidth, child: content),
              ),
            );
          },
        ),
      ),
    );
  }
}
