import 'package:flutter/material.dart';

import '../../agenda/model.dart';
import '../../agenda/ui/agenda_editor.dart';
import '../../l10n/l10n.dart';
import '../../schedule/selection.dart';
import '../../schedule/ui/course_editor.dart';
import '../../ui/app_menu_anchor.dart';
import '../controller.dart';

class AddMenu extends StatelessWidget {
  const AddMenu({
    super.key,
    required this.controller,
    this.menuController,
    this.selection,
    this.date,
    this.onClose,
    this.builder,
    this.child,
  });

  final AppController controller;
  final MenuController? menuController;
  final TimetableSelection? selection;
  final DateTime? date;
  final VoidCallback? onClose;
  final AppMenuAnchorBuilder? builder;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final agendaEnabled = controller.agenda.ready && !controller.agenda.busy;
    return AppMenuAnchor(
      controller: menuController,
      onClose: onClose,
      menuChildren: [
        AppMenuItemButton(
          onPressed: controller.timetable.busy
              ? null
              : () => editCourse(context, controller, selection: selection),
          leadingIcon: const Icon(Icons.school_outlined),
          child: Text(l10n.addCourse),
        ),
        for (final (kind, label, icon) in [
          (AgendaKind.event, l10n.addAgenda, Icons.event_outlined),
          (AgendaKind.deadline, l10n.addDeadline, Icons.flag_outlined),
        ])
          AppMenuItemButton(
            onPressed: agendaEnabled
                ? () => editAgenda(
                    context,
                    controller,
                    kind: kind,
                    selection: selection,
                    date: date,
                    term: controller.timetable.schedule?.term,
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
  const AddButton({super.key, required this.controller, this.date});

  final AppController controller;
  final DateTime? date;

  @override
  Widget build(BuildContext context) => AddMenu(
    controller: controller,
    date: date,
    builder: (context, menu, isOpen) => IconButton(
      tooltip: context.l10n.add,
      onPressed: controller.timetable.busy || controller.agenda.busy
          ? null
          : () => isOpen ? menu.close() : menu.open(),
      icon: const Icon(Icons.add_rounded),
    ),
  );
}
