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
        constraints: const BoxConstraints(minHeight: appControlHeight),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          l10n.selectAll,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        flex: 2,
                        child: Text(
                          summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: TextButton(
                onPressed: enabled && !noneSelected ? onClear : null,
                style: TextButton.styleFrom(
                  minimumSize: appControlSize,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
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
    this.trailing,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
    this.enabled = true,
  });

  final bool value;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final ValueChanged<bool?>? onChanged;
  final EdgeInsetsGeometry contentPadding;
  final bool enabled;

  @override
  Widget build(BuildContext context) => CheckboxListTile(
    contentPadding: contentPadding,
    controlAffinity: ListTileControlAffinity.leading,
    dense: true,
    visualDensity: VisualDensity.compact,
    minTileHeight: appControlHeight,
    minVerticalPadding: 0,
    title: title,
    subtitle: subtitle,
    secondary: trailing,
    value: value,
    onChanged: enabled ? onChanged : null,
  );
}

/// A compact row for an immediate on/off setting rather than a selection.
class AppToggleTile extends StatelessWidget {
  const AppToggleTile({
    super.key,
    required this.value,
    required this.title,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
  });

  final bool value;
  final Widget title;
  final Widget? subtitle;
  final ValueChanged<bool>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
    dense: true,
    visualDensity: VisualDensity.compact,
    minTileHeight: appControlHeight,
    minVerticalPadding: 0,
    title: title,
    subtitle: subtitle,
    value: value,
    onChanged: enabled ? onChanged : null,
  );
}

/// A shared selected-state control for compact choice grids.
class AppSelectionButton extends StatelessWidget {
  const AppSelectionButton({
    super.key,
    required this.selected,
    required this.onPressed,
    required this.child,
    this.minimumSize = const Size(0, appControlHeight),
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.sm,
    ),
  });

  const AppSelectionButton.compact({
    super.key,
    required this.selected,
    required this.onPressed,
    required this.child,
  }) : minimumSize = const Size(0, appControlHeight),
       padding = const EdgeInsets.symmetric(
         horizontal: AppSpacing.sm,
         vertical: AppSpacing.xs,
       );

  final bool selected;
  final VoidCallback? onPressed;
  final Widget child;
  final Size minimumSize;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: minimumSize,
          padding: padding,
          backgroundColor: selected
              ? scheme.primaryContainer
              : scheme.surfaceContainerLow,
          foregroundColor: selected
              ? scheme.onPrimaryContainer
              : scheme.onSurface,
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: child,
      ),
    );
  }
}
