import 'package:flutter/material.dart';

import '../../agenda/deadline_source.dart';
import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../ui/app_dialog.dart';
import '../../ui/app_page.dart';
import '../../ui/section_label.dart';
import '../../ui/sheet_layout.dart';
import '../controller.dart';
import '../rules.dart';
import 'automation_script_screen.dart';

class AutomationScreen extends StatefulWidget {
  const AutomationScreen({super.key, required this.controller});

  final AutomationController controller;

  @override
  State<AutomationScreen> createState() => _AutomationScreenState();
}

class _AutomationScreenState extends State<AutomationScreen> {
  bool _saving = false;
  String? _error;

  Future<void> _applyRules(AutomationRules rules) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.controller.saveRules(rules);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editCourseAliases() async {
    final current = widget.controller.rules ?? AutomationRules();
    final names = {
      ...widget.controller.courseNames,
      ...current.courseAliases.keys,
    }.toList()..sort();
    final aliases = await showAppSheet<Map<String, String>>(
      context: context,
      builder: (_) => _CourseAliasesSheet(
        courseNames: names,
        aliases: current.courseAliases,
      ),
    );
    if (aliases == null || !mounted) return;
    await _applyRules(current.copyWith(courseAliases: aliases));
  }

  Future<void> _editHiddenSources() async {
    final current = widget.controller.rules ?? AutomationRules();
    final selected = await showAppSheet<Set<DeadlineSource>>(
      context: context,
      builder: (_) =>
          _DeadlineSourcesSheet(selected: current.hiddenDeadlineSources),
    );
    if (selected == null || !mounted) return;
    await _applyRules(current.copyWith(hiddenDeadlineSources: selected));
  }

  Future<void> _editExamPrefix() async {
    final current = widget.controller.rules ?? AutomationRules();
    final prefix = await showAppDialog<String>(
      context: context,
      builder: (_) => _ExamPrefixDialog(initialValue: current.examTitlePrefix),
    );
    if (prefix == null || !mounted) return;
    await _applyRules(current.copyWith(examTitlePrefix: prefix));
  }

  Future<void> _openCustomScript() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AutomationScriptScreen(controller: widget.controller),
      ),
    );
    if (mounted) setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final l10n = context.l10n;
      final controller = widget.controller;
      final error = _error ?? controller.error;
      final rules = controller.rules;
      final busy = _saving || controller.running;
      final aliases = rules?.courseAliases ?? const {};
      final hiddenSources = rules?.hiddenDeadlineSources ?? const {};
      final prefix = rules?.examTitlePrefix ?? '';
      final hasScript = controller.source.trim().isNotEmpty;
      final scheme = Theme.of(context).colorScheme;
      return AppRoutePage(
        title: l10n.automationTitle,
        showProgress: busy,
        maxWidth: 800,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            if (error != null) ...[
              Text(
                l10n.automationFallback,
                style: TextStyle(color: scheme.error),
              ),
              const SizedBox(height: 8),
              SelectableText(
                error,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              const SizedBox(height: 16),
            ],
            _TaskTile(
              icon: Icons.drive_file_rename_outline,
              title: l10n.automationCourseAliases,
              subtitle: aliases.isEmpty
                  ? l10n.automationNotSet
                  : l10n.automationAliasSummary(aliases.length),
              onTap: busy ? null : _editCourseAliases,
            ),
            _TaskTile(
              icon: Icons.visibility_off_outlined,
              title: l10n.automationHideSources,
              subtitle: hiddenSources.isEmpty
                  ? l10n.automationNoneHidden
                  : l10n.automationHiddenSources(
                      hiddenSources
                          .map((source) => source.localizedLabel(l10n))
                          .join(l10n.listSeparator),
                    ),
              onTap: busy ? null : _editHiddenSources,
            ),
            _TaskTile(
              icon: Icons.title_rounded,
              title: l10n.automationExamPrefix,
              subtitle: prefix.isEmpty
                  ? l10n.automationNotSet
                  : l10n.automationPrefixSummary(prefix),
              onTap: busy ? null : _editExamPrefix,
            ),
            const SizedBox(height: 20),
            AppSectionHeader(l10n.advanced),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 4,
              ),
              leading: const Icon(Icons.code_rounded),
              title: Text(l10n.automationCustomScript),
              subtitle: Text(
                !hasScript
                    ? l10n.automationCustomScriptHint
                    : !controller.scriptEnabled
                    ? l10n.disabled
                    : controller.fileName.isNotEmpty
                    ? controller.fileName
                    : l10n.automationScriptActive,
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: busy ? null : _openCustomScript,
            ),
          ],
        ),
      );
    },
  );
}

class _ExamPrefixDialog extends StatefulWidget {
  const _ExamPrefixDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_ExamPrefixDialog> createState() => _ExamPrefixDialogState();
}

class _ExamPrefixDialogState extends State<_ExamPrefixDialog> {
  late final _input = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.automationExamPrefix),
    content: TextField(
      controller: _input,
      autofocus: true,
      decoration: InputDecoration(
        labelText: context.l10n.automationExamPrefixLabel,
        hintText: context.l10n.automationExamPrefixExample,
      ),
      onSubmitted: (value) => Navigator.pop(context, value.trim()),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _input.text.trim()),
        child: Text(context.l10n.save),
      ),
    ],
  );
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}

class _CourseAliasesSheet extends StatefulWidget {
  const _CourseAliasesSheet({required this.courseNames, required this.aliases});

  final List<String> courseNames;
  final Map<String, String> aliases;

  @override
  State<_CourseAliasesSheet> createState() => _CourseAliasesSheetState();
}

class _CourseAliasesSheetState extends State<_CourseAliasesSheet> {
  late final _controllers = {
    for (final name in widget.courseNames)
      name: TextEditingController(text: widget.aliases[name] ?? ''),
  };

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, String> _result() => {
    for (final entry in _controllers.entries)
      if (entry.value.text.trim().isNotEmpty)
        entry.key: entry.value.text.trim(),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SheetLayout(
      header: SheetHeader(
        title: Text(l10n.automationCourseAliases),
        actions: const [SheetCloseButton()],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.automationCourseAliasesHint),
          const SizedBox(height: 16),
          if (_controllers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                l10n.automationCourseAliasesEmpty,
                textAlign: TextAlign.center,
              ),
            )
          else
            for (final entry in _controllers.entries) ...[
              Text(entry.key, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 4),
              TextField(
                key: ValueKey('automation-alias-${entry.key}'),
                controller: entry.value,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.automationDisplayName,
                ),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
      actions: SheetActionBar.primary(
        primary: FilledButton(
          onPressed: () => Navigator.pop(context, _result()),
          child: Text(l10n.save),
        ),
      ),
    );
  }
}

class _DeadlineSourcesSheet extends StatefulWidget {
  const _DeadlineSourcesSheet({required this.selected});

  final Set<DeadlineSource> selected;

  @override
  State<_DeadlineSourcesSheet> createState() => _DeadlineSourcesSheetState();
}

class _DeadlineSourcesSheetState extends State<_DeadlineSourcesSheet> {
  late final _selected = {...widget.selected};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SheetLayout(
      header: SheetHeader(
        title: Text(l10n.automationHideSources),
        actions: const [SheetCloseButton()],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.automationHideSourcesHint),
          const SizedBox(height: 8),
          for (final source in DeadlineSource.values)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _selected.contains(source),
              title: Text(source.localizedLabel(l10n)),
              onChanged: (value) => setState(() {
                if (value == true) {
                  _selected.add(source);
                } else {
                  _selected.remove(source);
                }
              }),
            ),
        ],
      ),
      actions: SheetActionBar.primary(
        primary: FilledButton(
          onPressed: () => Navigator.pop(context, Set.of(_selected)),
          child: Text(l10n.save),
        ),
      ),
    );
  }
}
