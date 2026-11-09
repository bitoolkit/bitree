import 'package:flutter/material.dart';

import '../../app/controller.dart';
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
import '../model.dart';
import 'agenda_color_palette.dart';
import 'agenda_color_picker.dart';
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

  final AppController controller;
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
  late int _tailDays = widget.entry?.tailDays ?? AgendaEntry.defaultTailDays;
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
        color: _kind == AgendaKind.exam ? null : _color,
        // Editing turns a generated record into a user-authored snapshot. Its
        // localized presentation must not keep overriding the edited values.
        details: null,
        tailDays: _tailDays,
        // Editing keeps the open-ended flag, but only while the entry stays a
        // deadline: an event or exam always has an end time.
        startOnly:
            _kind == AgendaKind.deadline &&
            (widget.entry?.startOnly ?? false),
      ),
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

  Widget _timeRow(String label, DateTime value, bool start) {
    final enabled = !_saving;
    final time = _allDay ? '' : clockText(value);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Expanded(
            child: Semantics(
              button: true,
              enabled: enabled,
              label: '$label ${dateText(value)}',
              onTap: enabled ? () => _pickDate(start) : null,
              child: ExcludeSemantics(
                child: InkWell(
                  key: ValueKey('agenda-${start ? 'start' : 'end'}-date'),
                  onTap: enabled ? () => _pickDate(start) : null,
                  borderRadius: AppCorners.control,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      dateText(value),
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (time.isNotEmpty)
            Semantics(
              button: true,
              enabled: enabled,
              label: '$label $time',
              onTap: enabled ? () => _pickTime(start) : null,
              child: ExcludeSemantics(
                child: InkWell(
                  key: ValueKey('agenda-${start ? 'start' : 'end'}-time'),
                  onTap: enabled ? () => _pickTime(start) : null,
                  borderRadius: AppCorners.control,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: AppCorners.control,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      child: Text(
                        time,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _colorSwatch(ThemeData theme, AgendaColor? color, {Key? key}) {
    final fill = color == null
        ? theme.colorScheme.surfaceContainerHighest
        : agendaColorValues(theme.colorScheme, color).fill;
    final accent = color == null
        ? theme.colorScheme.outline
        : agendaColorValues(theme.colorScheme, color).accent;
    return Container(
      key: key,
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: accent, width: 1.5),
      ),
    );
  }

  Future<void> _pickColor() async {
    final result = await showAgendaColorPicker(context, initialColor: _color);
    if (result == null || !mounted) return;
    setState(() => _color = result.color);
  }

  Widget _colorSelector() {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final selectedLabel =
        _color?.localizedLabel(l10n) ?? l10n.agendaColorDefault;
    return ListTile(
      key: const ValueKey('agenda-color-field'),
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: _colorSwatch(
        theme,
        _color,
        key: const ValueKey('agenda-color-current-swatch'),
      ),
      title: Text(l10n.agendaColor),
      subtitle: Text(selectedLabel, key: const ValueKey('agenda-color-value')),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: _saving ? null : _pickColor,
    );
  }

  Widget _moreOptions(ThemeData theme) {
    final l10n = context.l10n;
    final hasLocation = _location.text.trim().isNotEmpty;
    final hasNotes = _notes.text.trim().isNotEmpty;
    final hasCustomTail =
        _kind == AgendaKind.deadline &&
        _tailDays != AgendaEntry.defaultTailDays;
    return ExpansionTile(
      key: const ValueKey('agenda-more-options'),
      initiallyExpanded:
          hasNotes ||
          hasCustomTail ||
          (_kind != AgendaKind.deadline && hasLocation),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      shape: const Border(),
      collapsedShape: const Border(),
      leading: const Icon(Icons.tune_rounded, size: 20),
      title: Text(l10n.agendaMoreOptions),
      children: [
        if (_kind == AgendaKind.deadline) ...[
          Row(
            children: [
              Expanded(child: Text(l10n.agendaTailDays)),
              Text(l10n.agendaTailDaysValue(_tailDays)),
            ],
          ),
          Semantics(
            label: l10n.agendaTailDays,
            child: Slider(
              value: _tailDays.toDouble(),
              min: 1,
              max: AgendaEntry.maxTailDays.toDouble(),
              divisions: AgendaEntry.maxTailDays - 1,
              label: l10n.agendaTailDaysValue(_tailDays),
              semanticFormatterCallback: (value) =>
                  l10n.agendaTailDaysValue(value.round()),
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _tailDays = value.round()),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              l10n.agendaTailDaysHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_kind != AgendaKind.deadline) ...[
          TextFormField(
            controller: _location,
            enabled: !_saving,
            decoration: InputDecoration(labelText: l10n.agendaLocationOptional),
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
    );
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
                  _kind == AgendaKind.deadline && widget.entry?.startOnly != true
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
          _moreOptions(theme),
        ],
      ),
    );
  }
}
