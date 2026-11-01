import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/controller.dart';
import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../ui/app_dialog.dart';
import '../../ui/app_notice.dart';
import '../../ui/campus_time_builder.dart';
import '../../ui/design.dart';
import '../../ui/sheet_layout.dart';
import '../../ui/theme.dart';
import '../../wencui/place.dart';
import '../../wencui/ui/location_card.dart';
import '../../wencui/ui/wencui_map_screen.dart';
import '../building_palette.dart';
import '../model.dart';
import '../selection.dart';
import 'course_editor.dart';

Future<void> showCourse(
  BuildContext context,
  AppController controller,
  Course course, {
  DateTime? date,
}) {
  var selected = course;
  final schedule = controller.timetable.schedule;
  final occurrence =
      date ??
      (schedule != null && course.weekday != null
          ? schedule
                .mondayAt(controller.timetable.week)
                .add(Duration(days: course.weekday! - 1))
          : null);
  return showAppSheet<void>(
    context: context,
    builder: (sheetContext) => StatefulBuilder(
      builder: (_, selectCourse) => CampusTimeBuilder(
        active: true,
        builder: (_, now) => ListenableBuilder(
          listenable: controller.timetable,
          builder: (_, _) => _CourseDetails(
            controller: controller,
            course: selected,
            date: occurrence,
            now: now,
            onNext: (next) => selectCourse(() => selected = next),
            onMap:
                WencuiPlace.parse(selected.room, campus: selected.campus) ==
                    null
                ? null
                : () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => WencuiMapScreen(
                          controller: controller,
                          initialCourse: selected,
                          initialOverview: true,
                        ),
                      ),
                    );
                  },
            onEdit: () {
              Navigator.pop(sheetContext);
              editCourse(context, controller, course: selected);
            },
          ),
        ),
      ),
    ),
  );
}

class _CourseDetails extends StatelessWidget {
  const _CourseDetails({
    required this.controller,
    required this.course,
    required this.onEdit,
    required this.onMap,
    required this.date,
    required this.now,
    required this.onNext,
  });

  final AppController controller;
  final Course course;
  final VoidCallback onEdit;
  final VoidCallback? onMap;
  final DateTime? date;
  final DateTime now;
  final ValueChanged<Course> onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = courseColors(context, course);
    final occurrence = date != null && course.startSection != null
        ? TimetableSelection(
            date: date!,
            startSection: course.startSection!,
            endSection: course.endSection!,
          )
        : null;
    final progress = occurrence?.progressAt(now);
    final status = progress != null
        ? l10n.courseOngoingUntil(sectionTimes[course.endSection! - 1].$2)
        : occurrence != null && !now.isBefore(occurrence.endsAt)
        ? l10n.ended
        : l10n.course;
    final schedule = controller.timetable.schedule;
    final next = date == null || course.endSection == null || schedule == null
        ? null
        : schedule
              .coursesAt(schedule.weekAt(date!), weekday: date!.weekday)
              .where((item) => item.startSection! > course.endSection!)
              .firstOrNull;
    final location = [
      course.campus,
      course.room,
    ].where((part) => part.isNotEmpty).join(' ');

    Widget detail(IconData icon, String text, {String? secondary}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(text, style: theme.textTheme.bodyLarge),
                if (secondary != null) ...[
                  const SizedBox(height: 2),
                  SelectableText(
                    secondary,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return SheetLayout(
      key: ValueKey(course.id),
      header: SheetHeader(
        title: Row(
          children: [
            Icon(
              Icons.school_outlined,
              size: 18,
              color: progress != null
                  ? colors.accent
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                status,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: progress != null
                      ? colors.accent
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        actions: [SheetCloseButton(enabled: !controller.timetable.busy)],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CopyableCourseName(name: course.name),
          detail(
            Icons.schedule_outlined,
            localizedCourseTime(l10n, course),
            secondary:
                '${course.weekday == null ? '' : '${localizedWeekday(l10n, course.weekday!)} · '}'
                '${localizedCourseSection(l10n, course)} · '
                '${localizedWeeks(l10n, course.weeks)}',
          ),
          if (onMap case final openMap?)
            WencuiLocationCard(
              place: WencuiPlace.parse(course.room, campus: course.campus)!,
              onTap: openMap,
            )
          else
            detail(
              Icons.place_outlined,
              location.isEmpty ? l10n.locationPending : location,
            ),
          if (course.teacher.isNotEmpty)
            detail(Icons.person_outline, course.teacher),
          if (course.number.isNotEmpty) detail(Icons.tag, course.number),
          if (course.description.isNotEmpty)
            detail(Icons.notes_rounded, course.description),
          if (progress != null) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              borderRadius: BorderRadius.circular(2),
              color: colors.accent,
              backgroundColor: colors.fill,
            ),
            const SizedBox(height: 6),
            Text(
              l10n.minutesUntilEnd(
                (occurrence!.endsAt.difference(now).inSeconds / 60).ceil(),
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (next != null)
            _NextCourse(course: course, next: next, onTap: () => onNext(next)),
        ],
      ),
      actions: Row(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: controller.timetable.busy ? null : onEdit,
              child: Text(l10n.courseEditorEditTitle),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(
                color: theme.colorScheme.error.withValues(alpha: 0.4),
              ),
            ),
            onPressed: controller.timetable.busy
                ? null
                : () => _deleteCourse(context, controller, course),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}

class _NextCourse extends StatelessWidget {
  const _NextCourse({
    required this.course,
    required this.next,
    required this.onTap,
  });

  final Course course;
  final Course next;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final from = matchCampusBuilding(course.room, campus: course.campus);
    final to = matchCampusBuilding(next.room, campus: next.campus);
    final relation = from == null || to == null
        ? null
        : from == to
        ? l10n.sameBuilding
        : from.area == to.area
        ? l10n.sameArea
        : l10n.differentArea;
    Widget building(Course course, BuildingPalette place) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: courseColors(context, course).accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(child: Text(place.name)),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(l10n.courseNext, style: theme.textTheme.bodySmall),
              if (relation != null)
                Text(relation, style: theme.textTheme.labelMedium),
            ],
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: AppCorners.control,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(next.name, style: theme.textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(
                            '${localizedCourseTime(l10n, next)}${next.room.isEmpty ? '' : ' · ${next.room}'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right_rounded, size: 20),
                  ],
                ),
              ),
            ),
          ),
          if (from != null && to != null && from != to)
            DefaultTextStyle.merge(
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  building(course, from),
                  const Icon(Icons.arrow_forward_rounded, size: 14),
                  building(next, to),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CopyableCourseName extends StatelessWidget {
  const _CopyableCourseName({required this.name});

  final String name;

  Future<void> _copy(BuildContext context) async {
    final l10n = context.l10n;
    String message;
    try {
      await Clipboard.setData(ClipboardData(text: name));
      message = l10n.copyCourseNameSuccess;
    } on PlatformException {
      message = l10n.copyCourseNameFailure;
    }
    if (context.mounted) showAppNotice(context, message);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onLongPress: () => _copy(context),
    child: Text(name, style: Theme.of(context).textTheme.titleLarge),
  );
}

Future<void> _deleteCourse(
  BuildContext context,
  AppController controller,
  Course course,
) async {
  final l10n = context.l10n;
  final confirmed = await showAppConfirmDialog(
    context,
    title: l10n.deleteCourseQuestion,
    body: l10n.deleteCourseBody(course.name),
    confirmLabel: l10n.deleteCourse,
    destructive: true,
  );
  if (!confirmed || !context.mounted) return;

  final success = await controller.timetable.deleteCourse(course);
  if (!context.mounted) return;

  if (success) {
    Navigator.pop(context);
  }
}
