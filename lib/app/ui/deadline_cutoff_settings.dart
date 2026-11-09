import 'package:flutter/material.dart';

import '../../agenda/deadline_cutoff.dart';
import '../../l10n/l10n.dart';
import '../../ui/app_page.dart';
import '../settings_controller.dart';

String _clock(BuildContext context, int minute) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
      alwaysUse24HourFormat: true,
    );

String _windowSummary(BuildContext context, DeadlineCutoffWindow window) {
  final l10n = context.l10n;
  final start = _clock(context, window.startMinute);
  final end = _clock(context, window.endMinute);
  if (window.startMinute == window.endMinute) {
    return l10n.deadlineCutoffInstant(start);
  }
  return window.startMinute > window.endMinute
      ? l10n.deadlineCutoffOvernight(start, end)
      : l10n.deadlineCutoffSameDay(start, end);
}

class DeadlineCutoffSettingsTile extends StatelessWidget {
  const DeadlineCutoffSettingsTile({super.key, required this.settings});

  final AppSettingsController settings;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: settings.deadlineCutoff,
    builder: (context, window, _) => ListTile(
      key: const ValueKey('deadline-cutoff-settings'),
      contentPadding: const EdgeInsets.symmetric(vertical: 2),
      leading: const Icon(Icons.more_time_rounded),
      title: Text(context.l10n.settingsDeadlineCutoff),
      subtitle: Text(
        window.enabled
            ? _windowSummary(context, window)
            : context.l10n.deadlineCutoffDisabled,
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => DeadlineCutoffScreen(settings: settings),
        ),
      ),
    ),
  );
}

class DeadlineCutoffScreen extends StatelessWidget {
  const DeadlineCutoffScreen({super.key, required this.settings});

  final AppSettingsController settings;

  Future<void> _selectTime(BuildContext context, {required bool start}) async {
    final current = settings.deadlineCutoff.value;
    final minute = start ? current.startMinute : current.endMinute;
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
      initialEntryMode: TimePickerEntryMode.input,
      helpText: start
          ? context.l10n.deadlineCutoffStart
          : context.l10n.deadlineCutoffEnd,
    );
    if (selected == null || !context.mounted) return;
    final selectedMinute = selected.hour * 60 + selected.minute;
    // A picker may stay open while another setting changes. Retain the newest
    // enabled flag and opposite endpoint rather than writing the old snapshot.
    final latest = settings.deadlineCutoff.value;
    await settings.setDeadlineCutoff(
      start
          ? latest.copyWith(startMinute: selectedMinute)
          : latest.copyWith(endMinute: selectedMinute),
    );
  }

  @override
  Widget build(BuildContext context) => AppRoutePage(
    title: context.l10n.settingsDeadlineCutoff,
    child: ValueListenableBuilder(
      valueListenable: settings.deadlineCutoff,
      builder: (context, window, _) {
        final l10n = context.l10n;
        final hintStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            SwitchListTile(
              key: const ValueKey('deadline-cutoff-enabled'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.deadlineCutoffEnabled),
              subtitle: Text(l10n.deadlineCutoffDescription),
              value: window.enabled,
              onChanged: (enabled) => settings.setDeadlineCutoff(
                window.copyWith(enabled: enabled),
              ),
            ),
            const SizedBox(height: 12),
            Text(_windowSummary(context, window), style: hintStyle),
            const SizedBox(height: 12),
            ListTile(
              key: const ValueKey('deadline-cutoff-start'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_rounded),
              title: Text(l10n.deadlineCutoffStart),
              subtitle: Text(_clock(context, window.startMinute)),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _selectTime(context, start: true),
            ),
            ListTile(
              key: const ValueKey('deadline-cutoff-end'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_rounded),
              title: Text(l10n.deadlineCutoffEnd),
              subtitle: Text(_clock(context, window.endMinute)),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _selectTime(context, start: false),
            ),
            const SizedBox(height: 12),
            Text(l10n.deadlineCutoffBoundaryHint, style: hintStyle),
            const SizedBox(height: 8),
            Text(l10n.deadlineCutoffPreserveHint, style: hintStyle),
          ],
        );
      },
    ),
  );
}
