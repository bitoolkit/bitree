import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../ui/app_dialog.dart';
import '../../ui/design.dart';
import '../../ui/external_link.dart';
import '../../ui/selection_controls.dart';
import '../release.dart';

Future<void> showUpdateDialog(
  BuildContext context, {
  required List<AppRelease> releases,
  required bool preferDevelopment,
}) => showAppDialog<void>(
  context: context,
  builder: (_) =>
      UpdateDialog(releases: releases, preferDevelopment: preferDevelopment),
);

class UpdateDialog extends StatefulWidget {
  const UpdateDialog({
    super.key,
    required this.releases,
    required this.preferDevelopment,
  });

  final List<AppRelease> releases;
  final bool preferDevelopment;

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  int _selected = 0;

  AppRelease get _release => widget.releases[_selected];

  @override
  void initState() {
    super.initState();
    final preferred = widget.releases.indexWhere(
      (release) => release.isDevelopment == widget.preferDevelopment,
    );
    if (preferred != -1) _selected = preferred;
  }

  Future<void> _download() async {
    final l10n = context.l10n;
    final opened = await openExternalLink(
      context,
      _release.downloadUrl,
      failureTitle: l10n.unableOpenDownload,
    );
    if (opened && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final channel = _release.isDevelopment
        ? l10n.developmentBuild
        : l10n.stableBuild;
    final actionStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
      textStyle: WidgetStatePropertyAll(
        theme.textTheme.labelMedium!.copyWith(fontSize: 13),
      ),
    );

    return AppDialog(
      title: Text(l10n.updateAvailable),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.releases.length > 1) ...[
            AppSegmentedControl<int>(
              options: {
                for (final (index, release) in widget.releases.indexed)
                  index: release.isDevelopment
                      ? l10n.developmentBuild
                      : l10n.stableBuild,
              },
              value: _selected,
              onChanged: (value) => setState(() => _selected = value),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Text(
            l10n.releaseVersion(channel, _release.version),
            style: theme.textTheme.titleMedium,
          ),
          if (localizedReleaseNotes(l10n, _release.notes) case final notes
              when notes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            MarkdownBody(
              data: notes,
              selectable: true,
              styleSheet: MarkdownStyleSheet.fromTheme(theme)
                  .copyWith(h2: theme.textTheme.titleSmall),
              onTapLink: (_, href, _) async {
                if (href == null) return;
                await openExternalLink(
                  context,
                  Uri.parse(href),
                  failureTitle: l10n.unableOpenLink,
                );
              },
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          style: actionStyle,
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.later),
        ),
        TextButton(
          style: actionStyle,
          onPressed: () => openExternalLink(
            context,
            _release.url,
            failureTitle: l10n.unableOpenReleasePage,
          ),
          child: Text(l10n.releasePage),
        ),
        FilledButton(
          style: actionStyle,
          onPressed: _download,
          child: Text(
            _release.isDevelopment
                ? l10n.downloadDevelopment
                : l10n.downloadStable,
          ),
        ),
      ],
    );
  }
}
