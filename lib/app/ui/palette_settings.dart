import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/diagnostics.dart';
import '../../ui/app_menu_anchor.dart';
import '../../ui/app_menu_trigger.dart';
import '../../ui/app_notice.dart';
import '../controller.dart';

class PaletteSettings extends StatefulWidget {
  const PaletteSettings({super.key, required this.controller});

  final AppController controller;

  @override
  State<PaletteSettings> createState() => _PaletteSettingsState();
}

class _PaletteSettingsState extends State<PaletteSettings> {
  bool _importing = false;

  Future<void> _import() async {
    setState(() => _importing = true);
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: '导入调色板',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (file == null || !mounted) return;
      final source = utf8.decode(await file.readAsBytes());
      if (!mounted) return;
      await widget.controller.importCoursePalette(source);
      if (mounted) showAppNotice(context, '已导入并应用配色。');
    } catch (failure, stack) {
      AppDiagnostics.instance.report('导入调色板', failure, stack);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Widget _selection(Brightness brightness) {
    final controller = widget.controller;
    final selected = controller.paletteIdFor(brightness);
    final choices = <String?, String>{
      null: '默认',
      for (final entry in controller.palettesFor(brightness).entries)
        entry.key: entry.value.name,
    };
    return LayoutBuilder(
      builder: (context, constraints) => AppMenuAnchor(
        menuWidth: constraints.maxWidth,
        menuChildren: [
          for (final entry in choices.entries)
            Semantics(
              selected: selected == entry.key,
              child: AppMenuItemButton(
                onPressed: () =>
                    controller.setCoursePalette(brightness, entry.key),
                trailingIcon: selected == entry.key
                    ? const Icon(Icons.check_rounded, size: 18)
                    : const SizedBox(width: 18),
                child: Text(entry.value),
              ),
            ),
        ],
        builder: (context, menu, isOpen) => ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 2),
          leading: const Icon(Icons.palette_outlined),
          title: Text(brightness == Brightness.dark ? '深色模式调色板' : '浅色模式调色板'),
          subtitle: Text(controller.paletteFor(brightness)?.name ?? '默认'),
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
        title: const Text('导入调色板'),
        enabled: !_importing,
        onTap: _importing ? null : _import,
      ),
      for (final entry in widget.controller.customPalettes.entries)
        ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 2),
          title: Text(entry.value.name),
          subtitle: Text(
            entry.value.brightness == Brightness.dark ? '深色' : '浅色',
          ),
          onTap: () => widget.controller.setCoursePalette(
            entry.value.brightness,
            entry.key,
          ),
          trailing: IconButton(
            tooltip: '删除 ${entry.value.name}',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => widget.controller.deleteCoursePalette(entry.key),
          ),
        ),
    ],
  );
}
