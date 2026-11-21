part of 'sync.dart';

class _CustomSyncSheet extends StatefulWidget {
  const _CustomSyncSheet({required this.app});
  final AppController app;
  @override
  State<_CustomSyncSheet> createState() => _CustomSyncSheetState();
}

class _CustomSyncSheetState extends State<_CustomSyncSheet> {
  late final _availableTargets = widget.app.sync.bulkTargets;
  final _selected = <SyncTarget>{};
  late final List<String> _terms;
  String? _term;

  bool get _usesTerm =>
      _selected.contains(SyncTarget.schedule) ||
      _selected.contains(SyncTarget.exams);

  @override
  void initState() {
    super.initState();
    final currentTerm = semesterAt(
      widget.app.timetable.schedules,
      campusNow(),
    )?.term;
    _terms = orderedSemesterTerms(
      widget.app.timetable.terms,
      currentTerm: currentTerm,
    );
    _term =
        currentTerm ??
        widget.app.timetable.schedule?.term ??
        _terms.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mooc = widget.app.mooc;
    final moocSubtitle = mooc.needsLogin
        ? Text(
            mooc.status.localizedLabel(l10n),
            style: theme.textTheme.bodySmall?.copyWith(
              color: mooc.status == MoocStatus.expired
                  ? scheme.error
                  : scheme.onSurfaceVariant,
            ),
          )
        : null;

    return SheetLayout(
      header: SheetHeader(
        title: Text(l10n.customSync),
        actions: const [SheetCloseButton()],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionHeader(l10n.syncSchoolData),
          _SyncTargetChoices(
            targets: _availableTargets.where(
              (target) => target.category == SyncCategory.schoolData,
            ),
            selected: _selected,
            onChanged: _setSelected,
          ),
          if (_usesTerm && _terms.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            SemesterDropdown(
              label: l10n.syncTerm,
              value: _term,
              terms: _terms,
              onChanged: (term) => setState(() => _term = term),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          AppSectionHeader(l10n.syncDeadlineData),
          _SyncTargetChoices(
            targets: _availableTargets.where(
              (target) => target.category == SyncCategory.deadlineData,
            ),
            selected: _selected,
            subtitleFor: (target) =>
                target == SyncTarget.mooc ? moocSubtitle : null,
            onChanged: _setSelected,
          ),
        ],
      ),
      actions: SheetActionBar.split(
        leading: TextButton(
          onPressed: () => setState(() {
            if (_selected.isEmpty) {
              _selected.addAll(_availableTargets);
            } else {
              _selected.clear();
            }
          }),
          child: Text(_selected.isEmpty ? l10n.selectAll : l10n.clearSelection),
        ),
        primary: FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.pop(context, (
                  targets: Set<SyncTarget>.unmodifiable(_selected),
                  term: _usesTerm ? _term : null,
                )),
          child: Text(l10n.syncSelected),
        ),
      ),
    );
  }

  void _setSelected(SyncTarget target, bool checked) {
    setState(() {
      if (checked) {
        _selected.add(target);
      } else {
        _selected.remove(target);
      }
    });
  }
}

class _SyncTargetChoices extends StatelessWidget {
  const _SyncTargetChoices({
    required this.targets,
    required this.selected,
    required this.onChanged,
    this.subtitleFor,
  });

  final Iterable<SyncTarget> targets;
  final Set<SyncTarget> selected;
  final void Function(SyncTarget target, bool checked) onChanged;
  final Widget? Function(SyncTarget target)? subtitleFor;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final target in targets)
        AppSelectionTile(
          value: selected.contains(target),
          title: Text(target.localizedTitle(context.l10n)),
          subtitle: subtitleFor?.call(target),
          onChanged: (checked) => onChanged(target, checked ?? false),
        ),
    ],
  );
}
