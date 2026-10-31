import 'package:flutter/material.dart';

import '../../app/controller.dart';
import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../ui/app_dropdown_field.dart';
import '../../ui/dialog_layout.dart';
import '../../ui/editor_sheet.dart';
import '../../ui/sheet_layout.dart';
import '../model.dart';
import '../selection.dart';
import 'course_period_fields.dart';
import 'course_week_picker.dart';
import 'week_range_sheet.dart';

Future<void> editCourse(
  BuildContext context,
  AppController controller, {
  Course? course,
  TimetableSelection? selection,
}) => showAppSheet<void>(
  context: context,
  builder: (_) => _CourseEditor(
    controller: controller,
    course: course,
    selection: selection,
  ),
);

class _CourseEditor extends StatefulWidget {
  const _CourseEditor({required this.controller, this.course, this.selection});

  final AppController controller;
  final Course? course;
  final TimetableSelection? selection;

  @override
  State<_CourseEditor> createState() => _CourseEditorState();
}

class _CourseEditorState extends State<_CourseEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.course?.name);
  late final _room = TextEditingController(text: widget.course?.room);
  late final _teacher = TextEditingController(text: widget.course?.teacher);
  late final _term = TextEditingController(text: _initialTerm());
  late int _day =
      widget.course?.weekday ??
      widget.selection?.date.weekday ??
      campusNow().weekday;
  late int _start =
      widget.course?.startSection ?? widget.selection?.startSection ?? 1;
  late int _end =
      widget.course?.endSection ?? widget.selection?.endSection ?? 2;
  late DateTime _monday =
      widget.controller.timetable.schedule?.firstMonday ??
      mondayOf(campusNow());
  late Set<int> _weeks =
      widget.course?.weeks.toSet() ??
      (widget.selection == null
          ? null
          : {
              widget.controller.timetable.schedule!.weekAt(
                widget.selection!.date,
              ),
            }) ??
      (widget.controller.timetable.schedule?.weeks ?? academicWeeks(1, 25))
          .toSet();
  late int _firstWeek = widget.controller.timetable.schedule?.firstWeek ?? 1;
  late int _lastWeek = widget.controller.timetable.schedule?.lastWeek ?? 25;
  bool _saving = false;
  String? _error;

  String _initialTerm() {
    final now = campusNow();
    final year = now.month >= 8 ? now.year : now.year - 1;
    return widget.controller.timetable.schedule?.term ??
        '$year-${year + 1}-${now.month >= 8 ? 1 : 2}';
  }

  @override
  void dispose() {
    _name.dispose();
    _room.dispose();
    _teacher.dispose();
    _term.dispose();
    super.dispose();
  }

  Future<void> _manageWeeks() async {
    final range = await showWeekRangeSheet(
      context,
      first: _firstWeek,
      last: _lastWeek,
      controller: widget.controller.timetable.schedule == null
          ? null
          : widget.controller,
    );
    if (range == null || !mounted) return;
    setState(() {
      _firstWeek = range.first;
      _lastWeek = range.last;
      _weeks = _weeks
          .where((week) => week >= range.first && week <= range.last)
          .toSet();
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_weeks.isEmpty) {
      setState(() => _error = context.l10n.courseEditorWeeksRequired);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final course = Course(
      id:
          widget.course?.stableId ??
          'local-${DateTime.now().microsecondsSinceEpoch}',
      name: _name.text.trim(),
      teacher: _teacher.text.trim(),
      room: _room.text.trim(),
      campus: widget.course?.campus ?? '',
      number: widget.course?.number ?? '',
      description: widget.course?.description ?? '',
      weekday: _day,
      startSection: _start,
      endSection: _end,
      weeks: _weeks.toList(),
      local: true,
    );
    final success = await widget.controller.timetable.saveCourse(
      course,
      replacing: widget.course,
      semester: widget.controller.timetable.schedule == null
          ? SemesterSchedule(
              term: _term.text.trim(),
              firstMonday: _monday,
              firstWeek: _firstWeek,
              lastWeek: _lastWeek,
              courses: [],
            )
          : null,
    );
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
    } else {
      setState(() {
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final weeks = academicWeeks(_firstWeek, _lastWeek);
    return EditorSheet(
      title: widget.course == null
          ? l10n.courseEditorAddTitle
          : l10n.courseEditorEditTitle,
      saveLabel: Text(_saving ? l10n.saving : l10n.courseEditorSave),
      formKey: _form,
      saving: _saving,
      error: _error,
      onSave: _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.controller.timetable.schedule == null) ...[
            TextFormField(
              controller: _term,
              enabled: !_saving,
              decoration: InputDecoration(labelText: l10n.courseEditorTerm),
              validator: (value) =>
                  value!.trim().isEmpty ? l10n.courseEditorTermRequired : null,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: _saving
                  ? null
                  : () async {
                      final date = await showDatePicker(
                        context: context,
                        builder: appPickerDialogBuilder,
                        initialDate: _monday,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        selectableDayPredicate: (date) =>
                            date.weekday == DateTime.monday,
                        helpText: l10n.courseEditorMondayHelp,
                      );
                      if (date != null) {
                        setState(() => _monday = calendarDate(date));
                      }
                    },
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text(l10n.courseEditorMondayLabel(dateText(_monday))),
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _name,
            enabled: !_saving,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: l10n.courseEditorName),
            validator: (value) =>
                value!.trim().isEmpty ? l10n.courseEditorNameRequired : null,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final room = TextFormField(
                controller: _room,
                enabled: !_saving,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l10n.courseEditorRoom),
              );
              final teacher = TextFormField(
                controller: _teacher,
                enabled: !_saving,
                decoration: InputDecoration(
                  labelText: l10n.courseEditorTeacher,
                ),
              );
              final scale = MediaQuery.textScalerOf(context).scale(1);
              if (constraints.maxWidth < 300 * scale) {
                return Column(
                  children: [room, const SizedBox(height: 12), teacher],
                );
              }
              return Row(
                children: [
                  Expanded(child: room),
                  const SizedBox(width: 12),
                  Expanded(child: teacher),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          AppDropdownField<int>(
            value: _day,
            label: l10n.courseEditorWeekday,
            entries: [
              for (var i = 1; i <= 7; i++)
                DropdownMenuEntry(value: i, label: localizedWeekday(l10n, i)),
            ],
            onChanged: _saving ? null : (value) => setState(() => _day = value),
          ),
          const SizedBox(height: 12),
          CoursePeriodFields(
            startSection: _start,
            endSection: _end,
            enabled: !_saving,
            onChanged: (start, end) {
              setState(() {
                _start = start;
                _end = end;
              });
            },
          ),
          const SizedBox(height: 12),
          CourseWeekPicker(
            weeks: weeks,
            selectedWeeks: _weeks,
            enabled: !_saving,
            onChanged: (weeks) => setState(() => _weeks = weeks),
            onManageRange: _manageWeeks,
          ),
        ],
      ),
    );
  }
}
