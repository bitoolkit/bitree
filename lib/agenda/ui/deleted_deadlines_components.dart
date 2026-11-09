part of 'deleted_deadlines.dart';

class _RecoverySelectionBar extends StatelessWidget {
  const _RecoverySelectionBar({
    required this.selectedCount,
    required this.totalCount,
    required this.visible,
    required this.selected,
    required this.enabled,
    required this.onToggleVisible,
    required this.onClear,
  });

  final int selectedCount;
  final int totalCount;
  final List<AgendaEntry> visible;
  final Set<String> selected;
  final bool enabled;
  final VoidCallback onToggleVisible;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final allVisibleSelected =
        visible.isNotEmpty &&
        visible.every((entry) => selected.contains(entry.id));
    final noneVisibleSelected =
        visible.isEmpty ||
        visible.every((entry) => !selected.contains(entry.id));
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.md, 0),
      child: Row(
        children: [
          Checkbox(
            value: allVisibleSelected
                ? true
                : noneVisibleSelected
                ? false
                : null,
            tristate: true,
            onChanged: enabled && visible.isNotEmpty
                ? (_) => onToggleVisible()
                : null,
          ),
          Expanded(
            child: InkWell(
              borderRadius: AppCorners.control,
              onTap: enabled && visible.isNotEmpty ? onToggleVisible : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Row(
                  children: [
                    Text(
                      l10n.selectAll,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Flexible(
                      child: Text(
                        l10n.deletedDeadlinesSelectionCount(
                          selectedCount,
                          totalCount,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: enabled && selectedCount > 0 ? onClear : null,
            child: Text(l10n.clearSelection),
          ),
        ],
      ),
    );
  }
}

class _RecoveryDateHeader extends StatelessWidget {
  const _RecoveryDateHeader({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.lg,
      AppSpacing.lg,
      AppSpacing.xs,
    ),
    child: Text(
      localizedAgendaDate(context.l10n, date),
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _DeletedDeadlineTile extends StatelessWidget {
  const _DeletedDeadlineTile({
    super.key,
    required this.entry,
    required this.selected,
    required this.enabled,
    required this.onChanged,
    required this.onRestore,
  });

  final AgendaEntry entry;
  final bool selected;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final source = entry.source?.localizedLabel(l10n) ?? l10n.deadlineManual;
    final metadata = [
      source,
      if (entry.course.isNotEmpty) entry.course,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Material(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: .48)
            : Colors.transparent,
        borderRadius: AppCorners.control,
        child: InkWell(
          borderRadius: AppCorners.control,
          onTap: enabled ? () => onChanged(!selected) : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs,
              AppSpacing.xs,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: selected,
                  onChanged: enabled
                      ? (value) => onChanged(value ?? false)
                      : null,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                localizedAgendaTitle(l10n, entry),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Text(
                              localizedAgendaTime(l10n, entry),
                              textAlign: TextAlign.end,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                metadata,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ),
                            Tooltip(
                              message: l10n.deletedDeadlinesRestoreAction,
                              child: TextButton(
                                onPressed: enabled ? onRestore : null,
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(56, 36),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                  ),
                                ),
                                child: Text(l10n.deletedDeadlinesRestoreAction),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyRecoveryList extends StatelessWidget {
  const _EmptyRecoveryList({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 40,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}
