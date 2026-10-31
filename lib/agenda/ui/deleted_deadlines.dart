import 'package:flutter/material.dart';

import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../ui/app_notice.dart';
import '../../ui/design.dart';
import '../../ui/sheet_layout.dart';
import '../controller.dart';
import '../model.dart';

Future<void> showDeletedDeadlines(
  BuildContext context,
  AgendaController controller,
) => showAppSheet<void>(
  context: context,
  builder: (sheetContext) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final l10n = context.l10n;
      final entries = controller.deletedDeadlines.toList()
        ..sort((a, b) => b.startsAt.compareTo(a.startsAt));

      Future<void> restore([AgendaEntry? entry]) async {
        final saved = entry == null
            ? await controller.restoreDeletedDeadlines()
            : await controller.restore(entry);
        if (!sheetContext.mounted) return;
        if (!saved) return;
        showAppNotice(
          context,
          entry == null
              ? l10n.deletedDeadlinesRestoredAll
              : l10n.deletedDeadlinesRestored(entry.title),
        );
        if (controller.deletedDeadlines.isEmpty &&
            ModalRoute.of(sheetContext)?.isCurrent == true) {
          Navigator.pop(sheetContext);
        }
      }

      return SheetLayout(
        header: SheetHeader(
          title: Text(l10n.deletedDeadlinesTitle),
          actions: const [SheetCloseButton()],
        ),
        contentPadding: appSheetListPadding,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (entries.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text(l10n.deletedDeadlinesNone),
              ),
            for (final entry in entries)
              ListTile(
                key: ValueKey(entry.id),
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                title: Text(
                  entry.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  [
                    [
                      entry.source?.localizedLabel(l10n) ?? l10n.deadlineManual,
                      if (entry.course.isNotEmpty) entry.course,
                    ].join('  '),
                    '${localizedAgendaDate(l10n, entry.startsAt)} '
                        '${localizedAgendaTime(l10n, entry)}',
                  ].join('\n'),
                ),
                trailing: TextButton(
                  onPressed: controller.busy ? null : () => restore(entry),
                  child: Text(l10n.deletedDeadlinesRestoreAction),
                ),
              ),
          ],
        ),
        actions: FilledButton(
          onPressed: controller.busy || entries.isEmpty
              ? null
              : () => restore(),
          child: Text(l10n.deletedDeadlinesRestoreAll),
        ),
      );
    },
  ),
);
