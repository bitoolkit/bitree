import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../ui/sheet_layout.dart';

Future<void> showWidgetGuide(BuildContext context) => showAppSheet<void>(
  context: context,
  builder: (context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    Widget step(int number, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$number',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );

    return SheetLayout(
      header: SheetHeader(
        title: Text(l10n.widgetGuideTitle),
        actions: const [SheetCloseButton()],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _WidgetSize(columns: 1, label: l10n.widgetSingleColumn),
                _WidgetSize(columns: 2, label: l10n.widgetDoubleColumn),
              ],
            ),
          ),
          const SizedBox(height: 8),
          step(1, l10n.widgetStepOpen),
          step(2, l10n.widgetStepFind),
          step(3, l10n.widgetStepScroll),
          const SizedBox(height: 8),
          Text(
            l10n.widgetGuideTomorrow,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: SheetActionBar.primary(
        primary: FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.gotIt),
        ),
      ),
    );
  },
);

class _WidgetSize extends StatelessWidget {
  const _WidgetSize({required this.columns, required this.label});

  final int columns;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Container(
            width: columns == 1 ? 64 : 112,
            height: 64,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              spacing: 6,
              children: List.generate(
                columns,
                (_) => Expanded(
                  child: Column(
                    spacing: 6,
                    children: List.generate(
                      2,
                      (_) => Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: theme.textTheme.labelLarge),
      ],
    );
  }
}
