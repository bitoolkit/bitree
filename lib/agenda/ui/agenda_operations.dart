import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/controller.dart';
import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../ui/app_dialog.dart';
import '../../ui/app_notice.dart';
import '../controller.dart';
import '../model.dart';

Future<bool> toggleAgendaDone(
  AgendaController controller,
  AgendaEntry entry, {
  bool haptic = true,
}) async {
  final saved = await controller.save(entry.copyWith(done: !entry.done));
  if (saved && haptic) {
    HapticFeedback.selectionClick();
  }
  return saved;
}

Future<bool> deleteAgendaEntry(
  BuildContext context,
  AppController controller,
  AgendaEntry entry, {
  bool confirm = true,
}) async {
  final l10n = context.l10n;
  // The originating sheet can close while the undo action remains visible.
  final overlay = Overlay.of(context, rootOverlay: true);
  if (confirm) {
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.agendaDeleteQuestion(entry.kind.localizedLabel(l10n)),
      body: entry.title,
      confirmLabel: l10n.delete,
      destructive: true,
    );
    if (!confirmed) return false;
  }
  final deleted = await controller.agenda.delete(entry);
  if (!overlay.mounted) return deleted;
  if (!deleted) return false;

  Future<void> restore() async {
    final restored = await controller.agenda.restore(entry);
    if (!overlay.mounted) return;
    if (restored) {
      showOverlayNotice(overlay, l10n.agendaRestored(entry.title));
    }
  }

  showOverlayNotice(
    overlay,
    l10n.agendaDeleted(entry.title),
    action: (label: l10n.undo, onPressed: restore),
  );
  return true;
}
