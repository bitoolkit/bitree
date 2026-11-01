import 'package:flutter/material.dart';

import '../../academics/ui/credit_progress_screen.dart';
import '../../academics/ui/exams_screen.dart';
import '../../academics/ui/grade_simulation_screen.dart';
import '../../academics/ui/grades_screen.dart';
import '../../classrooms/ui/classroom_screen.dart';
import '../../l10n/l10n.dart';
import '../../ui/app_page.dart';
import '../../wencui/ui/wencui_map_screen.dart';
import '../controller.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppPage(
      title: Text(l10n.toolsTitle),
      child: ListView(
        children: [
          for (final tool in [
            (
              title: l10n.gradesAndAcademics,
              icon: Icons.school_outlined,
              page: GradesScreen(controller: controller),
            ),
            (
              title: l10n.gradeSimulation,
              icon: Icons.calculate_outlined,
              page: GradeSimulationScreen(controller: controller),
            ),
            (
              title: l10n.creditProgress,
              icon: Icons.checklist_rounded,
              page: CreditProgressScreen(controller: controller),
            ),
            (
              title: l10n.examScheduleTool,
              icon: Icons.event_available_outlined,
              page: ExamsScreen(controller: controller),
            ),
          ])
            ListTile(
              leading: Icon(tool.icon),
              title: Text(tool.title),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () =>
                  Navigator.of(context)
                      .push<void>(MaterialPageRoute(builder: (_) => tool.page)),
            ),
          ListTile(
            leading: const Icon(Icons.meeting_room_outlined),
            title: Text(l10n.emptyClassroomQuery),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => ClassroomScreen(controller: controller),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.map_outlined),
            title: Text(l10n.wencuiMap),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => WencuiMapScreen(controller: controller),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
