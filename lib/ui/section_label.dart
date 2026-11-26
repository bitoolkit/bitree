import 'package:flutter/material.dart';

/// Compact section heading used above related controls and choices.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader(this.label, {super.key, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 12.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}
