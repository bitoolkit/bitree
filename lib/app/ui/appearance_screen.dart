import 'package:flutter/material.dart';

import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../schedule/height_mode.dart';
import '../../ui/app_page.dart';
import '../../ui/section_label.dart';
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
            SegmentedButton<ThemeMode>(
              expandedInsets: EdgeInsets.zero,
              showSelectedIcon: false,
              segments: [
                for (final mode in ThemeMode.values)
                  ButtonSegment(
                    value: mode,
                    label: Text(
                      mode.localizedLabel(l10n),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (selection) =>
                  settings.setTheme(selection.single),
            ),
            const SizedBox(height: 16),
            PaletteSettings(settings: settings),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 2),
              secondary: const Icon(Icons.auto_awesome_outlined),
              title: Text(l10n.widgetUsesSystemPalette),
              value: settings.widgetUseSystemPalette,
              onChanged: settings.setWidgetUseSystemPalette,
            ),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 2),
              secondary: const Icon(Icons.color_lens_outlined),
              title: Text(l10n.globalSystemPaletteExperimental),
              value: settings.globalUseSystemPalette,
              onChanged: settings.setGlobalUseSystemPalette,
            ),
            const SizedBox(height: 24),
            AppSectionHeader(l10n.timetableHeight),
            SegmentedButton<TimetableHeightMode>(
              expandedInsets: EdgeInsets.zero,
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: TimetableHeightMode.fit,
                  label: Text(
                    l10n.timetableHeightFit,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                  ),
                ),
                ButtonSegment(
                  value: TimetableHeightMode.normal,
                  label: Text(
                    l10n.timetableHeightNormal,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              selected: {settings.timetableHeightMode.value},
              onSelectionChanged: (selection) =>
                  settings.setTimetableHeightMode(selection.single),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.timetableHeightHint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
