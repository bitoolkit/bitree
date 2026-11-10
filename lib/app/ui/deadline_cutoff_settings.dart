import 'dart:async';

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

String _inputClock(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:'
    '${(minute % 60).toString().padLeft(2, '0')}';

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

class DeadlineCutoffScreen extends StatefulWidget {
  const DeadlineCutoffScreen({super.key, required this.settings});

  final AppSettingsController settings;

  @override
  State<DeadlineCutoffScreen> createState() => _DeadlineCutoffScreenState();
}

class _DeadlineCutoffScreenState extends State<DeadlineCutoffScreen> {
  late DeadlineCutoffWindow _window;
  late final TextEditingController _start;
  late final TextEditingController _end;
  final _startFocus = FocusNode();
  final _endFocus = FocusNode();
  bool _editingStart = true;
  bool _startInvalid = false;
  bool _endInvalid = false;

  @override
  void initState() {
    super.initState();
    _window = widget.settings.deadlineCutoff.value;
    _start = TextEditingController(text: _inputClock(_window.startMinute));
    _end = TextEditingController(text: _inputClock(_window.endMinute));
    _startFocus.addListener(_startFocusChanged);
    _endFocus.addListener(_endFocusChanged);
    widget.settings.deadlineCutoff.addListener(_settingsChanged);
  }

  @override
  void didUpdateWidget(covariant DeadlineCutoffScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      oldWidget.settings.deadlineCutoff.removeListener(_settingsChanged);
      widget.settings.deadlineCutoff.addListener(_settingsChanged);
      _syncInputs(widget.settings.deadlineCutoff.value);
    }
  }

  void _syncInputs(DeadlineCutoffWindow next) {
    // A switch or opposite endpoint change must not destroy partially typed
    // input. Only a changed persisted endpoint replaces its own text draft.
    if (next.startMinute != _window.startMinute) {
      _start.text = _inputClock(next.startMinute);
      _startInvalid = false;
    }
    if (next.endMinute != _window.endMinute) {
      _end.text = _inputClock(next.endMinute);
      _endInvalid = false;
    }
    _window = next;
  }

  void _settingsChanged() {
    if (!mounted) return;
    setState(() => _syncInputs(widget.settings.deadlineCutoff.value));
  }

  void _startFocusChanged() => _focusChanged(start: true);
  void _endFocusChanged() => _focusChanged(start: false);

  void _focusChanged({required bool start}) {
    final focus = start ? _startFocus : _endFocus;
    if (!mounted) return;
    if (focus.hasFocus) {
      if (_editingStart != start) setState(() => _editingStart = start);
    } else {
      _commitInput(start: start);
    }
  }

  void _commitInput({required bool start}) {
    if (!mounted) return;
    final controller = start ? _start : _end;
    final match = RegExp(r'^\s*(\d{1,2}):(\d{2})\s*$')
        .firstMatch(controller.text);
    final hour = match == null ? null : int.tryParse(match[1]!);
    final minute = match == null ? null : int.tryParse(match[2]!);
    final valid = hour != null && hour < 24 && minute != null && minute < 60;
    setState(() {
      if (start) {
        _startInvalid = !valid;
      } else {
        _endInvalid = !valid;
      }
    });
    if (hour == null || hour >= 24 || minute == null || minute >= 60) return;
    final value = hour * 60 + minute;
    controller.text = _inputClock(value);
    final latest = widget.settings.deadlineCutoff.value;
    if (value == (start ? latest.startMinute : latest.endMinute)) return;
    unawaited(widget.settings.setDeadlineCutoff(
      start
          ? latest.copyWith(startMinute: value)
          : latest.copyWith(endMinute: value),
    ));
  }

  void _resetInput(int value, {required bool start}) {
    setState(() {
      if (start) {
        _start.text = _inputClock(value);
        _startInvalid = false;
      } else {
        _end.text = _inputClock(value);
        _endInvalid = false;
      }
    });
  }

  void _cancelTime({required bool start}) {
    final latest = widget.settings.deadlineCutoff.value;
    _resetInput(
      start ? latest.startMinute : latest.endMinute,
      start: start,
    );
  }

  Future<void> _selectTime(TimeOfDay selected, {required bool start}) {
    final value = selected.hour * 60 + selected.minute;
    _resetInput(value, start: start);
    // The picker can remain mounted while enabled or the opposite endpoint
    // changes. Read the latest configuration, never its opening snapshot.
    final latest = widget.settings.deadlineCutoff.value;
    return widget.settings.setDeadlineCutoff(
      start
          ? latest.copyWith(startMinute: value)
          : latest.copyWith(endMinute: value),
    );
  }

  void _selectEndpoint(bool start) {
    FocusScope.of(context).unfocus();
    setState(() => _editingStart = start);
  }

  @override
  void dispose() {
    widget.settings.deadlineCutoff.removeListener(_settingsChanged);
    _startFocus.removeListener(_startFocusChanged);
    _endFocus.removeListener(_endFocusChanged);
    _startFocus.dispose();
    _endFocus.dispose();
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final editingStart = _editingStart;
    final hintStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    Widget input({required bool start}) => TextField(
      key: ValueKey(start ? 'deadline-cutoff-start' : 'deadline-cutoff-end'),
      controller: start ? _start : _end,
      focusNode: start ? _startFocus : _endFocus,
      keyboardType: TextInputType.datetime,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: start ? l10n.deadlineCutoffStart : l10n.deadlineCutoffEnd,
        hintText: 'HH:mm',
        prefixIcon: const Icon(Icons.schedule_rounded),
        errorText: (start ? _startInvalid : _endInvalid)
            ? MaterialLocalizations.of(context).invalidTimeLabel
            : null,
      ),
      onSubmitted: (_) => _commitInput(start: start),
    );
    return AppRoutePage(
      title: l10n.settingsDeadlineCutoff,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    key: const ValueKey('deadline-cutoff-enabled'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.deadlineCutoffEnabled),
                    subtitle: Text(l10n.deadlineCutoffDescription),
                    value: _window.enabled,
                    onChanged: (enabled) => widget.settings.setDeadlineCutoff(
                      widget.settings.deadlineCutoff.value.copyWith(
                        enabled: enabled,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _windowSummary(context, _window),
                    key: const ValueKey('deadline-cutoff-summary'),
                    style: hintStyle,
                  ),
                  const SizedBox(height: 20),
                  input(start: true),
                  const SizedBox(height: 16),
                  input(start: false),
                  const SizedBox(height: 20),
                  SegmentedButton<bool>(
                    key: const ValueKey('deadline-cutoff-endpoint'),
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: true,
                        label: Text(
                          l10n.deadlineCutoffStart,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      ButtonSegment(
                        value: false,
                        label: Text(
                          l10n.deadlineCutoffEnd,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    selected: {_editingStart},
                    onSelectionChanged: (selection) =>
                        _selectEndpoint(selection.single),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            InlineDeadlineTimePicker(
              key: const ValueKey('deadline-cutoff-clock'),
              minute: _editingStart ? _window.startMinute : _window.endMinute,
              endpoint: _editingStart,
              helpText: _editingStart
                  ? l10n.deadlineCutoffStart
                  : l10n.deadlineCutoffEnd,
              onSelected: (value) => _selectTime(value, start: editingStart),
              onCancelled: () => _cancelTime(start: editingStart),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Text(l10n.deadlineCutoffBoundaryHint, style: hintStyle),
                  const SizedBox(height: 8),
                  Text(l10n.deadlineCutoffPreserveHint, style: hintStyle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Embeds the real Material time picker, without copying its private dial.
///
/// TimePickerDialog reports OK/Cancel through Navigator.pop. The nested
/// navigator has an inert anchor below its picker, so those actions never pop
/// the settings route. Each result resets the picker, keeping it resident.
class InlineDeadlineTimePicker extends StatefulWidget {
  const InlineDeadlineTimePicker({
    super.key,
    required this.minute,
    required this.endpoint,
    required this.helpText,
    required this.onSelected,
    required this.onCancelled,
  });

  final int minute;
  final bool endpoint;
  final String helpText;
  final Future<void> Function(TimeOfDay value) onSelected;
  final VoidCallback onCancelled;

  @override
  State<InlineDeadlineTimePicker> createState() => _InlineDeadlineTimePickerState();
}

class _InlineDeadlineTimePickerState extends State<InlineDeadlineTimePicker> {
  int _generation = 0;

  @override
  void didUpdateWidget(covariant InlineDeadlineTimePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.minute != widget.minute || oldWidget.endpoint != widget.endpoint) {
      _generation++;
    }
  }

  void _complete(TimeOfDay? selected, int generation) {
    if (!mounted || generation != _generation) return;
    if (selected != null) {
      unawaited(widget.onSelected(selected));
    } else {
      widget.onCancelled();
    }
    setState(() => _generation++);
  }

  Route<TimeOfDay> _pickerRoute(int generation) {
    final route = PageRouteBuilder<TimeOfDay>(
      settings: const RouteSettings(name: 'deadline-cutoff-inline-picker'),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) => TimePickerDialog(
        initialTime: TimeOfDay(hour: widget.minute ~/ 60, minute: widget.minute % 60),
        helpText: widget.helpText,
        initialEntryMode: TimePickerEntryMode.dial,
        orientation: Orientation.portrait,
      ),
    );
    unawaited(route.popped.then((selected) => _complete(selected, generation)));
    return route;
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 580.0 *
        (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 1.1),
    child: MediaQuery.removeViewInsets(
      context: context,
      removeBottom: true,
      child: HeroControllerScope.none(
        child: Navigator(
          key: ValueKey(_generation),
          requestFocus: false,
          onGenerateInitialRoutes: (_, initialRoute) => [
            PageRouteBuilder<void>(
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const SizedBox.shrink(),
            ),
            _pickerRoute(_generation),
          ],
          onGenerateRoute: (_) => _pickerRoute(_generation),
        ),
      ),
    ),
  );
}
