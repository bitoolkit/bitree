import 'package:flutter/material.dart';

import '../../agenda/controller.dart';
import '../../agenda/model.dart';
import '../../agenda/ui/agenda_editor.dart';
import '../../l10n/l10n.dart';
import '../../schedule/controller.dart';
import '../../schedule/selection.dart';
import '../../schedule/ui/course_editor.dart';
import '../../ui/app_menu_anchor.dart';

bool _canAddCourse(TimetableController timetable) => !timetable.busy;

bool _canAddAgenda(AgendaController agenda) => agenda.ready && !agenda.busy;

class AddMenu extends StatelessWidget {
  const AddMenu({
    super.key,
    required this.timetable,
    required this.agenda,
    this.menuController,
    this.selection,
    this.date,
    this.onClose,
    this.builder,
    this.child,
  });

  final TimetableController timetable;
  final AgendaController agenda;
  final MenuController? menuController;
  final TimetableSelection? selection;
  final DateTime? date;
  final VoidCallback? onClose;
  final AppMenuAnchorBuilder? builder;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final canAddCourse = _canAddCourse(timetable);
    final canAddAgenda = _canAddAgenda(agenda);
    return AppMenuAnchor(
      controller: menuController,
      onClose: onClose,
      menuChildren: [
        AppMenuItemButton(
          onPressed: canAddCourse
              ? () => editCourse(context, timetable, selection: selection)
              : null,
          leadingIcon: const Icon(Icons.school_outlined),
          child: Text(l10n.addCourse),
        ),
        for (final (kind, label, icon) in [
          (AgendaKind.event, l10n.addAgenda, Icons.event_outlined),
          (AgendaKind.deadline, l10n.addDeadline, Icons.flag_outlined),
        ])
          AppMenuItemButton(
            onPressed: canAddAgenda
                ? () => editAgenda(
                    context,
                    agenda,
                    kind: kind,
                    selection: selection,
                    date: date,
                    term: timetable.schedule?.term,
                  )
                : null,
            leadingIcon: Icon(icon),
            child: Text(label),
          ),
      ],
      builder: builder,
      child: child,
    );
  }
}

class AddButton extends StatelessWidget {
  const AddButton({
    super.key,
    required this.timetable,
    required this.agenda,
    this.date,
  });

  final TimetableController timetable;
  final AgendaController agenda;
  final DateTime? date;

  @override
  Widget build(BuildContext context) => AddMenu(
    timetable: timetable,
    agenda: agenda,
    date: date,
    builder: (context, menu, isOpen) => IconButton(
      tooltip: context.l10n.add,
      onPressed: !_canAddCourse(timetable) && !_canAddAgenda(agenda)
          ? null
          : () => isOpen ? menu.close() : menu.open(),
      icon: const Icon(Icons.add_rounded),
    ),
  );
}
