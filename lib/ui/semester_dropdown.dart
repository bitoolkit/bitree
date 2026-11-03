import 'package:flutter/material.dart';

import '../l10n/formats.dart';
import '../l10n/l10n.dart';
import 'app_dropdown_field.dart';

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
  });

  final String label;
  final String? value;
  final List<String> terms;
  final String? currentTerm;
  final ValueChanged<String?> onChanged;
  final bool includeAll;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ordered = orderedSemesterTerms(terms, currentTerm: currentTerm);
    final selected = value != null && ordered.contains(value)
        ? value
        : includeAll
        ? null
        : ordered.firstOrNull;

    return AppDropdownField<String?>(
      label: label,
      value: selected,
      onChanged: onChanged,
      entries: [
        for (final term in ordered)
          DropdownMenuEntry(value: term, label: localizedTerm(l10n, term)),
        if (includeAll)
          DropdownMenuEntry(value: null, label: l10n.allSemesters),
      ],
    );
  }
}
