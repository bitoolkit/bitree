import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../ui/app_dialog.dart';
import '../../ui/design.dart';
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
      final linkStyle = TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      );
      return AppDialog(
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
                  resetTaps?.cancel();
                  resetTaps = null;
                  iconTaps = 0;
                  settings.unlockDeveloperMode();
                  // The dialog stays open on purpose: taps that keep coming
                  // after the unlock would otherwise land on the settings page
                  // behind it. The unlock is confirmed inside the dialog.
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
                      Text(l10n.appName),
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
                  ListenableBuilder(
                    listenable: settings,
                    builder: (context, _) {
                      if (!settings.developerMode) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          l10n.developerModeEnabled,
                          key: const ValueKey('about-developer-mode-note'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      );
                    },
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
            style: linkStyle,
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
            style: linkStyle,
            onPressed: () => openExternalLink(
              dialogContext,
              Uri.https('github.com', '/bitoolkit/bitree'),
              failureTitle: l10n.aboutOpenGitHubFailed,
            ),
            child: Text(l10n.github),
          ),
          TextButton(
            key: const ValueKey('about-qq-group'),
            style: linkStyle,
            onPressed: () => openExternalLink(
              dialogContext,
              Uri.https('qm.qq.com', '/q/84t3ZHKMpO'),
              failureTitle: l10n.aboutOpenQQGroupFailed,
            ),
            child: Text(l10n.aboutOpenQQGroup),
          ),
        ],
      );
    },
  );
  resetTaps?.cancel();
}
