import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../app/controller.dart';
import '../../automation/ui/automation_screen.dart';
import '../../l10n/l10n.dart';
import '../../sources/source.dart';
import '../../ui/app_notice.dart';
import '../../ui/app_page.dart';
import '../../ui/section_label.dart';
import '../package.dart';

class ExtensionsScreen extends StatefulWidget {
  const ExtensionsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ExtensionsScreen> createState() => _ExtensionsScreenState();
}

class _ExtensionsScreenState extends State<ExtensionsScreen> {
  bool _installing = false;
  String? _error;

  Future<void> _install() async {
    setState(() {
      _installing = true;
      _error = null;
    });
    try {
      final path = await FilePicker.getDirectoryPath(
        dialogTitle: context.l10n.installExtension,
      );
      if (path == null || !mounted) return;
      await widget.controller.extensions.installDirectory(path);
      if (mounted) showAppNotice(context, context.l10n.extensionInstalled);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller.extensions,
    builder: (context, _) {
      final l10n = context.l10n;
      final language = Localizations.localeOf(context).languageCode;
      final packages = widget.controller.extensions.packages.toList()
        ..sort(
          (left, right) => left.manifest.name
              .resolve(language)
              .compareTo(right.manifest.name.resolve(language)),
        );
      return AppRoutePage(
        title: l10n.extensionsTitle,
        showProgress: _installing,
        actions: [
          IconButton(
            tooltip: l10n.installExtension,
            onPressed: _installing ? null : _install,
            icon: const Icon(Icons.folder_open_outlined),
          ),
        ],
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: const Icon(Icons.code_rounded),
              title: Text(l10n.automationTitle),
              subtitle: Text(l10n.automationDescription),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => AutomationScreen(
                    controller: widget.controller.automation,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            AppSectionHeader(l10n.extensionsTitle),
            if (packages.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.extensionsEmpty),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _installing ? null : _install,
                      icon: const Icon(Icons.folder_open_outlined),
                      label: Text(l10n.installExtension),
                    ),
                  ],
                ),
              )
            else
              for (final package in packages)
                _PackageTile(
                  controller: widget.controller,
                  package: package,
                  language: language,
                ),
            if (_error case final error?) ...[
              const SizedBox(height: 16),
              SelectableText(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class _PackageTile extends StatelessWidget {
  const _PackageTile({
    required this.controller,
    required this.package,
    required this.language,
  });

  final AppController controller;
  final ExtensionPackage package;
  final String language;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    leading: const Icon(Icons.extension_outlined),
    title: Text(package.manifest.name.resolve(language)),
    subtitle: Text(
      '${package.manifest.version} · '
      '${package.enabled ? context.l10n.enabled : context.l10n.disabled}',
    ),
    trailing: Switch.adaptive(
      value: package.enabled,
      onChanged: (value) =>
          controller.extensions.setEnabled(package.manifest.id, value),
    ),
    onTap: () => showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(package.manifest.name.resolve(language)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${context.l10n.extensionPackageVersion} ${package.manifest.version}',
              ),
              const SizedBox(height: 12),
              for (final source in package.manifest.sources) ...[
                Text(
                  source.name.resolve(language),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  source.permissions == null
                      ? ''
                      : _permissionsText(source.permissions!, context),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.close),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await controller.extensions.uninstall(package.manifest.id);
            },
            child: Text(context.l10n.uninstallExtension),
          ),
        ],
      ),
    ),
  );

  String _permissionsText(SourcePermissions permissions, BuildContext context) {
    final parts = <String>[
      if (permissions.networkHosts.isNotEmpty)
        permissions.networkHosts.join(', '),
      if (permissions.sessionServices.isNotEmpty)
        permissions.sessionServices.join(', '),
      if (permissions.dataRead.isNotEmpty)
        '${context.l10n.dataRead}: '
            '${permissions.dataRead.map((item) => item.wireName).join(', ')}',
    ];
    return parts.join('\n');
  }
}
