import 'package:flutter/material.dart';

import '../../agenda/model.dart';
import '../../app/controller.dart';
import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../schedule/model.dart';
import '../../sync/controller.dart';
import '../../sync/ui/sync.dart';
import '../../ui/app_page.dart';
import '../../ui/design.dart';
import '../../ui/external_link.dart';
import '../../ui/sheet_layout.dart';
import '../model.dart';

class AcademicPage extends StatelessWidget {
  const AcademicPage({
    super.key,
    required this.title,
    required this.children,
    this.actions = const [],
    this.loading = false,
  });

  final String title;
  final List<Widget> children;
  final List<Widget> actions;
  final bool loading;

  @override
  Widget build(BuildContext context) => AppRoutePage(
    title: title,
    actions: actions,
    maxWidth: 880,
    showProgress: loading,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: children,
    ),
  );
}

class AcademicImportButton extends StatelessWidget {
  const AcademicImportButton({
    super.key,
    required this.controller,
    required this.action,
    this.term,
  });
  final AppController controller;
  final SyncTarget action;
  final String? term;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller.sync,
    builder: (context, _) => IconButton(
      tooltip: controller.sync.busy
          ? context.l10n.viewSyncProgress
          : action.localizedAction(context.l10n),
      onPressed: () => controller.sync.busy
          ? showSyncProgress(context, controller)
          : startSync(context, controller, targets: {action}, term: term),
      icon: controller.sync.busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh_rounded),
    ),
  );
}

class AcademicEmpty extends StatelessWidget {
  const AcademicEmpty({
    super.key,
    required this.title,
    required this.label,
    required this.onPressed,
  });
  final String title;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Column(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        FilledButton(onPressed: onPressed, child: Text(label)),
      ],
    ),
  );
}

class AcademicSummary extends StatelessWidget {
  const AcademicSummary({super.key, required this.values});
  final List<({String label, String value})> values;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Wrap(
      spacing: 32,
      runSpacing: 16,
      children: [
        for (final item in values)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                item.value,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
      ],
    ),
  );
}

class GradeListTile extends StatelessWidget {
  const GradeListTile({super.key, required this.grade, required this.onTap});
  final CourseGrade grade;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(grade.name),
      subtitle: Text(
        [
          l10n.credits(creditText(grade.credits)),
          grade.category,
          if (grade.failed) l10n.failedCourse,
        ].where((text) => text.isNotEmpty).join('  '),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              grade.result,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: grade.failed
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, size: 18),
        ],
      ),
      onTap: onTap,
    );
  }
}

class AcademicUpdatedAt extends StatelessWidget {
  const AcademicUpdatedAt({super.key, required this.updatedAt});
  final DateTime updatedAt;

  @override
  Widget build(BuildContext context) {
    final time = updatedAt.toUtc().add(const Duration(hours: 8));
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        context.l10n.syncedAt(dateText(time), clockText(time)),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

Future<void> showGpaRules(BuildContext context) => showAppSheet<void>(
  context: context,
  builder: (sheetContext) {
    final l10n = context.l10n;
    return SheetLayout(
      header: SheetHeader(
        title: Text(l10n.gpaRulesTitle),
        actions: const [SheetCloseButton()],
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.gpaRuleIntro),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.gpaRulePercent),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.gpaRuleFive),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.gpaRuleWeighting),
        ],
      ),
      actions: SheetActionBar.actions(
        children: [
          TextButton(
            onPressed: () => openExternalLink(
              sheetContext,
              Uri.parse(gpaRulesUrl),
              failureTitle: l10n.openGpaRulesFailed,
            ),
            child: Text(l10n.schoolSource),
          ),
        ],
      ),
    );
  },
);
