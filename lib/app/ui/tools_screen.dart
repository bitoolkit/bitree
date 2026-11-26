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
    final scheme = Theme.of(context).colorScheme;
    final divider = Divider(
      height: 1,
      thickness: 1,
      color: scheme.outlineVariant.withValues(alpha: 0.55),
    );
    final academicTools = [
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
    ];
    final campusTools = [
      (
        title: l10n.emptyClassroomQuery,
        icon: Icons.meeting_room_outlined,
        page: ClassroomScreen(
          repository: controller.classroomRepository,
          school: controller.school,
          timetable: controller.timetable,
        ),
      ),
      (
        title: l10n.wencuiMap,
        icon: Icons.map_outlined,
        page: WencuiMapScreen(timetable: controller.timetable),
      ),
    ];

    Widget buildSection(
      String header,
      List<({String title, IconData icon, Widget page})> items,
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(header),
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) divider,
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 2,
            ),
            leading: Icon(items[i].icon, size: 21),
            title: Text(items[i].title),
            trailing: Icon(
              Icons.chevron_right_rounded,
              size: 19,
              color: scheme.onSurfaceVariant,
            ),
            onTap: () => Navigator.of(context)
                .push<void>(MaterialPageRoute(builder: (_) => items[i].page)),
          ),
        ],
      ],
    );

    return AppPage(
      title: Text(l10n.toolsTitle),
      maxWidth: 720,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          buildSection(l10n.academicTools, academicTools),
          const SizedBox(height: 28),
          buildSection(l10n.campusTools, campusTools),
        ],
      ),
    );
  }
}
