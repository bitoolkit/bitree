import 'package:flutter/material.dart';

import '../../agenda/model.dart';
import '../../automation/ui/automation_screen.dart';
import '../../automation/ui/status.dart';
import '../../core/time.dart';
import '../../l10n/l10n.dart';
import '../../ui/app_page.dart';
import '../../ui/campus_time_builder.dart';
import '../controller.dart';

class DeveloperScreen extends StatelessWidget {
  const DeveloperScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => CampusTimeBuilder(
    active: true,
    builder: (context, currentTime) => ListenableBuilder(
      listenable: controller.automation,
      builder: (context, _) {
        final start = mondayOf(currentTime);
        final end = start.add(const Duration(days: 7));
        final title =
            controller.automation.entries.any(
              (entry) =>
                  entry.kind == AgendaKind.exam &&
                  (entry.title.contains('自动控制原理') ||
                      entry.title.contains('自控原理')) &&
                  entry.startsAt.isBefore(end) &&
                  entry.endsAt!.isAfter(start),
            )
            ? '被动控制原理'
            : context.l10n.automationTitle;
        return AppRoutePage(
          title: context.l10n.developerMode,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.settings_outlined),
                title: Text(title),
                subtitle: Text(
                  displayRulesSummary(controller.automation, context.l10n),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) =>
                        AutomationScreen(controller: controller.automation),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
