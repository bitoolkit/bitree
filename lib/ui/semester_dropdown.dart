import 'package:flutter/material.dart';

import '../l10n/formats.dart';
import '../l10n/l10n.dart';
import 'app_dropdown_field.dart';
import 'app_menu_anchor.dart';
import 'app_menu_trigger.dart';

List<String> orderedSemesterTerms(
  Iterable<String> terms, {
  String? currentTerm,
}) {
  final unique = {
    for (final term in terms)
      if (term.trim() case final value when value.isNotEmpty) value,
  };
  final current = currentTerm?.trim();
  final remaining = unique.where((term) => term != current).toList()
    ..sort((first, second) => second.compareTo(first));
  return [
    if (current != null && unique.contains(current)) current,
    ...remaining,
  ];
}

class SemesterDropdown extends StatelessWidget {
  const SemesterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.terms,
    required this.onChanged,
    this.currentTerm,
    this.includeAll = false,
    this.compact = false,
  });

  final String label;
  final String? value;
  final List<String> terms;
  final String? currentTerm;
  final ValueChanged<String?> onChanged;
  final bool includeAll;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ordered = orderedSemesterTerms(terms, currentTerm: currentTerm);
    final selected = value != null && ordered.contains(value)
        ? value
        : includeAll
        ? null
        : ordered.firstOrNull;

    String labelFor(String? term) =>
        term == null ? l10n.allSemesters : localizedTerm(l10n, term);

    final values = <String?>[...ordered, if (includeAll) null];
    if (compact) {
      return AppMenuAnchor(
        menuChildren: [
          for (final term in values)
            Semantics(
              selected: selected == term,
              child: AppMenuItemButton(
                onPressed: () => onChanged(term),
                trailingIcon: selected == term
                    ? const Icon(Icons.check_rounded, size: 18)
                    : const SizedBox(width: 18),
                child: Text(labelFor(term)),
              ),
            ),
        ],
        builder: (context, menu, isOpen) => AppMenuTrigger(
          label: labelFor(selected),
          semanticsLabel: label,
          isOpen: isOpen,
          onPressed: () => isOpen ? menu.close() : menu.open(),
        ),
      );
    }

    return AppDropdownField<String?>(
      label: label,
      value: selected,
      onChanged: onChanged,
      entries: [
        for (final term in values)
          DropdownMenuEntry(value: term, label: labelFor(term)),
      ],
    );
  }
}
