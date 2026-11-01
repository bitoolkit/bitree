import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/controller.dart';
import '../../app/ui/widget_guide.dart';
import '../../core/diagnostics.dart';
import '../../l10n/l10n.dart';
import '../../ui/app_menu_anchor.dart';
import '../../ui/app_notice.dart';
import '../ics.dart';
import '../model.dart';
import 'week_range_dialog.dart';

class ScheduleMenu extends StatefulWidget {
  const ScheduleMenu({super.key, required this.controller});

  final AppController controller;

  @override
  State<ScheduleMenu> createState() => _ScheduleMenuState();
}

class _ScheduleMenuState extends State<ScheduleMenu> {
  bool _exporting = false;

  Future<void> _export(SemesterSchedule schedule) async {
    if (_exporting) return;
    final skipped = schedule.courses
        .where((course) => !course.isScheduled)
        .length;
    if (skipped == schedule.courses.length) {
      showAppNotice(context, context.l10n.exportScheduleEmpty);
      return;
    }
    setState(() => _exporting = true);
    try {
      final term = schedule.term.replaceAll(
        RegExp(r'[<>:"/\\|?*\x00-\x1f]'),
        '_',
      );
      final saved = await FilePicker.saveFile(
        fileName: 'BITree-$term.ics',
        bytes: Uint8List.fromList(
          utf8.encode(scheduleToIcs(schedule, context.l10n)),
        ),
        mimeType: 'text/calendar',
        dialogTitle: context.l10n.exportSchedule,
      );
      if (!mounted || saved == null) return;
      showAppNotice(
        context,
        skipped == 0
            ? context.l10n.exportScheduleSuccess
            : context.l10n.exportScheduleSkipped(skipped),
      );
    } on Exception catch (failure, stack) {
      AppDiagnostics.instance.report('导出课表', failure, stack);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final schedule = widget.controller.timetable.schedule;
    final enabled = !widget.controller.timetable.busy;
    return AppMenuAnchor(
      menuChildren: [
        AppMenuItemButton(
          leadingIcon: const Icon(Icons.date_range_outlined),
          onPressed: schedule == null || !enabled
              ? null
              : () => manageTermWeeks(context, widget.controller),
          child: Text(l10n.weekManagement),
        ),
        if (Platform.isAndroid)
          AppMenuItemButton(
            onPressed: () => showWidgetGuide(context),
            leadingIcon: const Icon(Icons.widgets_outlined),
            child: Text(l10n.desktopAgendaWidget),
          ),
        AppMenuItemButton(
          onPressed: schedule == null || !enabled || _exporting
              ? null
              : () => _export(schedule),
          leadingIcon: const Icon(Icons.file_download_outlined),
          child: Text(l10n.exportIcs),
        ),
      ],
      builder: (context, menu, isOpen) => IconButton(
        tooltip: l10n.more,
        onPressed: _exporting
            ? null
            : () => isOpen ? menu.close() : menu.open(),
        icon: const Icon(Icons.more_horiz_rounded),
      ),
    );
  }
}
