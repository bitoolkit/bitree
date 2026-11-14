import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'design.dart';

/// Shows a focused task over the current page and returns its result.
///
/// Use dialogs for a decision, a short input, brief reference content, or a
/// bounded one-time announcement.
/// Use `showAppSheet` for object details, long forms, batch tools, and progress.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) => showDialog<T>(
  context: context,
  barrierDismissible: barrierDismissible,
  builder: builder,
);

class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    this.title,
    required this.content,
    this.actions,
    this.semanticLabel,
  });

  final Widget? title;
  final Widget content;
  final List<Widget>? actions;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: title,
    content: content,
    actions: actions,
    semanticLabel: semanticLabel,
    scrollable: true,
    contentPadding: EdgeInsets.fromLTRB(
      AppSpacing.xl,
      title == null ? AppSpacing.xl : AppSpacing.md,
      AppSpacing.xl,
      actions == null ? AppSpacing.xl : AppSpacing.lg,
    ),
    actionsOverflowButtonSpacing: AppSpacing.sm,
  );
}

/// Shared confirmation dialog for actions that need one explicit decision.
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final confirmed = await showAppDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final scheme = Theme.of(dialogContext).colorScheme;
      return AppDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  )
                : null,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
