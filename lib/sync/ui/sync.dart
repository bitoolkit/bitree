import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/controller.dart';
import '../../core/time.dart';
import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../mooc/ui/mooc_sheet.dart';
import '../../schedule/model.dart';
import '../../school/ui/school_screen.dart';
import '../../school/ui/school_verification_dialog.dart';
import '../../school/verification.dart';
import '../../ui/app_notice.dart';
import '../../ui/design.dart';
import '../../ui/section_label.dart';
import '../../ui/selection_controls.dart';
import '../../ui/semester_dropdown.dart';
import '../../ui/sheet_layout.dart';
import '../controller.dart';
import 'sync_text.dart';

part 'custom_sync_sheet.dart';
part 'sync_progress_sheet.dart';

final _progressSheets = <SyncController, Future<void>>{};
typedef _CustomSyncSelection = ({Set<SyncTarget> targets, String? term});

/// Starts one round silently. Only account authentication requires a page.
Future<bool> startSync(
  BuildContext context,
  AppController app, {
  Set<SyncTarget>? targets,
  String? term,
  VerifySchoolLogin? verify,
}) async {
  if (app.sync.busy) {
    await showSyncProgress(context, app);
    return false;
  }
  final selected = targets ?? app.sync.defaultTargets;
  if (selected.isEmpty) return false;
  final school = selected
      .where((target) => target.usesSchoolSession)
      .firstOrNull;
  if (school != null &&
      (app.school.username == null || app.school.loginExpired)) {
    if (await openSchoolLogin(context, app.school, source: school.source) !=
            true ||
        !context.mounted) {
      return false;
    }
  }
  if (!context.mounted) return false;
  if (selected.contains(SyncTarget.mooc) && app.mooc.needsLogin) {
    if (!await showMoocAccount(context, app.mooc) || !context.mounted) {
      return false;
    }
  }
  if (!context.mounted) return false;
  final overlay = Overlay.of(context, rootOverlay: true);
  final l10n = context.l10n;
  final success = await app.sync.synchronize(
    selected,
    term: term,
    verify: verify,
  );
  if (!overlay.mounted ||
      app.sync.cancelled ||
      _progressSheets.containsKey(app.sync)) {
    return success;
  }
  showOverlayNotice(
    overlay,
    success ? l10n.syncComplete : l10n.syncPartial,
    action: success
        ? null
        : (
            label: l10n.view,
            onPressed: () {
              if (overlay.mounted) {
                unawaited(showSyncProgress(overlay.context, app));
              }
            },
          ),
  );
  return success;
}

Future<void> customizeSync(BuildContext context, AppController app) async {
  final selected = await showAppSheet<_CustomSyncSelection>(
    context: context,
    builder: (_) => _CustomSyncSheet(app: app),
  );
  if (selected == null || !context.mounted) return;
  await startSync(context, app, targets: selected.targets, term: selected.term);
}

Future<void> showSyncProgress(BuildContext context, AppController app) {
  final existing = _progressSheets[app.sync];
  if (existing != null) return existing;
  dismissAppNotice();
  final sheet = showAppSheet<void>(
    context: context,
    builder: (_) => _SyncProgressSheet(app: app),
  );
  _progressSheets[app.sync] = sheet;
  return sheet.whenComplete(() => _progressSheets.remove(app.sync));
}
