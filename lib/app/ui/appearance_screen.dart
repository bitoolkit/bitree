import 'package:flutter/material.dart';

import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../schedule/height_mode.dart';
import '../../ui/app_page.dart';
import '../../ui/section_label.dart';
import '../../ui/selection_controls.dart';
import '../settings_controller.dart';
import 'palette_settings.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key, required this.settings});

  final AppSettingsController settings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return AppRoutePage(
      title: l10n.appearance,
      child: ListenableBuilder(
        listenable: Listenable.merge([settings, settings.timetableHeightMode]),
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            AppSegmentedControl<ThemeMode>(
              options: {
                for (final mode in ThemeMode.values)
                  mode: mode.localizedLabel(l10n),
              },
              value: settings.themeMode,
              onChanged: settings.setTheme,
            ),
            const SizedBox(height: 16),
            PaletteSettings(settings: settings),
            AppToggleTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: Text(l10n.widgetUsesSystemPalette),
              value: settings.widgetUseSystemPalette,
              onChanged: settings.setWidgetUseSystemPalette,
            ),
            AppToggleTile(
              leading: const Icon(Icons.color_lens_outlined),
              title: Text(l10n.globalSystemPaletteExperimental),
              value: settings.globalUseSystemPalette,
              onChanged: settings.setGlobalUseSystemPalette,
            ),
            const SizedBox(height: 24),
            AppSectionHeader(l10n.timetableHeight),
            AppSegmentedControl<TimetableHeightMode>(
              options: {
                TimetableHeightMode.fit: l10n.timetableHeightFit,
                TimetableHeightMode.normal: l10n.timetableHeightNormal,
              },
              value: settings.timetableHeightMode.value,
              onChanged: settings.setTimetableHeightMode,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.timetableHeightHint,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
