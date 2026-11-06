import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../ui/app_notice.dart';
import '../../ui/app_page.dart';
import '../../ui/section_label.dart';
import '../controller.dart';
import '../example.dart';
import '../lua_filter.dart';

class AutomationScreen extends StatefulWidget {
  const AutomationScreen({super.key, required this.controller});

  final AutomationController controller;

  @override
  State<AutomationScreen> createState() => _AutomationScreenState();
}

class _AutomationScreenState extends State<AutomationScreen> {
  late final _source = TextEditingController(text: widget.controller.source);
  late String _fileName = widget.controller.fileName;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _source.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.controller.saveScript(_source.text, fileName: _fileName);
      if (mounted && widget.controller.error == null) {
        showAppNotice(context, context.l10n.automationSaved);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _import() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: context.l10n.automationImport,
        type: FileType.custom,
        allowedExtensions: ['lua'],
      );
      if (file == null || !mounted) return;
      if ((await file.length() ?? 0) > LuaFilterExecutor.maxScriptBytes) {
        throw const FormatException('Lua script exceeds 128 KiB.');
      }
      final bytes = await file.readAsBytes();
      if (bytes.length > LuaFilterExecutor.maxScriptBytes) {
        throw const FormatException('Lua script exceeds 128 KiB.');
      }
      final source = utf8.decode(bytes);
      if (!mounted) return;
      _source.text = source;
      _fileName = file.name;
      await widget.controller.saveScript(source, fileName: _fileName);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setEnabled(bool value) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.controller.setEnabled(value);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final l10n = context.l10n;
      final controller = widget.controller;
      final error = _error ?? controller.error;
      final busy = _saving || controller.running;
      return AppRoutePage(
        title: l10n.automationTitle,
        showProgress: busy,
        maxWidth: 800,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(l10n.automationDescription),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.automationEnabled),
              subtitle: Text(
                controller.fileName.isEmpty
                    ? l10n.automationLocalScript
                    : controller.fileName,
              ),
              value: controller.enabled,
              onChanged: busy || controller.source.trim().isEmpty
                  ? null
                  : _setEnabled,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : _import,
                  icon: const Icon(Icons.file_open_outlined),
                  label: Text(l10n.automationImport),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () {
                          setState(() {
                            _source.text = automationExample;
                            _fileName = '';
                          });
                        },
                  child: Text(l10n.automationExample),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('automation-source'),
              controller: _source,
              enabled: !busy,
              minLines: 12,
              maxLines: 22,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: l10n.automationScript,
                alignLabelWithHint: true,
                hintText: 'function filter(data)\n    return data\nend',
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: busy ? null : _save,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(l10n.automationApply),
              ),
            ),
            const SizedBox(height: 20),
            AppSectionHeader(l10n.automationResult),
            if (error != null) ...[
              Text(
                _error != null
                    ? l10n.operationSaveFailed
                    : l10n.automationFallback,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 8),
              SelectableText(
                error,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ] else
              Text(
                controller.running
                    ? l10n.automationRunning
                    : controller.enabled
                    ? l10n.automationHidden(
                        controller.hiddenCourses,
                        controller.hiddenDeadlines,
                      )
                    : l10n.automationDisabled,
              ),
            const SizedBox(height: 20),
            AppSectionHeader(l10n.automationContractTitle),
            SelectableText(l10n.automationContract),
          ],
        ),
      );
    },
  );
}
