import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../ui/app_dialog.dart';
import '../../ui/external_link.dart';
import '../../updates/version.dart';
import '../settings_controller.dart';

Future<void> showBitreeAboutDialog(
  BuildContext context,
  AppSettingsController settings,
) async {
  final l10n = context.l10n;
  final version = await appVersion();
  final builtAt = appBuildTime?.toLocal();
  if (!context.mounted) return;

  var iconTaps = 0;
  Timer? resetTaps;

  await showAppDialog<void>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      final localizations = MaterialLocalizations.of(dialogContext);
      var versionLabel = version;
      if (builtAt != null) {
        final date = localizations.formatCompactDate(builtAt);
        final time = localizations.formatTimeOfDay(
          TimeOfDay.fromDateTime(builtAt),
          alwaysUse24HourFormat: true,
        );
        versionLabel += '\n${l10n.settingsBuiltAt(date, time)}';
      }
      return AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        scrollable: true,
        title: Row(
          children: [
            Semantics(
              button: true,
              label: l10n.aboutIconSemantics,
              child: GestureDetector(
                key: const ValueKey('about-icon'),
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (settings.developerMode) return;
                  resetTaps?.cancel();
                  resetTaps = Timer(const Duration(seconds: 2), () {
                    iconTaps = 0;
                  });
                  iconTaps++;
                  if (iconTaps < 5) return;
                  settings.unlockDeveloperMode();
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.developerModeEnabled)),
                  );
                },
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Image.asset(
                      'assets/brand/bitree.png',
                      width: 40,
                      height: 40,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        l10n.appName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        l10n.appChineseName,
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    versionLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.projectDescription),
            const SizedBox(height: 12),
            Text(l10n.aboutLicenseSummary, style: theme.textTheme.bodySmall),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              showLicensePage(
                context: context,
                applicationName: l10n.aboutLicenseName,
                applicationVersion: version,
                applicationIcon: Image.asset(
                  'assets/brand/bitree.png',
                  width: 40,
                  height: 40,
                ),
              );
            },
            child: Text(l10n.settingsLicenses),
          ),
          TextButton(
            onPressed: () => openExternalLink(
              dialogContext,
              Uri.https('github.com', '/bitoolkit/bitree'),
              failureTitle: l10n.aboutOpenGitHubFailed,
            ),
            child: Text(l10n.github),
          ),
          TextButton(
            key: const ValueKey('about-qq-group'),
            onPressed: () => openExternalLink(
              dialogContext,
              Uri.https('qm.qq.com', '/q/V472c8UjwQ'),
              failureTitle: l10n.aboutOpenQQGroupFailed,
            ),
            child: Text(l10n.aboutOpenQQGroup),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.close),
          ),
        ],
      );
    },
  );
  resetTaps?.cancel();
}
