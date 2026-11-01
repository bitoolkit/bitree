import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/diagnostics.dart';
import '../l10n/l10n.dart';
import 'app_dialog.dart';

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

  await showAppDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(failureTitle),
      content: SelectableText(context.l10n.openInBrowser('$url')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.close),
        ),
      ],
    ),
  );

  return false;
}
