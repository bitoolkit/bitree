import 'package:flutter/material.dart';

import '../../core/time.dart';
import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../schedule/selection.dart';
import '../../ui/design.dart';
import '../../ui/dialog_layout.dart';
import '../../ui/editor_sheet.dart';
import '../../ui/external_link.dart';
import '../../ui/sheet_layout.dart';
import '../agenda_color.dart';
import '../controller.dart';
import '../model.dart';
import 'agenda_color_palette.dart';
import 'agenda_color_picker.dart';
import 'agenda_operations.dart';

part 'agenda_editor_sections.dart';

Future<void> editAgenda(
  BuildContext context,
  AgendaController controller, {
  AgendaEntry? entry,
  AgendaKind kind = AgendaKind.event,
  TimetableSelection? selection,
  DateTime? date,
  String? term,
}) => showAppSheet<void>(
  context: context,
  builder: (sheetContext) => _AgendaEditor(
    controller: controller,
    entry: entry,
    entryTitle: entry == null
        ? null
        : localizedAgendaTitle(sheetContext.l10n, entry),
    entryNotes: entry == null
        ? null
        : localizedAgendaNotes(sheetContext.l10n, entry),
    kind: entry?.kind ?? kind,
    startsAt: selection?.startsAt ?? date ?? campusNow(),
    endsAt: selection?.endsAt,
    term: term,
  ),
);

class _AgendaEditor extends StatefulWidget {
  const _AgendaEditor({
    required this.controller,
    required this.kind,
    required this.startsAt,
    this.entry,
    this.entryTitle,
    this.entryNotes,
    this.endsAt,
    this.term,
  });

  final AgendaController controller;
  final AgendaEntry? entry;
  final String? entryTitle;
  final String? entryNotes;
  final AgendaKind kind;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String? term;

  @override
  State<_AgendaEditor> createState() => _AgendaEditorState();
}

class _AgendaEditorState extends State<_AgendaEditor> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.entryTitle);
  late final _location = TextEditingController(text: widget.entry?.location);
  late final _notes = TextEditingController(text: widget.entryNotes);
  late int? _tailDays = widget.entry?.tailDays;
  late AgendaKind _kind = widget.kind;
  late DateTime _start = widget.entry?.startsAt ?? widget.startsAt;
  late DateTime _end =
      widget.entry?.allDay == true && widget.entry?.endsAt != null
      ? widget.entry!.endsAt!.subtract(const Duration(days: 1))
      : widget.entry?.endsAt ??
            widget.endsAt ??
            _start.add(const Duration(hours: 1));
  late bool _allDay = widget.entry?.allDay ?? false;
  late AgendaColor? _color = widget.entry?.color;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool start) async {
    final current = start ? _start : _end;
    final date = await showDatePicker(
      context: context,
      builder: appPickerDialogBuilder,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final value = DateTime.utc(
      date.year,
      date.month,
      date.day,
      current.hour,
      current.minute,
    );
    setState(() {
      if (start) {
        _end = _end.add(value.difference(_start));
        _start = value;
      } else {
        _end = value;
      }
    });
  }

  Future<void> _pickTime(bool start) async {
    final current = start ? _start : _end;
    final time = await showTimePicker(
      context: context,
      builder: appPickerDialogBuilder,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    final value = DateTime.utc(
      current.year,
      current.month,
      current.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (start) {
        _end = _end.add(value.difference(_start));
        _start = value;
      } else {
        _end = value;
      }
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final start = _allDay ? calendarDate(_start) : _start;
    final end = _allDay
        ? calendarDate(_end).add(const Duration(days: 1))
        : _end;
    if (_kind != AgendaKind.deadline && !end.isAfter(start)) {
      setState(() => _error = context.l10n.agendaEndAfterStart);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final l10n = context.l10n;
    final success = await widget.controller.save(
      AgendaEntry(
        id:
            widget.entry?.id ??
            'local-${DateTime.now().microsecondsSinceEpoch}',
        title: _title.text.trim(),
        kind: _kind,
        startsAt: start,
        endsAt: _kind == AgendaKind.deadline ? null : end,
        allDay: _allDay,
        location: _location.text.trim(),
        notes: _notes.text.trim(),
        done: widget.entry?.done ?? false,
        examAutoCompletionHandled:
            widget.entry?.examAutoCompletionHandled ?? false,
        completionSchemaVersion:
            widget.entry?.completionSchemaVersion ??
            AgendaEntry.currentCompletionSchemaVersion,
        term: widget.entry?.term ?? widget.term,
        source: widget.entry?.source,
        course: widget.entry?.course ?? '',
        url: widget.entry?.url,
        color: _kind == AgendaKind.exam ? null : _color,
        // Editing turns a generated record into a user-authored snapshot. Its
        // localized presentation must not keep overriding the edited values.
        details: null,
        tailDays: _tailDays,
        // Editing keeps the open-ended flag, but only while the entry stays a
        // deadline: an event or exam always has an end time.
        startOnly:
            _kind == AgendaKind.deadline && (widget.entry?.startOnly ?? false),
      ),
      preserveCompletion: true,
    );
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
    } else {
      setState(() {
        _saving = false;
        _error = l10n.operationSaveFailed;
      });
    }
  }

  Future<void> _delete() async {
    setState(() => _saving = true);
    final error = context.l10n.operationDeleteFailed;
    final success = await deleteAgendaEntry(
      context,
      widget.controller,
      widget.entry!,
    );
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  void _updateTailDays(int? days) {
    setState(() => _tailDays = days);
  }

  void _updateColor(AgendaColor? color) {
    setState(() => _color = color);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final kindLabel = _kind == AgendaKind.event
        ? l10n.agenda
        : _kind.localizedLabel(l10n);

    return EditorSheet(
      title: widget.entry == null
          ? l10n.agendaAddTitle(kindLabel)
          : l10n.agendaEditTitle(kindLabel),
      onDelete: widget.entry == null ? null : _delete,
      saveLabel: _saving
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(l10n.save),
      formKey: _form,
      saving: _saving,
      error: _error,
      onSave: _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.entry == null) ...[
            SegmentedButton<AgendaKind>(
              segments: [
                ButtonSegment(
                  value: AgendaKind.event,
                  label: Text(l10n.agenda),
                ),
                ButtonSegment(value: AgendaKind.deadline, label: Text('DDL')),
              ],
              selected: {_kind},
              showSelectedIcon: false,
              onSelectionChanged: _saving
                  ? null
                  : (values) => setState(() => _kind = values.single),
            ),
            const SizedBox(height: 16),
          ],
          if (widget.entry?.source != null) ...[
            Text(
              [
                widget.entry!.source!.localizedLabel(l10n),
                if (widget.entry!.course.isNotEmpty) widget.entry!.course,
              ].join('  '),
              style: theme.textTheme.bodySmall,
            ),
            if (widget.entry?.url case final url?)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _saving
                      ? null
                      : () => openExternalLink(
                          context,
                          url,
                          failureTitle: l10n.agendaOpenLink,
                        ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text(l10n.agendaOpenLink),
                ),
              ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _title,
            enabled: !_saving,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: l10n.agendaName),
            validator: (text) =>
                text!.trim().isEmpty ? l10n.agendaNameRequired : null,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.agendaTime,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(l10n.agendaAllDay),
              Switch(
                value: _allDay,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _allDay = value),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Material(
            color: theme.colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: AppCorners.control,
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _timeRow(
                  _kind == AgendaKind.deadline &&
                          widget.entry?.startOnly != true
                      ? l10n.due
                      : l10n.start,
                  _start,
                  true,
                ),
                if (_kind != AgendaKind.deadline) ...[
                  Divider(height: 1, color: theme.colorScheme.outlineVariant),
                  _timeRow(l10n.end, _end, false),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (_kind != AgendaKind.exam) _colorSelector(),
          _moreOptions(),
        ],
      ),
    );
  }
}
