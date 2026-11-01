import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/diagnostics.dart';
import '../../l10n/l10n.dart';
import '../../ui/app_notice.dart';
import '../../ui/app_page.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final _scroll = ScrollController();
  String? _preview;
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final preview = await AppDiagnostics.instance.recentLines();
      if (mounted) setState(() => _preview = preview);
    } on Exception catch (failure, stack) {
      AppDiagnostics.instance.report('读取日志', failure, stack);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _export() async {
    final l10n = context.l10n;
    setState(() => _exporting = true);
    try {
      final bytes = await AppDiagnostics.instance.export();
      if (!mounted) return;
      final date = DateTime.now().toIso8601String().substring(0, 10);
      final saved = await FilePicker.saveFile(
        fileName: 'BITree-logs-$date.txt',
        bytes: bytes,
        mimeType: 'text/plain',
        dialogTitle: l10n.exportLogs,
      );
      if (mounted && saved != null) showAppNotice(context, l10n.logsExported);
    } on Exception catch (failure, stack) {
      AppDiagnostics.instance.report('导出日志', failure, stack);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppRoutePage(
      title: l10n.logsTitle,
      actions: [
        IconButton(
          tooltip: l10n.refresh,
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.logsRecent, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Expanded(child: _buildPreview(context)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _exporting ? null : _export,
              icon: _exporting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_download_outlined, size: 20),
              label: Text(_exporting ? l10n.exportingLogs : l10n.exportLogs),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    final l10n = context.l10n;
    if (_loading) return const Center(child: CircularProgressIndicator());
    final preview = _preview;
    if (preview == null) {
      return Center(
        child: TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(l10n.reloadLogs),
        ),
      );
    }
    if (preview.isEmpty) return Center(child: Text(l10n.noLogs));

    return SingleChildScrollView(
      controller: _scroll,
      padding: const EdgeInsetsDirectional.only(end: 16),
      child: SelectableText(
        preview,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(fontFamily: 'monospace', height: 1.5),
      ),
    );
  }
}
