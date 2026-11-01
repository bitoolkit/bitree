import 'package:flutter/material.dart';

import '../../agenda/model.dart';
import '../../agenda/ui/agenda_detail.dart';
import '../../agenda/ui/calendar_list.dart';
import '../../app/controller.dart';
import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../schedule/model.dart';
import '../../sync/controller.dart';
import '../../sync/ui/sync.dart';
import '../../ui/app_dropdown_field.dart';
import '../../ui/selection_controls.dart';
import '../exam_conflicts.dart';
import 'academic_common.dart';

class ExamsScreen extends StatefulWidget {
  const ExamsScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen> {
  late String? _term = widget.controller.timetable.schedule?.term;
  bool _includeClasses = true;
  bool _showPast = false;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.controller.agenda,
      widget.controller.timetable,
      widget.controller.school,
    ]),
    builder: (context, _) {
      final controller = widget.controller;
      final now = campusNow();
      final allExams = controller.agenda.entries
          .where((entry) => entry.kind == AgendaKind.exam)
          .toList();
      final terms = {
        if (controller.timetable.schedule != null)
          controller.timetable.schedule!.term,
        for (final exam in allExams)
          if (exam.term != null) exam.term!,
      }.toList()..sort((a, b) => b.compareTo(a));
      final term = terms.contains(_term) ? _term : null;
      final selected = allExams
          .where((entry) => term == null || entry.term == term)
          .toList();
      final exams =
          selected
              .where((entry) => _showPast || !entry.isFinished(now))
              .toList()
            ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
      final conflicts = findExamConflicts(
        exams,
        controller.timetable.schedules,
        includeClasses: _includeClasses,
      );
      final days = <DateTime, List<AgendaEntry>>{};
      for (final exam in exams) {
        days.putIfAbsent(calendarDate(exam.startsAt), () => []).add(exam);
      }
      final theme = Theme.of(context);
      final l10n = context.l10n;
      return AcademicPage(
        title: l10n.examScheduleAndConflicts,
        loading: controller.school.busy,
        actions: [
          AcademicImportButton(
            controller: controller,
            action: SyncTarget.exams,
            term: term,
          ),
        ],
        children: [
          if (terms.isNotEmpty)
            AppDropdownField<String?>(
              label: l10n.settingsTerm,
              value: term,
              entries: [
                DropdownMenuEntry(value: null, label: l10n.allSemesters),
                for (final value in terms)
                  DropdownMenuEntry(value: value, label: value),
              ],
              onChanged: (value) => setState(() => _term = value),
            ),
          AppToggleTile(
            title: Text(l10n.checkLocalSchedule),
            value: _includeClasses,
            onChanged: (value) => setState(() => _includeClasses = value),
          ),
          if (_includeClasses && controller.timetable.schedules.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                l10n.syncScheduleConflictHint,
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (conflicts.isNotEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.warning_amber_rounded,
                color: theme.colorScheme.error,
              ),
              title: Text(l10n.timeConflictsFound(conflicts.length)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => _ExamConflictsScreen(
                    controller: controller,
                    term: term,
                    includeClasses: _includeClasses,
                    showPast: _showPast,
                  ),
                ),
              ),
            ),
          for (final day in days.entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 8),
              child: Text(
                localizedAgendaDate(l10n, day.key),
                style: theme.textTheme.bodySmall,
              ),
            ),
            for (final exam in day.value)
              _ExamTile(
                controller: controller,
                exam: exam,
                conflicts: conflicts
                    .where(
                      (conflict) =>
                          conflict.exam.entry?.id == exam.id ||
                          conflict.other.entry?.id == exam.id,
                    )
                    .toList(),
              ),
          ],
          if (exams.isEmpty)
            AcademicEmpty(
              title: !_showPast && selected.isNotEmpty
                  ? l10n.noUpcomingExams
                  : l10n.noExams,
              label: SyncTarget.exams.localizedAction(l10n),
              onPressed: () => startSync(
                context,
                controller,
                targets: {SyncTarget.exams},
                term: term,
              ),
            ),
          if (selected.any((exam) => exam.isFinished(now)))
            TextButton(
              onPressed: () => setState(() => _showPast = !_showPast),
              child: Text(
                _showPast ? l10n.hideFinishedExams : l10n.showFinishedExams,
              ),
            ),
          const SizedBox(height: 16),
          Text(l10n.examAgendaSharedNote, style: theme.textTheme.bodySmall),
        ],
      );
    },
  );
}

class _ExamTile extends StatelessWidget {
  const _ExamTile({
    required this.controller,
    required this.exam,
    required this.conflicts,
  });
  final AppController controller;
  final AgendaEntry exam;
  final List<ExamConflict> conflicts;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(exam.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              localizedAgendaTime(l10n, exam),
              exam.location,
            ].where((value) => value.isNotEmpty).join('  '),
          ),
          for (final conflict in conflicts)
            Text(
              conflict.other.course != null
                  ? l10n.overlapsClass(conflict.other.title)
                  : l10n.overlapsExam(
                      conflict.exam.entry?.id == exam.id
                          ? conflict.other.title
                          : conflict.exam.title,
                    ),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => showAgendaEntry(context, controller, exam),
    );
  }
}

class _ExamConflictsScreen extends StatelessWidget {
  const _ExamConflictsScreen({
    required this.controller,
    required this.term,
    required this.includeClasses,
    required this.showPast,
  });
  final AppController controller;
  final String? term;
  final bool includeClasses;
  final bool showPast;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      controller.agenda,
      controller.timetable,
      controller.school,
    ]),
    builder: (context, _) {
      final now = campusNow();
      final conflicts = findExamConflicts(
        controller.agenda.entries.where(
          (entry) =>
              entry.kind == AgendaKind.exam &&
              (term == null || entry.term == term) &&
              (showPast || !entry.isFinished(now)),
        ),
        controller.timetable.schedules,
        includeClasses: includeClasses,
      );
      return AcademicPage(
        title: context.l10n.timeConflict,
        children: [
          if (conflicts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Text(context.l10n.noTimeConflict),
            ),
          for (final conflict in conflicts) ...[
            Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 4),
              child: Text(
                context.l10n.overlapMinutes(
                  localizedAgendaDate(context.l10n, conflict.exam.startsAt),
                  conflict.minutes,
                ),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            for (final item in [conflict.exam, conflict.other])
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.title),
                subtitle: Text(
                  [
                    localizedCalendarItemTime(context.l10n, item),
                    item.location,
                  ].where((value) => value.isNotEmpty).join('  '),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => openCalendarItem(context, controller, item),
              ),
            const Divider(height: 24),
          ],
        ],
      );
    },
  );
}
