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
  });

  final String label;
  final String? value;
  final List<String> terms;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppDropdownField<String>(
      label: label,
      value: value != null && terms.contains(value) ? value! : terms.first,
      onChanged: onChanged,
      entries: [
        for (final term in terms)
          DropdownMenuEntry(
            value: term,
            label: localizedTerm(context.l10n, term),
          ),
      ],
    );
  }
}
