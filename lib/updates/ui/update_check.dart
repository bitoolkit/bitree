import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/diagnostics.dart';
import '../../l10n/l10n.dart';
import '../../ui/app_notice.dart';
import '../repository.dart';
import '../version.dart';
import 'update_sheet.dart';

Future<void> checkForUpdates(
  BuildContext context, {
  bool silent = false,
}) async {
  final l10n = context.l10n;
  try {
    final updates = UpdateRepository(SharedPreferencesAsync(), l10n: l10n);
    final installed = await appVersion();
    final releases = await updates.check(
      installed,
      builtAt: appBuildTime,
      automatic: silent,
    );

    if (!context.mounted) return;
    if (silent && !ModalRoute.of(context)!.isCurrent) return;

    if (releases.isEmpty) {
      if (!silent) {
        showAppNotice(context, l10n.latestVersion);
      }
      return;
    }

    await showUpdateSheet(
      context,
      releases: releases,
      preferDevelopment: installed.contains('-'),
    );

    await updates.markNotified(releases);
  } on Exception catch (failure, stack) {
    if (silent || !context.mounted) {
      AppDiagnostics.instance.error('检查更新', failure, stack);
    } else {
      AppDiagnostics.instance.report(
        '检查更新',
        failure,
        stack,
        message: l10n.updateCheckFailed,
      );
    }
  }
}
