import 'package:flutter/material.dart';

import '../../agenda/deadline_clear_scope.dart';
import '../../agenda/ui/clear_deadlines_sheet.dart';
import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../mooc/ui/mooc_sheet.dart';
import '../../schedule/ui/week_range_sheet.dart';
import '../../school/ui/school_account.dart';
import '../../sync/controller.dart';
import '../../sync/ui/sync.dart';
import '../../ui/app_dialog.dart';
import '../../ui/app_menu_anchor.dart';
import '../../ui/app_menu_trigger.dart';
import '../../ui/app_page.dart';
import '../../ui/external_link.dart';
import '../../ui/section_label.dart';
import '../../ui/sheet_layout.dart';
import '../../updates/version.dart';
import '../controller.dart';
import 'logs_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    required this.checkingForUpdates,
    required this.onCheckForUpdates,
  });

  final AppController controller;
  final bool checkingForUpdates;
  final VoidCallback onCheckForUpdates;

  Future<bool> _selectTerm(BuildContext context, String term) =>
      controller.timetable.selectTerm(
        term,
        importTerm: (term) async {
          if (!context.mounted) return false;
          return await startSync(
                context,
                controller,
                targets: {SyncTarget.schedule},
                term: term,
              ) ==
              true;
        },
      );

  Future<void> _clearSchedule(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.settingsDeleteScheduleQuestion,
      body: l10n.settingsDeleteScheduleBody,
      confirmLabel: l10n.settingsDeleteSchedule,
      destructive: true,
    );
    if (confirmed) await controller.timetable.clear();
  }

  Future<void> _showAbout(BuildContext context) async {
    final l10n = context.l10n;
    final version = await appVersion();
    final builtAt = appBuildTime?.toLocal();
    if (!context.mounted) return;

    await showAppSheet<void>(
      context: context,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final localizations = MaterialLocalizations.of(sheetContext);
        var versionLabel = version;
        if (builtAt != null) {
          final date = localizations.formatCompactDate(builtAt);
          final time = localizations.formatTimeOfDay(
            TimeOfDay.fromDateTime(builtAt),
            alwaysUse24HourFormat: true,
          );
          versionLabel += '\n${l10n.settingsBuiltAt(date, time)}';
        }
        return SheetLayout(
          header: SheetHeader(
            title: Row(
              children: [
                Image.asset('assets/brand/bitree.png', width: 40, height: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'BITree',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            l10n.appChineseName,
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        versionLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: const [SheetCloseButton()],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.appTagline),
              const SizedBox(height: 12),
              Semantics(
                link: true,
                child: InkWell(
                  onTap: () => openExternalLink(
                    sheetContext,
                    Uri.https('github.com', '/bitoolkit'),
                    failureTitle: l10n.aboutOpenBitoolkitFailed,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Unlicense. Made by '),
                          TextSpan(
                            text: 'BIToolkit',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          const TextSpan(text: ' with ♥️'),
                        ],
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: SheetActionBar.actions(
            children: [
              TextButton(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  showLicensePage(
                    context: context,
                    applicationName: l10n.aboutLicenseName,
                    applicationVersion: version,
                    applicationIcon: Image.asset(
                      'assets/brand/bitree.png',
                      width: 40,
                      height: 40,
                    ),
                  );
                },
                child: Text(l10n.settingsLicenses),
              ),
              TextButton(
                onPressed: () => openExternalLink(
                  sheetContext,
                  Uri.https('github.com', '/bitoolkit/bitree'),
                  failureTitle: l10n.aboutOpenGitHubFailed,
                ),
                child: const Text('GitHub'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      controller,
      controller.timetable,
      controller.agenda,
    ]),
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final deadlineCount = controller.agenda.countDeadlinesIn(
      DeadlineClearScope.values,
    );

    Widget section(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [AppSectionLabel(title), ...children],
      ),
    );

    const tilePadding = EdgeInsets.symmetric(vertical: 2);

    return AppPage(
      title: Text(l10n.navSettings),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SchoolAccount(controller: controller),
          MoocAccountTile(controller: controller.mooc),
          section(l10n.appearance, [
            SegmentedButton<ThemeMode>(
              expandedInsets: EdgeInsets.zero,
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text(
                    l10n.followSystem,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                  ),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text(l10n.themeLight),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text(l10n.themeDark),
                ),
              ],
              selected: {controller.themeMode},
              onSelectionChanged: (selection) =>
                  controller.setTheme(selection.single),
            ),
          ]),
          section(l10n.language, [
            SegmentedButton<AppLanguage>(
              expandedInsets: EdgeInsets.zero,
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: AppLanguage.system,
                  label: Text(
                    l10n.followSystem,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                  ),
                ),
                ButtonSegment(
                  value: AppLanguage.chinese,
                  label: Text(l10n.languageChinese),
                ),
                ButtonSegment(
                  value: AppLanguage.english,
                  label: Text(l10n.languageEnglish),
                ),
              ],
              selected: {controller.language},
              onSelectionChanged: (selection) =>
                  controller.setLanguage(selection.single),
            ),
          ]),
          if (controller.timetable.schedule != null)
            section(l10n.settingsLocalSchedule, [
              LayoutBuilder(
                builder: (context, constraints) => AppMenuAnchor(
                  menuWidth: constraints.maxWidth,
                  menuChildren: [
                    for (final term in controller.timetable.terms)
                      Semantics(
                        selected: controller.timetable.schedule!.term == term,
                        child: AppMenuItemButton(
                          onPressed: controller.timetable.busy
                              ? null
                              : () => _selectTerm(context, term),
                          trailingIcon:
                              controller.timetable.schedule!.term == term
                              ? const Icon(Icons.check_rounded, size: 18)
                              : const SizedBox(width: 18),
                          overflowAxis: Axis.vertical,
                          child: Text(term),
                        ),
                      ),
                  ],
                  builder: (context, menu, isOpen) => ListTile(
                    contentPadding: tilePadding,
                    leading: const Icon(Icons.calendar_month_outlined),
                    title: Text(l10n.settingsTerm),
                    subtitle: Text(
                      localizedTerm(l10n, controller.timetable.schedule!),
                    ),
                    trailing: AppMenuArrow(isOpen: isOpen),
                    onTap: controller.timetable.busy
                        ? null
                        : () => isOpen ? menu.close() : menu.open(),
                  ),
                ),
              ),
              ListTile(
                contentPadding: tilePadding,
                leading: const Icon(Icons.date_range_outlined),
                title: Text(l10n.settingsWeekManagement),
                subtitle: Text(
                  l10n.weekRangeShort(
                    controller.timetable.schedule!.firstWeek,
                    controller.timetable.schedule!.lastWeek,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: controller.timetable.busy
                    ? null
                    : () => manageTermWeeks(context, controller),
              ),
              ListTile(
                contentPadding: tilePadding,
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: scheme.error,
                ),
                title: Text(
                  l10n.settingsDeleteLocalSchedule,
                  style: TextStyle(color: scheme.error),
                ),
                onTap: controller.timetable.busy
                    ? null
                    : () => _clearSchedule(context),
              ),
            ]),
          section(l10n.settingsLocalAgenda, [
            ListTile(
              contentPadding: tilePadding,
              leading: Icon(Icons.delete_outline_rounded, color: scheme.error),
              title: Text(
                l10n.settingsDeleteDeadlines,
                style: TextStyle(color: scheme.error),
              ),
              subtitle: Text(l10n.settingsDeleteDeadlinesBody(deadlineCount)),
              onTap:
                  !controller.agenda.ready ||
                      controller.agenda.busy ||
                      deadlineCount == 0
                  ? null
                  : () => showClearDeadlines(context, controller.agenda),
            ),
          ]),
          section(l10n.settingsApplication, [
            ListTile(
              contentPadding: tilePadding,
              leading: const Icon(Icons.description_outlined),
              title: Text(l10n.settingsExportLogs),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => const LogsScreen()),
              ),
            ),
            ListTile(
              contentPadding: tilePadding,
              leading: const Icon(Icons.system_update_outlined),
              title: Text(
                checkingForUpdates
                    ? l10n.settingsCheckingUpdates
                    : l10n.settingsCheckUpdates,
              ),
              trailing: checkingForUpdates
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: checkingForUpdates ? null : onCheckForUpdates,
            ),
            ListTile(
              contentPadding: tilePadding,
              leading: const Icon(Icons.info_outline_rounded),
              title: Text(l10n.settingsAbout),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: () => _showAbout(context),
            ),
          ]),
        ],
      ),
    );
  }
}
