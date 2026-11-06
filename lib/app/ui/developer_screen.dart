import 'package:flutter/material.dart';

import '../../automation/ui/automation_screen.dart';
import '../../l10n/l10n.dart';
import '../../ui/app_page.dart';
import '../controller.dart';

class DeveloperScreen extends StatelessWidget {
  const DeveloperScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => AppRoutePage(
    title: context.l10n.developerMode,
    child: ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.auto_fix_high_outlined),
          title: Text(context.l10n.automationTitle),
          subtitle: Text(context.l10n.automationDescription),
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
}
