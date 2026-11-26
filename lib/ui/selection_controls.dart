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
    required this.onToggleAll,
    required this.onClear,
  }) : assert(selectedCount >= 0),
       assert(totalCount >= selectedCount);

  final int selectedCount;
  final int totalCount;
  final String summary;
  final ValueChanged<bool>? onToggleAll;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final allSelected = totalCount > 0 && selectedCount == totalCount;
    final noneSelected = selectedCount == 0;
    final toggleAll = totalCount > 0 && onToggleAll != null
        ? () => onToggleAll!(!allSelected)
        : null;

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
              onChanged: toggleAll == null ? null : (_) => toggleAll(),
            ),
            Expanded(
              child: InkWell(
                onTap: toggleAll,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: AppSpacing.sm,
                  ),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xxs,
                    children: [
                      Text(
                        l10n.selectAll,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      Text(
                        summary,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: TextButton(
                onPressed: onClear,
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

class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final Map<T, String> options;
  final T value;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final keys = options.keys.toList(growable: false);
    final selectedIndex = keys.indexOf(value);
    final alignmentX = keys.length <= 1
        ? 0.0
        : -1.0 + 2.0 * selectedIndex / (keys.length - 1);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: AppCorners.control,
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.05)
              : scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            if (selectedIndex >= 0 && keys.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedAlign(
                    alignment: AlignmentDirectional(alignmentX, 0),
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: FractionallySizedBox(
                      widthFactor: 1 / keys.length,
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: dark
                              ? scheme.surfaceContainerHighest
                              : scheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(7),
                          border: dark
                              ? Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
                                )
                              : null,
                          boxShadow: dark
                              ? null
                              : const [
                                  BoxShadow(
                                    color: Color(0x1014171D),
                                    blurRadius: 3,
                                    offset: Offset(0, 1),
                                  ),
                                  BoxShadow(
                                    color: Color(0x0614171D),
                                    blurRadius: 1,
                                    offset: Offset(0, 0.5),
                                  ),
                                ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            SegmentedButton<T>(
              expandedInsets: EdgeInsets.zero,
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                backgroundColor: Colors.transparent,
                selectedBackgroundColor: Colors.transparent,
                foregroundColor: scheme.onSurfaceVariant,
                selectedForegroundColor: scheme.onSurface,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                visualDensity: VisualDensity.standard,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              segments: [
                for (final option in options.entries)
                  ButtonSegment(
                    value: option.key,
                    label: Text(
                      option.value,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: option.key == value
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
              ],
              selected: {value},
              onSelectionChanged: onChanged == null
                  ? null
                  : (selection) => onChanged!(selection.single),
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
    this.leading,
    this.enabled = true,
  });

  final bool value;
  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
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
    secondary: leading,
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
