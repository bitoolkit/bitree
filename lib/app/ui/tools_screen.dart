import 'package:flutter/material.dart';

import '../../academics/ui/credit_progress_screen.dart';
import '../../academics/ui/exams_screen.dart';
import '../../academics/ui/grade_simulation_screen.dart';
import '../../academics/ui/grades_screen.dart';
import '../../classrooms/ui/classroom_screen.dart';
import '../../l10n/l10n.dart';
import '../../ui/app_page.dart';
import '../../ui/section_label.dart';
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          AppSectionHeader(l10n.academicTools),
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: Icon(tool.icon),
              title: Text(tool.title),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () =>
                  Navigator.of(context)
                      .push<void>(MaterialPageRoute(builder: (_) => tool.page)),
            ),
          const SizedBox(height: 16),
          AppSectionHeader(l10n.campusTools),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: const Icon(Icons.meeting_room_outlined),
            title: Text(l10n.emptyClassroomQuery),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => ClassroomScreen(
                  repository: controller.classroomRepository,
                  school: controller.school,
                  timetable: controller.timetable,
                ),
              ),
            ),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: const Icon(Icons.map_outlined),
            title: Text(l10n.wencuiMap),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) =>
                    WencuiMapScreen(timetable: controller.timetable),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
