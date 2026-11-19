import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'sheet_layout.dart';

class EditorSheet extends StatelessWidget {
  const EditorSheet({
    super.key,
    required this.title,
    required this.formKey,
    required this.saving,
    required this.onSave,
    required this.saveLabel,
    required this.child,
    this.onDelete,
    this.onBack,
    this.error,
    this.errorAction,
  });

  final String title;
  final GlobalKey<FormState> formKey;
  final bool saving;
  final VoidCallback onSave;
  final Widget saveLabel;
  final Widget child;
  final VoidCallback? onDelete;
  final VoidCallback? onBack;
  final String? error;
  final Widget? errorAction;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !saving,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SheetLayout(
          header: SheetHeader(
            leading: onBack == null
                ? null
                : IconButton(
                    tooltip: MaterialLocalizations.of(context)
                        .backButtonTooltip,
                    onPressed: saving ? null : onBack,
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                  ),
            title: Text(title),
            actions: [SheetCloseButton(enabled: !saving)],
          ),
          content: Form(key: formKey, child: child),
          actions: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error case final message?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      if (errorAction case final action?) ...[
                        const SizedBox(height: 4),
                        Align(alignment: Alignment.centerLeft, child: action),
                      ],
                    ],
                  ),
                ),
              SheetActionBar.split(
                leading: onDelete == null
                    ? null
                    : IconButton(
                        tooltip: context.l10n.delete,
                        onPressed: saving ? null : onDelete,
                        color: Theme.of(context).colorScheme.error,
                        icon: const Icon(Icons.delete_outline),
                      ),
                primary: FilledButton(
                  onPressed: saving ? null : onSave,
                  child: saveLabel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
