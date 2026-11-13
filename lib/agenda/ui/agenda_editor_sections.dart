part of 'agenda_editor.dart';

extension _AgendaEditorSections on _AgendaEditorState {
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
    _updateColor(result.color);
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

  Widget _moreOptions() {
    final l10n = context.l10n;
    final hasLocation = _location.text.trim().isNotEmpty;
    final hasNotes = _notes.text.trim().isNotEmpty;
    return ExpansionTile(
      key: const ValueKey('agenda-more-options'),
      initiallyExpanded:
          hasNotes || (_kind != AgendaKind.deadline && hasLocation),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      shape: const Border(),
      collapsedShape: const Border(),
      leading: const Icon(Icons.tune_rounded, size: 20),
      title: Text(l10n.agendaMoreOptions),
      children: [
        if (_kind == AgendaKind.deadline) ...[
          Text(l10n.agendaTailDays),
          SwitchListTile(
            key: const ValueKey('agenda-tail-days-default'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.agendaTailDaysDefault),
            value: _tailDays == null,
            onChanged: _saving
                ? null
                : (useDefault) => _updateTailDays(
                    useDefault ? null : AgendaEntry.defaultTailDays,
                  ),
          ),
          if (_tailDays case final days?) ...[
            Semantics(
              label: l10n.agendaTailDays,
              child: Slider(
                key: const ValueKey('agenda-tail-days-slider'),
                value: days.toDouble(),
                min: AgendaEntry.minTailDays.toDouble(),
                max: AgendaEntry.maxTailDays.toDouble(),
                divisions: AgendaEntry.maxTailDays - AgendaEntry.minTailDays,
                label: l10n.agendaTailDaysValue(days),
                semanticFormatterCallback: (value) =>
                    l10n.agendaTailDaysValue(value.round()),
                onChanged: _saving
                    ? null
                    : (value) => _updateTailDays(value.round()),
              ),
            ),
            Text(l10n.agendaTailDaysValue(days), textAlign: TextAlign.center),
          ],
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
}
