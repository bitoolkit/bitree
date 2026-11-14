part of 'sync.dart';

class _CustomSyncSheet extends StatefulWidget {
  const _CustomSyncSheet({required this.app});
  final AppController app;
  @override
  State<_CustomSyncSheet> createState() => _CustomSyncSheetState();
}

class _CustomSyncSheetState extends State<_CustomSyncSheet> {
  late final _availableTargets = widget.app.sync.bulkTargets;
  late final _selected = widget.app.sync.defaultTargets;
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
  Widget build(BuildContext context) => SheetLayout(
    header: SheetHeader(
      title: Text(context.l10n.customSync),
      actions: const [SheetCloseButton()],
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSelectionBar(
          selectedCount: _selected.length,
          totalCount: _availableTargets.length,
          summary: context.l10n.selectedItems(_selected.length),
          onToggleAll: (selected) => setState(() {
            _selected.clear();
            if (selected) _selected.addAll(_availableTargets);
          }),
          onClear: _selected.isEmpty ? null : () => setState(_selected.clear),
        ),
        const SizedBox(height: AppSpacing.md),
        AppSectionHeader(context.l10n.syncSchoolData),
        if (_usesTerm && _terms.isNotEmpty) ...[
          SemesterDropdown(
            label: context.l10n.syncTerm,
            value: _term,
            terms: _terms,
            onChanged: (term) => setState(() => _term = term),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        _SyncTargetChoices(
          targets: _availableTargets.where(
            (target) => target.category == SyncCategory.schoolData,
          ),
          selected: _selected,
          onChanged: _setSelected,
        ),
        const SizedBox(height: AppSpacing.md),
        AppSectionHeader(context.l10n.syncDeadlineData),
        _SyncTargetChoices(
          targets: _availableTargets.where(
            (target) => target.category == SyncCategory.deadlineData,
          ),
          selected: _selected,
          onChanged: _setSelected,
        ),
        if (_selected.contains(SyncTarget.mooc) &&
            widget.app.mooc.needsLogin) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.login_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  context.l10n.loginAfterSelection,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ],
    ),
    actions: SheetActionBar.primary(
      primary: FilledButton(
        onPressed: _selected.isEmpty
            ? null
            : () => Navigator.pop(context, (
                targets: Set<SyncTarget>.unmodifiable(_selected),
                term: _usesTerm ? _term : null,
              )),
        child: Text(context.l10n.syncSelected),
      ),
    ),
  );

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
  });

  final Iterable<SyncTarget> targets;
  final Set<SyncTarget> selected;
  final void Function(SyncTarget target, bool checked) onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final target in targets)
        AppSelectionTile(
          value: selected.contains(target),
          title: Text(target.localizedTitle(context.l10n)),
          onChanged: (checked) => onChanged(target, checked ?? false),
        ),
    ],
  );
}
