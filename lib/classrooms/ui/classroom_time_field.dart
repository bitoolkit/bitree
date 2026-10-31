import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../schedule/model.dart';
import '../../ui/app_dropdown_field.dart';
import '../../ui/design.dart';
import '../../ui/selection_controls.dart';
import '../../ui/sheet_layout.dart';
import '../model.dart';

enum _TimePreset { all, current, morning, afternoon, evening, custom }

class ClassroomTimeField extends StatelessWidget {
  const ClassroomTimeField({
    super.key,
    required this.value,
    required this.date,
    required this.now,
    required this.onChanged,
  });

  final ClassroomPeriod? value;
  final DateTime date;
  final DateTime now;
  final ValueChanged<ClassroomPeriod?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final current = date == calendarDate(now)
        ? currentClassroomSection(now)
        : null;
    final ranges = {
      if (current != null) _TimePreset.current: (start: current, end: current),
      _TimePreset.morning: (start: 1, end: 5),
      _TimePreset.afternoon: (start: 6, end: 10),
      _TimePreset.evening: (start: 11, end: sectionTimes.length),
    };
    final selected = value == null
        ? _TimePreset.all
        : ranges.entries
                  .where((entry) => entry.value == value)
                  .firstOrNull
                  ?.key ??
              _TimePreset.custom;
    final names = {
      _TimePreset.all: l10n.allPeriods,
      _TimePreset.current: l10n.currentPeriod,
      _TimePreset.morning: l10n.morning,
      _TimePreset.afternoon: l10n.afternoon,
      _TimePreset.evening: l10n.evening,
      _TimePreset.custom: l10n.customPeriods,
    };

    return AppDropdownField<_TimePreset>(
      label: l10n.freeTime,
      value: selected,
      textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
      entries: [
        for (final preset in [
          _TimePreset.all,
          ...ranges.keys,
          _TimePreset.custom,
        ])
          DropdownMenuEntry(
            value: preset,
            label: preset == selected && value != null
                ? value!.localizedTime(l10n)
                : names[preset]!,
            labelWidget: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(names[preset]!),
                  const SizedBox(height: 2),
                  Text(switch (preset) {
                    _TimePreset.all => l10n.viewAllFreePeriods,
                    _TimePreset.custom => l10n.chooseOneOrMoreSections,
                    _ => l10n.periodAndSection(
                      ranges[preset]!.localizedTime(l10n),
                      ranges[preset]!.localizedSection(l10n),
                    ),
                  }, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
      ],
      onChanged: (preset) async {
        if (preset != _TimePreset.custom) {
          onChanged(ranges[preset]);
          return;
        }
        final selection = await showAppSheet<({ClassroomPeriod? period})>(
          context: context,
          builder: (_) => _ClassroomTimeSheet(
            initial: value ?? (start: current ?? 1, end: current ?? 2),
          ),
        );
        if (selection != null && context.mounted) {
          onChanged(selection.period);
        }
      },
    );
  }
}

class _ClassroomTimeSheet extends StatefulWidget {
  const _ClassroomTimeSheet({required this.initial});

  final ClassroomPeriod initial;

  @override
  State<_ClassroomTimeSheet> createState() => _ClassroomTimeSheetState();
}

class _ClassroomTimeSheetState extends State<_ClassroomTimeSheet> {
  late ClassroomPeriod _period = widget.initial;
  bool _choosingEnd = false;

  void _select(int section) => setState(() {
    if (_choosingEnd) {
      _period = (
        start: math.min(_period.start, section),
        end: math.max(_period.start, section),
      );
    } else {
      _period = (start: section, end: section);
    }
    _choosingEnd = !_choosingEnd;
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;

    return SheetLayout(
      header: SheetHeader(
        title: Text(l10n.chooseFreePeriod),
        actions: const [SheetCloseButton()],
      ),
      content: LayoutBuilder(
        builder: (context, constraints) {
          final columns =
              (constraints.maxWidth /
                      (MediaQuery.textScalerOf(context).scale(11) * 7 + 20))
                  .floor()
                  .clamp(1, 4);
          final width =
              (constraints.maxWidth - (columns - 1) * AppSpacing.xs) / columns;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.periodSelectionHint, style: theme.textTheme.bodySmall),
              const SizedBox(height: AppSpacing.md),
              Semantics(
                liveRegion: true,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: AppCorners.control,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _period.localizedTime(l10n),
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          l10n.freeThroughoutSections(
                            _period.localizedSection(l10n),
                          ),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (
                    var section = 1;
                    section <= sectionTimes.length;
                    section++
                  )
                    SizedBox(
                      width: width,
                      child: AppSelectionButton(
                        selected: _period.contains(section),
                        minimumSize: const Size(0, 54),
                        padding: const EdgeInsets.symmetric(
                          vertical: 7,
                          horizontal: 3,
                        ),
                        onPressed: () => _select(section),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.sectionShort(section),
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              (
                                start: section,
                                end: section,
                              ).localizedTime(l10n),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
      actions: OverflowBar(
        alignment: MainAxisAlignment.end,
        spacing: AppSpacing.md,
        overflowSpacing: AppSpacing.sm,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context, (period: null)),
            child: Text(l10n.allPeriods),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, (period: _period)),
            child: Text(l10n.apply),
          ),
        ],
      ),
    );
  }
}
