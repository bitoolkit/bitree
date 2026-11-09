import 'package:flutter/material.dart';

import '../../app/controller.dart';
import '../../extensions/ui/extension_sheet.dart';
import '../../l10n/l10n.dart';
import '../../ui/app_page.dart';
import '../../ui/section_label.dart';
import '../source.dart';
import 'source_detail_screen.dart';

typedef ListedSource = ({SourceInstance instance, SourceDefinition definition});

/// Sources the user manages, built-in platforms first in catalog order.
List<ListedSource> listedSources(AppController controller) {
  final catalog = controller.sources.catalog;
  final order = catalog.definitions.toList();
  return [
    for (final instance in controller.sources.instances)
      if (catalog[instance.definitionId] case final definition?
          when _isManageableSource(definition))
        (instance: instance, definition: definition),
  ]..sort(
    (left, right) => order
        .indexOf(left.definition)
        .compareTo(order.indexOf(right.definition)),
  );
}

class SourcesScreen extends StatefulWidget {
  const SourcesScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends State<SourcesScreen> {
  bool _installing = false;

  AppController get _app => widget.controller;

  Future<void> _install() async {
    setState(() => _installing = true);
    try {
      await installExtension(context, _app);
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  Future<void> _installFromUrl() async {
    setState(() => _installing = true);
    try {
      await installExtensionFromUrl(context, _app);
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_app.sources, _app.extensions]),
    builder: (context, _) {
      final l10n = context.l10n;
      final language = Localizations.localeOf(context).languageCode;
      final sources = listedSources(_app);
      final instanceCounts = <String, int>{};
      for (final source in sources) {
        instanceCounts.update(
          source.definition.id,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
      final packages = _app.extensions.packages.toList()
        ..sort(
          (left, right) => left.manifest.name
              .resolve(language)
              .compareTo(right.manifest.name.resolve(language)),
        );
      const tilePadding = EdgeInsets.symmetric(horizontal: 4, vertical: 4);
      return AppRoutePage(
        title: l10n.dataSourcesTitle,
        showProgress: _installing,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            for (final source in sources)
              ListTile(
                contentPadding: tilePadding,
                leading: Icon(_sourceIcon(source.definition.id)),
                title: Text(source.definition.name.resolve(language)),
                subtitle: switch (_subtitle(
                  context,
                  source.instance,
                  showAccount: instanceCounts[source.definition.id]! > 1,
                )) {
                  final text? => Text(text),
                  null => null,
                },
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => SourceDetailScreen(
                      controller: _app,
                      instanceId: source.instance.id,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            AppSectionHeader(l10n.extensionsTitle),
            for (final package in packages)
              ListTile(
                contentPadding: tilePadding,
                leading: const Icon(Icons.extension_outlined),
                title: Text(package.manifest.name.resolve(language)),
                subtitle: Text(
                  [
                    ...extensionProvides(_app, package, l10n, language),
                    if (_app.extensions.isBundled(package.manifest.id))
                      l10n.extensionBundled,
                  ].join(l10n.listSeparator),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showExtensionDetails(context, _app, package),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  onPressed: _installing ? null : _install,
                  icon: const Icon(Icons.folder_open_outlined),
                  label: Text(l10n.installExtensionFromFolder),
                ),
                TextButton.icon(
                  onPressed: _installing ? null : _installFromUrl,
                  icon: const Icon(Icons.link_rounded),
                  label: Text(l10n.installExtensionFromUrl),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );

  String? _subtitle(
    BuildContext context,
    SourceInstance instance, {
    required bool showAccount,
  }) {
    final l10n = context.l10n;
    final language = Localizations.localeOf(context).languageCode;
    final sources = _app.sources;
    final account = sources.account(instance.accountId);
    final implementation = switch (instance.implementationId) {
      final id? => sources.catalog[id],
      null => null,
    };
    final courses = sources.storedSelection(instance.id)?.courses ?? const [];
    final parts = [
      if (showAccount)
        account?.displayName ?? account?.identity ?? l10n.accountUnverified,
      if (!instance.enabled) l10n.disabled,
      if (implementation != null)
        l10n.sourceUsingImplementation(implementation.name.resolve(language)),
      if (courses.isNotEmpty)
        l10n.sourceCoursesSelected(
          courses.where((course) => course.selected).length,
          courses.length,
        ),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

IconData _sourceIcon(String definitionId) => switch (definitionId) {
  'builtin.bit.school' => Icons.account_balance_outlined,
  'builtin.bit.lexue' => Icons.menu_book_outlined,
  'builtin.bit.eclass' => Icons.forum_outlined,
  'builtin.icourse163.mooc' => Icons.play_circle_outline,
  'builtin.bit.physics-lab' => Icons.science_outlined,
  _ => Icons.extension_outlined,
};

bool _isManageableSource(SourceDefinition definition) =>
    definition.supports(SourceOperation.coursesList) ||
    definition.supports(SourceOperation.deadlinesRead) ||
    definition.supports(SourceOperation.deadlinesReadAccount) ||
    definition.settings.isNotEmpty ||
    definition.actions.isNotEmpty;
