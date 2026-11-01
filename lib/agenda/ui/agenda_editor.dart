import 'package:flutter/material.dart';

import '../../app/controller.dart';
import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../schedule/model.dart';
import '../../schedule/selection.dart';
import '../../ui/dialog_layout.dart';
import '../../ui/editor_sheet.dart';
import '../../ui/external_link.dart';
import '../../ui/sheet_layout.dart';
import '../model.dart';
import 'agenda_operations.dart';

Future<void> editAgenda(
  BuildContext context,
  AppController controller, {
  AgendaEntry? entry,
  AgendaKind kind = AgendaKind.event,
  TimetableSelection? selection,
  DateTime? date,
  String? term,
}) => showAppSheet<void>(
  context: context,
  builder: (_) => _AgendaEditor(
    controller: controller,
    entry: entry,
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
    this.endsAt,
    this.term,
  });

  final AppController controller;
  final AgendaEntry? entry;
  final AgendaKind kind;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String? term;

  @override
  State<_AgendaEditor> createState() => _AgendaEditorState();
}

class _AgendaEditorState extends State<_AgendaEditor> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.entry?.title);
  late final _location = TextEditingController(text: widget.entry?.location);
  late final _notes = TextEditingController(text: widget.entry?.notes);
  late AgendaKind _kind = widget.kind;
  late DateTime _start = widget.entry?.startsAt ?? widget.startsAt;
  late DateTime _end =
      widget.entry?.allDay == true && widget.entry?.endsAt != null
      ? widget.entry!.endsAt!.subtract(const Duration(days: 1))
      : widget.entry?.endsAt ??
            widget.endsAt ??
            _start.add(const Duration(hours: 1));
  late bool _allDay = widget.entry?.allDay ?? false;
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
    final success = await widget.controller.agenda.save(
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
        term: widget.entry?.term ?? widget.term,
        source: widget.entry?.source,
        course: widget.entry?.course ?? '',
        url: widget.entry?.url,
      ),
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

  Future<void> _delete() async {
    setState(() => _saving = true);
    final success = await deleteAgendaEntry(
      context,
      widget.controller,
      widget.entry!,
    );
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
    } else {
      setState(() => _saving = false);
    }
  }

  Widget _when(String label, DateTime value, bool start) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      children: [
        SizedBox(width: 44, child: Text(label)),
        Expanded(
          child: OutlinedButton(
            onPressed: _saving ? null : () => _pickDate(start),
            child: Text(dateText(value)),
          ),
        ),
        if (!_allDay) ...[
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: _saving ? null : () => _pickTime(start),
            child: Text(clockText(value)),
          ),
        ],
      ],
    ),
  );

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
          Row(
            children: [
              Expanded(child: Text(l10n.agendaAllDay)),
              Switch(
                value: _allDay,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _allDay = value),
              ),
            ],
          ),
          _when(
            _kind == AgendaKind.deadline ? l10n.due : l10n.start,
            _start,
            true,
          ),
          if (_kind != AgendaKind.deadline) _when(l10n.end, _end, false),
          const SizedBox(height: 16),
          if (_kind != AgendaKind.deadline) ...[
            TextFormField(
              controller: _location,
              enabled: !_saving,
              decoration: InputDecoration(
                labelText: l10n.agendaLocationOptional,
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _notes,
            enabled: !_saving,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(labelText: l10n.agendaNotesOptional),
          ),
        ],
      ),
    );
  }
}
