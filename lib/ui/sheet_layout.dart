import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

class SheetCloseButton extends StatelessWidget {
  const SheetCloseButton({super.key, this.onPressed, this.enabled = true});

  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: context.l10n.close,
    onPressed: enabled
        ? (onPressed ?? () => Navigator.maybePop(context))
        : null,
    icon: const Icon(Icons.close_rounded, size: 20),
  );
}

class SheetHeader extends StatelessWidget {
  const SheetHeader({super.key, required this.title, required this.actions});

  final Widget title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 0, 8, 8),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: DefaultTextStyle.merge(
              style: Theme.of(context).textTheme.titleLarge,
              child: title,
            ),
          ),
        ),
        ...actions,
      ],
    ),
  );
}

class SheetLayout extends StatelessWidget {
  const SheetLayout({
    super.key,
    required this.content,
    this.header,
    this.actions,
  });

  final Widget content;
  final Widget? header;
  final Widget? actions;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ?header,
      Flexible(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: content,
        ),
      ),
      if (actions != null)
        DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: actions!,
        ),
    ],
  );
}
