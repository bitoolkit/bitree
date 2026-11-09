import 'package:flutter/material.dart';

import '../../app/controller.dart';
import '../../app/ui/add_menu.dart';
import '../../core/time.dart';
import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../schedule/model.dart';
import '../../sync/ui/sync_button.dart';
import '../../ui/app_menu_anchor.dart';
import '../../ui/app_menu_trigger.dart';
import '../../ui/app_page.dart';
import '../../ui/pull_to_reveal_list.dart';
import '../../ui/semester_dropdown.dart';
import '../controller.dart';
import '../model.dart';
import '../period.dart';
import '../view_mode.dart';
import 'agenda_list_tile.dart';
import 'agenda_timeline.dart';
import 'deleted_deadlines.dart';

part 'calendar_screen_components.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    required this.controller,
    required this.now,
    this.active = true,
  });

  final AppController controller;
  final DateTime now;
  final bool active;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  AgendaKind? _kind;
  int _status = 0;
  String? _term;
  bool _termInitialized = false;

  void _setStatus(int index) {
    if (_status != index) setState(() => _status = index);
  }

  void _setTerm(String? term) {
    if (_termInitialized && _term == term) return;
    setState(() {
      _termInitialized = true;
      _term = term;
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.controller.agenda,
      widget.controller.school,
      widget.controller.timetable,
      widget.controller.settings.agendaViewMode,
    ]),
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final l10n = context.l10n;
    final controller = widget.controller;
    final now = widget.now;
    final schedules = controller.timetable.schedules.toList();
    final allEntries = controller.agenda.entries;
    final terms = <String>{
      for (final schedule in schedules) schedule.term,
      for (final entry in allEntries)
        if (entry.term?.trim() case final term? when term.isNotEmpty) term,
    }.toList();
    final currentTerm = semesterAt(schedules, now)?.term;
    final orderedTerms = orderedSemesterTerms(terms, currentTerm: currentTerm);
    final defaultTerm =
        currentTerm ??
        controller.timetable.schedule?.term ??
        orderedTerms.firstOrNull;
    final selectedTerm = !_termInitialized
        ? defaultTerm
        : _term == null || terms.contains(_term)
        ? _term
        : null;
    final entries = filterAgendaByTerm(
      allEntries,
      selectedTerm,
      schedules,
    ).where((entry) => _kind == null || entry.kind == _kind).toList();
    final doneCount = entries.where((entry) => entry.isFinished(now)).length;
    final deletedDeadlineCount = controller.agenda.deletedDeadlines.length;
    final timeline =
        controller.settings.agendaViewMode.value == AgendaViewMode.timeline;

    Widget loadStatus() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!controller.agenda.ready && controller.agenda.busy)
          const LinearProgressIndicator(minHeight: 3),
        if (!controller.agenda.ready && !controller.agenda.busy)
          TextButton.icon(
            onPressed: controller.agenda.load,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(l10n.agendaReload),
          ),
      ],
    );

    Widget listHeader() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: 0,
                label: Text(
                  l10n.agendaPendingTab(entries.length - doneCount),
                  textAlign: TextAlign.center,
                ),
              ),
              ButtonSegment(
                value: 1,
                label: Text(
                  l10n.agendaCompletedTab(doneCount),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            selected: {_status},
            onSelectionChanged: (selection) => _setStatus(selection.single),
          ),
        ),
        loadStatus(),
      ],
    );

    return AppPage(
      title: Row(
        children: [
          Text(l10n.agendaTitle),
          const SizedBox(width: 8),
          Flexible(
            child: _AgendaKindFilter(
              value: _kind,
              onChanged: (kind) => setState(() => _kind = kind),
            ),
          ),
        ],
      ),
      actions: [
        AddButton(timetable: controller.timetable, agenda: controller.agenda),
        SyncButton(controller: controller),
        _AgendaOverflowMenu(
          terms: orderedTerms,
          currentTerm: currentTerm,
          selectedTerm: selectedTerm,
          onTermChanged: _setTerm,
          timeline: timeline,
          deletedDeadlineCount: deletedDeadlineCount,
          deletedDeadlinesEnabled:
              !controller.agenda.busy && controller.agenda.ready,
          onViewModeChanged: () => controller.settings.setAgendaViewMode(
            timeline ? AgendaViewMode.list : AgendaViewMode.timeline,
          ),
          onOpenDeletedDeadlines: () =>
              showDeletedDeadlines(context, controller.agenda),
        ),
      ],
      // Keep browsing positions while changing presentation. Horizontal
      // gestures belong to rows or timeline navigation.
      child: IndexedStack(
        index: timeline ? 1 : 0,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              listHeader(),
              Expanded(
                child: IndexedStack(
                  index: _status,
                  children: [
                    for (var index = 0; index < 2; index++)
                      _AgendaStatusList(
                        key: ValueKey((_kind, selectedTerm, index)),
                        controller: controller.agenda,
                        entries: entries,
                        completed: index == 1,
                        now: now,
                      ),
                  ],
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              loadStatus(),
              Expanded(
                child: AgendaTimeline(
                  controller: controller.agenda,
                  entries: entries,
                  now: now,
                  filter: (kind: _kind, term: selectedTerm),
                  active: widget.active,
                  visible: timeline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
