import 'package:flutter/material.dart';

import '../../agenda/deadline_clear_scope.dart';
import '../../agenda/ui/clear_deadlines_sheet.dart';
import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../mooc/ui/mooc_sheet.dart';
import '../../schedule/ui/week_range_dialog.dart';
import '../../school/ui/school_account.dart';
import '../../sync/controller.dart';
import '../../sync/ui/sync.dart';
import '../../ui/app_dialog.dart';
import '../../ui/app_menu_anchor.dart';
import '../../ui/app_menu_trigger.dart';
import '../../ui/app_notice.dart';
import '../../ui/app_page.dart';
import '../../ui/section_label.dart';
import '../../ui/selection_controls.dart';
import '../controller.dart';
import '../settings_controller.dart';
import 'about_dialog.dart';
import 'agenda_layout_days_settings.dart';
import 'appearance_screen.dart';
import 'deadline_cutoff_settings.dart';
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

  Future<void> _resetDefaultDeadlineTails(BuildContext context) async {
    final count = await controller.agenda.resetDefaultDeadlineTails();
    if (!context.mounted) return;
    showAppNotice(
      context,
      count == null
          ? context.l10n.operationSaveFailed
          : context.l10n.settingsResetDefaultDeadlineTailsResult(count),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      controller,
      controller.settings,
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
        children: [AppSectionHeader(title), ...children],
      ),
    );

    const tilePadding = EdgeInsets.symmetric(vertical: 2);

    return AppPage(
      title: Text(l10n.navSettings),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SchoolAccount(controller: controller.school),
          MoocAccountTile(controller: controller.mooc),
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
          section(l10n.language, [
            AppSegmentedControl<AppLanguage>(
              options: {
                AppLanguage.system: l10n.followSystem,
                AppLanguage.chinese: l10n.languageChinese,
                AppLanguage.english: l10n.languageEnglish,
              },
              value: controller.settings.language,
              onChanged: controller.settings.setLanguage,
            ),
          ]),
          if (controller.timetable.schedule != null)
            section(l10n.settingsLocalSchedule, [
              LayoutBuilder(
                builder: (context, constraints) => AppMenuAnchor(
                  menuWidth: constraints.maxWidth,
                  menuChildren: [
                    for (final term in controller.timetable.terms)
                      AppMenuItemButton(
                        selected: controller.timetable.schedule!.term == term,
                        onPressed: controller.timetable.busy
                            ? null
                            : () => _selectTerm(context, term),
                        child: Text(localizedTerm(l10n, term)),
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
                    : () => manageTermWeeks(context, controller.timetable),
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
            AgendaLayoutDaysSettingsTile(settings: controller.settings),
            DeadlineCutoffSettingsTile(settings: controller.settings),
            ValueListenableBuilder(
              valueListenable: controller.settings.agendaEventInfoBar,
              builder: (context, infoBar, _) => SwitchListTile(
                key: const ValueKey('agenda-event-info-bar-settings'),
                contentPadding: tilePadding,
                secondary: const Icon(Icons.article_outlined),
                title: Text(l10n.settingsAgendaEventInfoBar),
                subtitle: Text(l10n.settingsAgendaEventInfoBarDescription),
                value: infoBar,
                onChanged: controller.settings.setAgendaEventInfoBar,
              ),
            ),
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
              onTap: () => showBitreeAboutDialog(context, controller.settings),
            ),
          ]),
          if (controller.settings.developerMode)
            section(l10n.settingsDeveloperOptions, [
              ListTile(
                key: const ValueKey('reset-default-deadline-tails'),
                contentPadding: tilePadding,
                leading: const Icon(Icons.restart_alt_rounded),
                title: Text(l10n.settingsResetDefaultDeadlineTails),
                subtitle: Text(
                  l10n.settingsResetDefaultDeadlineTailsDescription,
                ),
                onTap: !controller.agenda.ready || controller.agenda.busy
                    ? null
                    : () => _resetDefaultDeadlineTails(context),
              ),
            ]),
        ],
      ),
    );
  }
}
