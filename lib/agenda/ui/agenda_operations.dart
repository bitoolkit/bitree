import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../automation/presentation.dart';
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
  if (entry is ScriptGenerated) return false;
  final original = controller.entries
      .where((saved) => saved.id == entry.id)
      .firstOrNull;
  if (original == null) return false;
  final saved = await controller.save(original.copyWith(done: !original.done));
  if (saved && haptic) {
    HapticFeedback.selectionClick();
  }
  return saved;
}

Future<bool> deleteAgendaEntry(
  BuildContext context,
  AgendaController controller,
  AgendaEntry entry, {
  bool confirm = true,
}) async {
  if (entry is ScriptGenerated) return false;
  final l10n = context.l10n;
  final original =
      controller.entries.where((saved) => saved.id == entry.id).firstOrNull ??
      entry;
  final title = localizedAgendaTitle(l10n, entry);
  // The originating sheet can close while the undo action remains visible.
  final overlay = Overlay.of(context, rootOverlay: true);
  if (confirm) {
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.agendaDeleteQuestion(entry.kind.localizedLabel(l10n)),
      body: title,
      confirmLabel: l10n.delete,
      destructive: true,
    );
    if (!confirmed) return false;
  }
  final deleted = await controller.delete(entry);
  if (!overlay.mounted) return deleted;
  if (!deleted) {
    showOverlayNotice(overlay, l10n.operationDeleteFailed);
    return false;
  }

  Future<void> restore() async {
    final restored = await controller.restore(original);
    if (!overlay.mounted) return;
    if (restored) {
      showOverlayNotice(overlay, l10n.agendaRestored(title));
    } else {
      showOverlayNotice(overlay, l10n.operationRestoreFailed);
    }
  }

  showOverlayNotice(
    overlay,
    l10n.agendaDeleted(title),
    action: (label: l10n.undo, onPressed: restore),
  );
  return true;
}
