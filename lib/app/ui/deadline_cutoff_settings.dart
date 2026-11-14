import 'package:flutter/material.dart';

import '../../agenda/deadline_cutoff.dart';
import '../../l10n/l10n.dart';
import '../../ui/app_page.dart';
import '../../ui/app_pickers.dart';
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
    final window = settings.deadlineCutoff.value;
    final minute = start ? window.startMinute : window.endMinute;
    final selected = await showAppTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
      helpText: start
          ? context.l10n.deadlineCutoffStart
          : context.l10n.deadlineCutoffEnd,
    );
    if (selected == null || !context.mounted) return;
    // Preserve changes to the switch or opposite endpoint while the dial is open.
    final latest = settings.deadlineCutoff.value;
    final value = selected.hour * 60 + selected.minute;
    await settings.setDeadlineCutoff(
      start
          ? latest.copyWith(startMinute: value)
          : latest.copyWith(endMinute: value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppRoutePage(
      title: l10n.settingsDeadlineCutoff,
      child: ValueListenableBuilder(
        valueListenable: settings.deadlineCutoff,
        builder: (context, window, _) {
          Widget timeTile({required bool start}) => ListTile(
            key: ValueKey(
              start ? 'deadline-cutoff-start' : 'deadline-cutoff-end',
            ),
            leading: const Icon(Icons.schedule_rounded),
            title: Text(
              start ? l10n.deadlineCutoffStart : l10n.deadlineCutoffEnd,
            ),
            trailing: Text(
              _clock(context, start ? window.startMinute : window.endMinute),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            onTap: () => _selectTime(context, start: start),
          );
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  key: const ValueKey('deadline-cutoff-enabled'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.deadlineCutoffEnabled),
                  subtitle: Text(l10n.deadlineCutoffDescription),
                  value: window.enabled,
                  onChanged: (enabled) => settings.setDeadlineCutoff(
                    settings.deadlineCutoff.value.copyWith(enabled: enabled),
                  ),
                ),
                const SizedBox(height: 12),
                timeTile(start: true),
                timeTile(start: false),
                const SizedBox(height: 12),
                Text(
                  _windowSummary(context, window),
                  key: const ValueKey('deadline-cutoff-summary'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
