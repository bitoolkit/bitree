import 'package:flutter/material.dart';

import '../../agenda/deadline_clear_scope.dart';
import '../../agenda/ui/clear_deadlines_sheet.dart';
import '../../automation/ui/automation_screen.dart';
import '../../automation/ui/status.dart';
import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../mooc/ui/mooc_sheet.dart';
import '../../schedule/ui/week_range_dialog.dart';
import '../../school/ui/school_account.dart';
import '../../sources/ui/sources_screen.dart';
import '../../sync/controller.dart';
import '../../sync/ui/sync.dart';
import '../../ui/app_dialog.dart';
import '../../ui/app_menu_anchor.dart';
import '../../ui/app_menu_trigger.dart';
import '../../ui/app_notice.dart';
import '../../ui/app_page.dart';
import '../../ui/section_label.dart';
import '../controller.dart';
import '../settings_controller.dart';
import 'about_dialog.dart';
import 'appearance_screen.dart';
import 'developer_screen.dart';
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
    if (!confirmed) return;
    final cleared = await controller.timetable.clear();
    if (!cleared && context.mounted) {
      showAppNotice(context, context.l10n.operationDeleteFailed);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      controller,
      controller.settings,
      controller.timetable,
      controller.agenda,
      controller.sources,
      controller.automation,
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
        children: [AppSectionHeader(title), ...children],
      ),
    );

    const tilePadding = EdgeInsets.symmetric(vertical: 2);
    final language = Localizations.localeOf(context).languageCode;
    final activeSources = {
      for (final source in listedSources(controller))
        if (source.instance.enabled) source.definition.name.resolve(language),
    };

    return AppPage(
      title: Text(l10n.navSettings),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SchoolAccount(controller: controller),
          MoocAccountTile(controller: controller.mooc),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            leading: const Icon(Icons.hub_outlined, size: 36),
            title: Text(l10n.dataSourcesTitle),
            subtitle: Text(
              activeSources.isEmpty
                  ? l10n.dataSourcesNone
                  : activeSources.join(l10n.listSeparator),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => SourcesScreen(controller: controller),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: ListTile(
              contentPadding: tilePadding,
              leading: const Icon(Icons.palette_outlined),
              title: Text(l10n.appearance),
              subtitle: Text(
                controller.settings.themeMode.localizedLabel(l10n),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) =>
                      AppearanceScreen(settings: controller.settings),
                ),
              ),
            ),
          ),
          ListTile(
            contentPadding: tilePadding,
            leading: const Icon(Icons.tune_rounded),
            title: Text(l10n.automationTitle),
            subtitle: Text(displayRulesSummary(controller.automation, l10n)),
            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) =>
                    AutomationScreen(controller: controller.automation),
              ),
            ),
          ),
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
              selected: {controller.settings.language},
              onSelectionChanged: (selection) =>
                  controller.settings.setLanguage(selection.single),
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
                      localizedTerm(l10n, controller.timetable.schedule!.term),
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
          if (controller.settings.developerMode)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: ListTile(
                contentPadding: tilePadding,
                leading: const Icon(Icons.code_rounded),
                title: Text(l10n.developerMode),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => DeveloperScreen(controller: controller),
                  ),
                ),
              ),
            ),
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
              onTap: () => showBitreeAboutDialog(context, controller.settings),
            ),
          ]),
        ],
      ),
    );
  }
}
