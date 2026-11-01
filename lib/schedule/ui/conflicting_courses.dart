import 'dart:math' as math;

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
    final firstSection = courses
        .map((course) => course.startSection!)
        .reduce(math.min);
    final lastSection = courses
        .map((course) => course.endSection!)
        .reduce(math.max);
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
            color: Colors.transparent,
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
                  final showCount = constraints.maxHeight >= 32;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 2,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showCount) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 11,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 1),
                              Flexible(
                                child: Text(
                                  l10n.courseOverlapCount(courses.length),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 9,
                                    height: 1,
                                    fontWeight: FontWeight.w700,
                                    color: scheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                        ],
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              const rowHeight = 20.0;
                              final positionsAtStart =
                                  constraints.maxHeight >=
                                  courses.length * (rowHeight + 1);
                              if (!positionsAtStart) {
                                return Column(
                                  children: [
                                    for (final course in courses)
                                      Expanded(
                                        child: _ConflictCourseRow(
                                          course: course,
                                          section: localizedCourseSection(
                                            l10n,
                                            course,
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              }

                              final span = lastSection - firstSection + 1;
                              final sorted = [...courses]
                                ..sort((first, second) {
                                  final section = first.startSection!.compareTo(
                                    second.startSection!,
                                  );
                                  return section != 0
                                      ? section
                                      : first.name.compareTo(second.name);
                                });
                              final rows = <Widget>[];
                              var nextTop = 0.0;
                              for (final course in sorted) {
                                final offset =
                                    course.startSection! - firstSection;
                                final proposed =
                                    offset / span * constraints.maxHeight;
                                final top = math
                                    .max(proposed, nextTop)
                                    .clamp(
                                      0.0,
                                      constraints.maxHeight - rowHeight,
                                    )
                                    .toDouble();
                                nextTop = top + rowHeight + 1;
                                rows.add(
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    top: top,
                                    height: rowHeight,
                                    child: _ConflictCourseRow(
                                      course: course,
                                      section: localizedCourseSection(
                                        l10n,
                                        course,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return Stack(children: rows);
                            },
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

class _ConflictCourseRow extends StatelessWidget {
  const _ConflictCourseRow({required this.course, required this.section});

  final Course course;
  final String section;

  @override
  Widget build(BuildContext context) {
    final colors = courseColors(context, course);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.fill,
        borderRadius: BorderRadius.circular(3),
        border: Border(left: BorderSide(color: colors.accent, width: 2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                course.name,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 9,
                  height: 1.05,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                section,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 8,
                  height: 1,
                  color: colors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
