import 'package:flutter/material.dart';

import '../controller.dart';
import 'palette_settings.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('外观')),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                SegmentedButton<ThemeMode>(
                  expandedInsets: EdgeInsets.zero,
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text(
                        '跟随系统',
                        maxLines: 2,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    ButtonSegment(value: ThemeMode.light, label: Text('浅色')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('深色')),
                  ],
                  selected: {controller.themeMode},
                  onSelectionChanged: (selection) =>
                      controller.setTheme(selection.single),
                ),
                const SizedBox(height: 16),
                PaletteSettings(controller: controller),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 2),
                  secondary: const Icon(Icons.auto_awesome_outlined),
                  title: const Text('小组件使用系统调色板'),
                  value: controller.widgetUseSystemPalette,
                  onChanged: controller.setWidgetUseSystemPalette,
                ),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 2),
                  secondary: const Icon(Icons.color_lens_outlined),
                  title: const Text('全局系统调色板（实验性）'),
                  value: controller.globalUseSystemPalette,
                  onChanged: controller.setGlobalUseSystemPalette,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
