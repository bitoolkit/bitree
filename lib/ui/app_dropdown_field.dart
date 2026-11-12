import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_menu_anchor.dart';
import 'app_menu_trigger.dart';
import 'design.dart';

class AppDropdownField<T> extends StatefulWidget {
  const AppDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.entries,
    required this.onChanged,
    this.textStyle,
    this.maxLines = 1,
  });

  final String label;
  final T value;
  final List<DropdownMenuEntry<T>> entries;
  final ValueChanged<T>? onChanged;
  final TextStyle? textStyle;
  final int? maxLines;

  @override
  State<AppDropdownField<T>> createState() => _AppDropdownFieldState<T>();
}

class _AppDropdownFieldState<T> extends State<AppDropdownField<T>> {
  final _focusNode = FocusNode();
  final _selectedItem = GlobalKey();
  bool _focused = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _selectedItem.currentContext;
      if (context != null) Scrollable.ensureVisible(context, alignment: 0.5);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = widget.onChanged != null;
    final selected = widget.entries.firstWhere(
      (entry) => entry.value == widget.value,
    );
    final textStyle = widget.textStyle ?? theme.textTheme.bodyLarge;

    return LayoutBuilder(
      builder: (context, constraints) => AppMenuAnchor(
        childFocusNode: _focusNode,
        onOpen: _scrollToSelection,
        style: MenuStyle(
          minimumSize: WidgetStatePropertyAll(Size(constraints.maxWidth, 0)),
        ),
        menuChildren: [
          for (final entry in widget.entries)
            AppMenuItemButton(
              selected: entry.value == widget.value,
              key: entry.value == widget.value ? _selectedItem : null,
              autofocus: entry.value == widget.value,
              onPressed: enabled && entry.enabled
                  ? () => widget.onChanged?.call(entry.value)
                  : null,
              leadingIcon: entry.leadingIcon,
              child: DefaultTextStyle.merge(
                style: textStyle,
                child: entry.labelWidget ?? Text(entry.label),
              ),
            ),
        ],
        builder: (context, menu, isOpen) {
          void toggle() => isOpen ? menu.close() : menu.open();

          return CallbackShortcuts(
            bindings: {
              if (enabled) ...{
                const SingleActivator(LogicalKeyboardKey.arrowDown): menu.open,
                const SingleActivator(LogicalKeyboardKey.arrowUp): menu.open,
              },
            },
            child: Semantics(
              label: widget.label,
              value: selected.label.replaceAll('\n', ' '),
              button: true,
              enabled: enabled,
              expanded: isOpen,
              onTap: enabled ? toggle : null,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: appControlSize.height),
                child: InkWell(
                  focusNode: _focusNode,
                  canRequestFocus: enabled,
                  onFocusChange: (focused) =>
                      setState(() => _focused = focused),
                  onTap: enabled ? toggle : null,
                  excludeFromSemantics: true,
                  borderRadius: AppCorners.control,
                  child: ExcludeSemantics(
                    child: InputDecorator(
                      isFocused: _focused || isOpen,
                      baseStyle: textStyle,
                      decoration: InputDecoration(
                        labelText: widget.label,
                        enabled: enabled,
                        suffixIconConstraints: const BoxConstraints.tightFor(
                          width: 36,
                          height: 44,
                        ),
                        suffixIcon: AppMenuArrow(isOpen: isOpen),
                      ),
                      child: Text(
                        selected.label,
                        maxLines: widget.maxLines,
                        overflow: TextOverflow.ellipsis,
                        style: enabled
                            ? textStyle
                            : textStyle?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.38,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
