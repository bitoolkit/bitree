import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/diagnostics.dart';
import '../../l10n/l10n.dart';
import '../../ui/app_menu_anchor.dart';
import '../../ui/app_menu_trigger.dart';
import '../../ui/app_notice.dart';
import '../settings_controller.dart';

class PaletteSettings extends StatefulWidget {
  const PaletteSettings({super.key, required this.settings});

  final AppSettingsController settings;

  @override
  State<PaletteSettings> createState() => _PaletteSettingsState();
}

class _PaletteSettingsState extends State<PaletteSettings> {
  bool _importing = false;

  Future<void> _import() async {
    final l10n = context.l10n;
    setState(() => _importing = true);
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: l10n.importPalette,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (file == null || !mounted) return;
      final source = utf8.decode(await file.readAsBytes());
      if (!mounted) return;
      await widget.settings.importCoursePalette(source);
      if (mounted) showAppNotice(context, l10n.paletteImported);
    } catch (failure, stack) {
      AppDiagnostics.instance.report('导入调色板', failure, stack);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Widget _selection(Brightness brightness) {
    final l10n = context.l10n;
    final settings = widget.settings;
    final selected = settings.paletteIdFor(brightness);
    final choices = <String?, String>{
      null: l10n.defaultPalette,
      for (final entry in settings.palettesFor(brightness).entries)
        entry.key: entry.value.name,
    };
    return LayoutBuilder(
      builder: (context, constraints) => AppMenuAnchor(
        menuWidth: constraints.maxWidth,
        menuChildren: [
          for (final entry in choices.entries)
            AppMenuItemButton(
              selected: selected == entry.key,
              onPressed: () => settings.setCoursePalette(brightness, entry.key),
              child: Text(entry.value),
            ),
        ],
        builder: (context, menu, isOpen) => ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 2),
          leading: const Icon(Icons.palette_outlined),
          title: Text(
            brightness == Brightness.dark
                ? l10n.darkModePalette
                : l10n.lightModePalette,
          ),
          subtitle: Text(
            settings.paletteFor(brightness)?.name ?? l10n.defaultPalette,
          ),
          trailing: AppMenuArrow(isOpen: isOpen),
          onTap: () => isOpen ? menu.close() : menu.open(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _selection(Brightness.light),
      _selection(Brightness.dark),
      ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 2),
        leading: const Icon(Icons.file_open_outlined),
        title: Text(context.l10n.importPalette),
        enabled: !_importing,
        onTap: _importing ? null : _import,
      ),
      for (final entry in widget.settings.customPalettes.entries)
        ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 2),
          title: Text(entry.value.name),
          subtitle: Text(
            entry.value.brightness == Brightness.dark
                ? context.l10n.themeDark
                : context.l10n.themeLight,
          ),
          onTap: () => widget.settings.setCoursePalette(
            entry.value.brightness,
            entry.key,
          ),
          trailing: IconButton(
            tooltip: context.l10n.deletePalette(entry.value.name),
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => widget.settings.deleteCoursePalette(entry.key),
          ),
        ),
    ],
  );
}
