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
    this.error,
  });

  final String title;
  final GlobalKey<FormState> formKey;
  final bool saving;
  final VoidCallback onSave;
  final Widget saveLabel;
  final Widget child;
  final VoidCallback? onDelete;
  final String? error;

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
                  child: Text(
                    message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Row(
                children: [
                  if (onDelete != null) ...[
                    IconButton(
                      tooltip: context.l10n.delete,
                      onPressed: saving ? null : onDelete,
                      color: Theme.of(context).colorScheme.error,
                      icon: const Icon(Icons.delete_outline),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: FilledButton(
                      onPressed: saving ? null : onSave,
                      child: saveLabel,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
