import 'package:flutter/material.dart';

import '../../app/controller.dart';
import '../../core/time.dart';
import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../ui/app_notice.dart';
import '../../ui/swipe_action_tile.dart';
import '../model.dart';
import 'agenda_detail.dart';
import 'agenda_operations.dart';
import 'calendar_list.dart';
import 'completion_text.dart';

class AgendaListTile extends StatelessWidget {
  const AgendaListTile({
    super.key,
    required this.controller,
    required this.entry,
    required this.now,
    this.onTap,
  });

  final AppController controller;
  final AgendaEntry entry;
  final DateTime now;
  final VoidCallback? onTap;

  Future<bool> _complete(BuildContext context, {bool haptic = false}) async {
    final saved = await toggleAgendaDone(
      controller.agenda,
      entry,
      haptic: haptic,
    );
    if (!saved && context.mounted) {
      showAppNotice(context, context.l10n.operationSaveFailed);
    }
    return saved;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final title = localizedAgendaTitle(l10n, entry);
    final subtitle = [
      if (entry.course.isNotEmpty)
        entry.course
      else if (entry.source != null)
        entry.source!.localizedLabel(l10n),
      if (entry.location.isNotEmpty) entry.location,
    ].join('  ');
    final description = localizedAgendaNotes(l10n, entry).trim();
    final hasDetails = description.isNotEmpty || subtitle.isNotEmpty;
    final dueToday =
        entry.isDeadline &&
        !entry.done &&
        calendarDate(entry.startsAt) == calendarDate(now);
    final timeColor = entry.overdue(now)
        ? scheme.error
        : dueToday
        ? scheme.primary
        : scheme.onSurface;
    final caption = localizedAgendaTimeCaption(l10n, entry, now);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SwipeActionTile(
        enabled: !controller.agenda.busy,
        leftAction: TileSwipeAction(
          label: l10n.agendaSwipeDelete,
          releaseLabel: l10n.agendaSwipeDeleteRelease,
          icon: Icons.delete_outline,
          background: scheme.error,
          foreground: scheme.onError,
          onInvoke: () =>
              deleteAgendaEntry(context, controller, entry, confirm: false),
        ),
        rightAction: entry.isDeadline
            ? TileSwipeAction(
                label: entry.done
                    ? l10n.agendaSwipeRestore
                    : l10n.agendaSwipeDone,
                releaseLabel: entry.done
                    ? l10n.agendaSwipeRestoreRelease
                    : l10n.agendaSwipeDoneRelease,
                icon: entry.done ? Icons.undo_rounded : Icons.check_rounded,
                background: scheme.primaryContainer,
                foreground: scheme.onPrimaryContainer,
                onInvoke: () => _complete(context),
              )
            : null,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            hoverColor: Colors.transparent,
            onTap: onTap ?? () => showAgendaEntry(context, controller, entry),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: hasDetails
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
                children: [
                  SizedBox.square(
                    dimension: 44,
                    child: entry.isDeadline
                        ? Tooltip(
                            message: entry.done
                                ? l10n.agendaMarkUndone
                                : l10n.agendaMarkDone,
                            child: Checkbox(
                              value: entry.done,
                              shape: const CircleBorder(),
                              onChanged: controller.agenda.busy
                                  ? null
                                  : (_) => _complete(context, haptic: true),
                            ),
                          )
                        : Icon(
                            agendaIcon(entry.kind),
                            size: 22,
                            color: scheme.onSurfaceVariant,
                          ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CompletionText(
                          title,
                          completed: entry.done,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        for (final detail in [description, subtitle])
                          if (detail.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              detail,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.45,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: MediaQuery.textScalerOf(context).scale(72),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          localizedAgendaClock(l10n, entry),
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.3,
                            fontWeight: FontWeight.w500,
                            color: timeColor,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        if (caption.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            caption,
                            maxLines: 2,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.4,
                              color: entry.overdue(now)
                                  ? scheme.error
                                  : dueToday
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
