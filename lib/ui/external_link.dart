import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/diagnostics.dart';
import '../l10n/l10n.dart';
import 'sheet_layout.dart';

Future<bool> openExternalLink(
  BuildContext context,
  Uri url, {
  required String failureTitle,
}) async {
  bool opened;
  try {
    opened = await launchUrl(url, mode: LaunchMode.externalApplication);
  } on PlatformException catch (failure, stack) {
    AppDiagnostics.instance.error('打开外部链接', failure, stack);
    opened = false;
  }

  if (opened || !context.mounted) return opened;

  await showAppSheet<void>(
    context: context,
    builder: (context) => SheetLayout(
      header: SheetHeader(
        title: Text(failureTitle),
        actions: const [SheetCloseButton()],
      ),
      content: SelectableText(context.l10n.openInBrowser('$url')),
      actions: SheetActionBar.primary(
        primary: FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.close),
        ),
      ),
    ),
  );

  return false;
}
