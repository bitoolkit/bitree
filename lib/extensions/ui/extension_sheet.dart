import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../app/controller.dart';
import '../../l10n/l10n.dart';
import '../../sources/builtin.dart';
import '../../sources/source.dart';
import '../../ui/app_dialog.dart';
import '../../ui/app_notice.dart';
import '../../ui/section_label.dart';
import '../../ui/sheet_layout.dart';
import '../download.dart';
import '../package.dart';

/// Picks a package folder, shows what it provides and can access, then
/// installs it. Sources it extends switch to its implementation.
Future<void> installExtension(BuildContext context, AppController app) async {
  final l10n = context.l10n;
  final path = await FilePicker.getDirectoryPath(
    dialogTitle: l10n.installExtension,
  );
  if (path == null || !context.mounted) return;
  try {
    final package = await app.extensions.inspectDirectory(path);
    if (!context.mounted) return;
    final confirmed = await showAppSheet<bool>(
      context: context,
      builder: (_) => _ExtensionSheet(app: app, package: package),
    );
    if (confirmed != true) return;
    await app.extensions.install(package);
  } on Exception catch (error) {
    if (!context.mounted) return;
    await showAppDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.extensionInstallFailed),
        content: SelectableText('$error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.l10n.close),
          ),
        ],
      ),
    );
  }
}

Future<void> installExtensionFromUrl(
  BuildContext context,
  AppController app,
) async {
  final bundle = await showAppSheet<ExtensionBundle>(
    context: context,
    builder: (_) => _UrlExtensionSheet(app: app),
  );
  if (bundle == null || !context.mounted) return;
  final confirmed = await showAppSheet<bool>(
    context: context,
    builder: (_) => _ExtensionSheet(
      app: app,
      package: ExtensionPackage(
        manifest: bundle.manifest,
        location: 'download:${bundle.manifest.id}',
      ),
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await app.extensions.installDownload(bundle);
  } on Exception catch (error) {
    if (context.mounted) await _showInstallError(context, error);
  }
}

/// Shows an installed package and offers to uninstall it.
Future<void> showExtensionDetails(
  BuildContext context,
  AppController app,
  ExtensionPackage package,
) async {
  final bundled = app.extensions.isBundled(package.manifest.id);
  final l10n = context.l10n;
  final name = package.manifest.name.resolve(
    Localizations.localeOf(context).languageCode,
  );
  final uninstall = await showAppSheet<bool>(
    context: context,
    builder: (_) => _ExtensionSheet(
      app: app,
      package: package,
      installed: true,
      bundled: bundled,
    ),
  );
  if (bundled || uninstall != true || !context.mounted) return;
  final confirmed = await showAppConfirmDialog(
    context,
    title: l10n.uninstallExtensionQuestion(name),
    body: l10n.uninstallExtensionBody,
    confirmLabel: l10n.uninstallExtension,
    destructive: true,
  );
  if (!confirmed) return;
  try {
    await app.extensions.uninstall(package.manifest.id);
  } on Exception {
    if (context.mounted) showAppNotice(context, l10n.operationDeleteFailed);
  }
}

Future<void> _showInstallError(BuildContext context, Exception error) =>
    showAppDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.extensionInstallFailed),
        content: SelectableText('$error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.l10n.close),
          ),
        ],
      ),
    );

/// What a package adds to the source list, one line per declared source.
List<String> extensionProvides(
  AppController app,
  ExtensionPackage package,
  AppLocalizations l10n,
  String language,
) {
  final catalog = app.sources.catalog.withDefinitions(
    package.manifest.definitions,
  );
  return [
    for (final definition in package.manifest.definitions)
      if (definition.extendsId case final baseId?)
        l10n.extensionReplacesSource(
          catalog.require(baseId).name.resolve(language),
        )
      else
        l10n.extensionProvidesSource(definition.name.resolve(language)),
  ];
}

class _ExtensionSheet extends StatelessWidget {
  const _ExtensionSheet({
    required this.app,
    required this.package,
    this.installed = false,
    this.bundled = false,
  });

  final AppController app;
  final ExtensionPackage package;
  final bool installed;
  final bool bundled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final catalog = app.sources.catalog.withDefinitions(
      package.manifest.definitions,
    );
    final definitions = [
      for (final definition in package.manifest.definitions)
        catalog.require(definition.id),
    ];
    final switched = installed
        ? const <String>[]
        : [
            for (final fix in app.extensions.fixesAppliedBy(package))
              catalog.require(fix.extendsId!).name.resolve(language),
          ];
    Widget line(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 6),
      child: Text(text, style: theme.textTheme.bodyMedium),
    );
    return SheetLayout(
      header: SheetHeader(
        title: Row(
          children: [
            Expanded(child: Text(package.manifest.name.resolve(language))),
            if (bundled)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 8),
                child: Text(
                  l10n.extensionBundled,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
        actions: const [SheetCloseButton()],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '${l10n.extensionPackageVersion} ${package.manifest.version}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppSectionHeader(l10n.extensionProvides),
          for (final text in extensionProvides(app, package, l10n, language))
            line(text),
          if (switched.isNotEmpty)
            line(
              l10n.extensionInstallApplies(switched.join(l10n.listSeparator)),
            ),
          const SizedBox(height: 16),
          AppSectionHeader(l10n.extensionAccess),
          for (final text in _accessLines(definitions, l10n, language))
            line(text),
        ],
      ),
      actions: installed
          ? bundled
                ? null
                : SheetActionBar.actions(
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: Text(l10n.uninstallExtension),
                      ),
                    ],
                  )
          : SheetActionBar.primary(
              primary: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.install),
              ),
            ),
    );
  }
}

class _UrlExtensionSheet extends StatefulWidget {
  const _UrlExtensionSheet({required this.app});

  final AppController app;

  @override
  State<_UrlExtensionSheet> createState() => _UrlExtensionSheetState();
}

class _UrlExtensionSheetState extends State<_UrlExtensionSheet> {
  final _url = TextEditingController();
  final _sha256 = TextEditingController();
  bool _checking = false;
  String? _error;

  bool get _canCheck =>
      _url.text.trim().isNotEmpty && _sha256.text.trim().isNotEmpty;

  @override
  void dispose() {
    _url.dispose();
    _sha256.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final bundle = await widget.app.extensions.inspectDownload(
        url: _url.text,
        sha256: _sha256.text,
      );
      if (mounted) Navigator.pop(context, bundle);
    } on Exception catch (error) {
      if (mounted) {
        setState(() => _error = '$error');
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SheetLayout(
      header: SheetHeader(
        title: Text(l10n.installExtensionFromUrl),
        actions: const [SheetCloseButton()],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _url,
            enabled: !_checking,
            keyboardType: TextInputType.url,
            autocorrect: false,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: l10n.extensionDownloadUrl),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sha256,
            enabled: !_checking,
            autocorrect: false,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n.extensionDownloadSha256,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.extensionDownloadHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (_error case final error?) ...[
            const SizedBox(height: 12),
            SelectableText(
              error,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
        ],
      ),
      actions: SheetActionBar.primary(
        primary: FilledButton(
          onPressed: _checking || !_canCheck ? null : _check,
          child: Text(
            _checking
                ? l10n.extensionDownloadChecking
                : l10n.extensionDownloadAction,
          ),
        ),
      ),
    );
  }
}

List<String> _accessLines(
  List<SourceDefinition> definitions,
  AppLocalizations l10n,
  String language,
) {
  final hosts = <String>{};
  final sessions = <String>{};
  final cookies = <String>{};
  final read = <SourceResource>{};
  final edit = <SourceResource>{};
  for (final definition in definitions) {
    final permissions = definition.permissions;
    hosts.addAll(
      permissions.networkHosts.map((origin) => Uri.parse(origin).host),
    );
    sessions.addAll(permissions.sessionServices);
    cookies.addAll(permissions.cookies.keys);
    read.addAll(permissions.dataRead);
    edit.addAll(permissions.dataEdit);
  }
  String accounts(Set<String> services) =>
      {for (final service in services) _serviceName(service, language)}
          .join(l10n.listSeparator);
  String resources(Set<SourceResource> values) =>
      [for (final resource in values) l10n.sourceResource(resource.wireName)]
          .join(l10n.listSeparator);
  final lines = [
    if (hosts.isNotEmpty)
      l10n.extensionAccessWebsites(hosts.join(l10n.listSeparator)),
    if (sessions.isNotEmpty) l10n.extensionAccessAccounts(accounts(sessions)),
    if (cookies.isNotEmpty) l10n.extensionAccessCookies(accounts(cookies)),
    if (read.isNotEmpty) l10n.extensionAccessDataRead(resources(read)),
    if (edit.isNotEmpty) l10n.extensionAccessDataEdit(resources(edit)),
  ];
  return lines.isEmpty ? [l10n.extensionNoAccess] : lines;
}

/// Session services are named after the built-in source that signs in to it.
String _serviceName(String service, String language) {
  for (final definition in BuiltinSources.all) {
    if (definition.permissions.sessionServices.contains(service)) {
      return definition.name.resolve(language);
    }
  }
  return service;
}
