import 'package:flutter/material.dart';

import '../../agenda/ui/agenda_reminder.dart';
import '../../app/controller.dart';
import '../../app/ui/add_menu.dart';
import '../../l10n/l10n.dart';
import '../../sync/ui/sync.dart';
import '../../sync/ui/sync_button.dart';
import '../../ui/app_page.dart';
import '../../ui/design.dart';
import '../../ui/sheet_layout.dart';
import '../model.dart';
import 'course_detail.dart';
import 'course_editor.dart';
import 'schedule_menu.dart';
import 'week_pager.dart';
import 'week_selector.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.now,
    this.active = true,
  });

  final AppController controller;
  final DateTime now;
  final bool active;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      controller,
      controller.timetable,
      controller.agenda,
      controller.school,
    ]),
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final l10n = context.l10n;
    final schedule = controller.timetable.schedule;
    final currentSemester = semesterAt(controller.timetable.schedules, now);
    final currentWeek = currentSemester?.term == schedule?.term
        ? currentSemester?.weekAt(now)
        : null;
    final selectedDate =
        schedule != null && schedule.weekAt(now) != controller.timetable.week
        ? schedule
              .mondayAt(controller.timetable.week)
              .add(const Duration(hours: 9))
        : now;

    return AppPage(
      title: schedule == null
          ? Text(l10n.homeTitle)
          : LayoutBuilder(
              builder: (context, constraints) {
                final selector = WeekSelector(controller: controller);
                final compact =
                    constraints.maxWidth <
                    MediaQuery.textScalerOf(context).scale(200);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: selector),
                    if (currentWeek != null &&
                        controller.timetable.week != currentWeek)
                      if (compact)
                        IconButton(
                          tooltip: l10n.backToThisWeek,
                          onPressed: () =>
                              controller.timetable.selectWeek(currentWeek),
                          icon: const Icon(Icons.today_outlined, size: 20),
                        )
                      else
                        TextButton(
                          onPressed: () =>
                              controller.timetable.selectWeek(currentWeek),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: Text(l10n.backToThisWeek),
                        ),
                  ],
                );
              },
            ),
      actions: [
        AddButton(controller: controller, date: selectedDate),
        SyncButton(controller: controller),
        ScheduleMenu(controller: controller),
      ],
      child: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!controller.ready)
                const LinearProgressIndicator(minHeight: 3),
              Expanded(
                child: schedule == null
                    ? Center(
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [
                            FilledButton.icon(
                              onPressed: controller.timetable.busy
                                  ? null
                                  : () => startSync(context, controller),
                              icon: const Icon(Icons.input_rounded, size: 20),
                              label: Text(l10n.syncAll),
                            ),
                            OutlinedButton.icon(
                              onPressed: controller.timetable.busy
                                  ? null
                                  : () => editCourse(context, controller),
                              icon: const Icon(Icons.add_rounded, size: 20),
                              label: Text(l10n.addCourse),
                            ),
                          ],
                        ),
                      )
                    : WeekPager(
                        key: ValueKey((
                          schedule.term,
                          schedule.firstMonday,
                          controller.timetable.weeks.first,
                          controller.timetable.weeks.last,
                        )),
                        controller: controller,
                        active: active,
                      ),
              ),
              if (schedule != null &&
                  schedule.courses.any((course) => !course.isScheduled))
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _unscheduled(context),
                    child: Text(l10n.timedCourses),
                  ),
                ),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: AgendaReminder(
                  controller: controller,
                  entries: controller.agenda.ready
                      ? controller.agenda.pendingOn(now, now: now)
                      : const [],
                  now: now,
                  active: active,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _unscheduled(BuildContext context) => showAppSheet<void>(
    context: context,
    builder: (sheetContext) => SheetLayout(
      header: SheetHeader(
        title: Text(sheetContext.l10n.timedCourses),
        actions: const [SheetCloseButton()],
      ),
      contentPadding: appSheetListPadding,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final course in controller.timetable.schedule!.courses.where(
            (course) => !course.isScheduled,
          ))
            ListTile(
              key: ValueKey(course.id),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
              ),
              title: Text(
                course.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(sheetContext);
                showCourse(context, controller, course);
              },
            ),
        ],
      ),
    ),
  );
}
