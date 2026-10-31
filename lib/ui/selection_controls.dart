import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'design.dart';

/// Compact select-all header shared by multi-select sheets and forms.
class AppSelectionBar extends StatelessWidget {
  const AppSelectionBar({
    super.key,
    required this.selectedCount,
    required this.totalCount,
    required this.summary,
    required this.onSelectAll,
    required this.onClear,
    this.enabled = true,
  }) : assert(selectedCount >= 0),
       assert(totalCount >= selectedCount);

  final int selectedCount;
  final int totalCount;
  final String summary;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final allSelected = totalCount > 0 && selectedCount == totalCount;
    final noneSelected = selectedCount == 0;
    final canToggle = enabled && totalCount > 0;

    void toggleAll() {
      if (allSelected) {
        onClear();
      } else {
        onSelectAll();
      }
    }

    return Material(
      color: scheme.surfaceContainerLow,
      shape: appControlShape.copyWith(
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Row(
          children: [
            Checkbox(
              value: allSelected ? true : (noneSelected ? false : null),
              tristate: true,
              onChanged: canToggle ? (_) => toggleAll() : null,
            ),
            Expanded(
              child: InkWell(
                onTap: canToggle ? toggleAll : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.selectAll,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton(
                onPressed: enabled && !noneSelected ? onClear : null,
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: Text(l10n.clearSelection),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact, consistently aligned row for a single checkbox choice.
class AppSelectionTile extends StatelessWidget {
  const AppSelectionTile({
    super.key,
    required this.value,
    required this.title,
    required this.onChanged,
    this.subtitle,
  });

  final bool value;
  final Widget title;
  final Widget? subtitle;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) => CheckboxListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    controlAffinity: ListTileControlAffinity.leading,
    dense: true,
    visualDensity: VisualDensity.compact,
    title: title,
    subtitle: subtitle,
    value: value,
    onChanged: onChanged,
  );
}
