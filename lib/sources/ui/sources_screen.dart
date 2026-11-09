import 'package:flutter/material.dart';

import '../../app/controller.dart';
import '../../l10n/l10n.dart';
import '../../ui/app_page.dart';
import '../../ui/section_label.dart';
import '../source.dart';
import 'source_detail_screen.dart';

class SourcesScreen extends StatelessWidget {
  const SourcesScreen({super.key, required this.controller});

  final AppController controller;

  Future<void> _addSource(BuildContext context) async {
    final l10n = context.l10n;
    final definitions = controller.sources.catalog.definitions.toList()
      ..sort(
        (left, right) => left.name
            .resolve(Localizations.localeOf(context).languageCode)
            .compareTo(
              right.name.resolve(Localizations.localeOf(context).languageCode),
            ),
      );
    final selected = await showModalBottomSheet<SourceDefinition>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            AppSectionHeader(l10n.addSource),
            for (final definition in definitions)
              ListTile(
                leading: Icon(_sourceIcon(definition.id)),
                title: Text(
                  definition.name.resolve(
                    Localizations.localeOf(sheetContext).languageCode,
                  ),
                ),
                subtitle: Text(
                  definition.builtin
                      ? l10n.sourceBuiltinImplementation
                      : '${l10n.extensionPackageVersion} ${definition.version}',
                ),
                onTap: () => Navigator.pop(sheetContext, definition),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !context.mounted) return;
    final account = _accountFor(selected);
    final instance = controller.sources.ensureInstance(
      selected.id,
      accountId: account?.id,
    );
    await controller.sources.persist();
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SourceDetailScreen(
          controller: controller,
          instanceId: instance.id,
        ),
      ),
    );
  }

  SourceAccount? _accountFor(SourceDefinition definition) {
    for (final account in controller.sources.accounts) {
      if (definition.permissions.sessionServices.contains(account.service)) {
        return account;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      controller.sources,
      controller.extensions,
      controller.school,
      controller.mooc,
    ]),
    builder: (context, _) {
      final l10n = context.l10n;
      final language = Localizations.localeOf(context).languageCode;
      final instances = controller.sources.instances.toList()
        ..sort((left, right) {
          final leftName =
              _definitionFor(left.id)?.name.resolve(language) ?? '';
          final rightName =
              _definitionFor(right.id)?.name.resolve(language) ?? '';
          return leftName.compareTo(rightName);
        });
      return AppRoutePage(
        title: l10n.dataSourcesTitle,
        actions: [
          IconButton(
            tooltip: l10n.addSource,
            onPressed: () => _addSource(context),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
        child: instances.isEmpty
            ? _EmptySources(onAdd: () => _addSource(context))
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  for (final instance in instances)
                    if (_definitionFor(instance.id) case final definition?)
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        leading: Icon(_sourceIcon(definition.id)),
                        title: Text(definition.name.resolve(language)),
                        subtitle: Text(_subtitle(instance)),
                        trailing: Switch.adaptive(
                          value: instance.enabled,
                          onChanged: (value) =>
                              controller.sources.setEnabled(instance.id, value),
                        ),
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => SourceDetailScreen(
                              controller: controller,
                              instanceId: instance.id,
                            ),
                          ),
                        ),
                      ),
                ],
              ),
      );
    },
  );

  SourceDefinition? _definitionFor(String instanceId) {
    final instance = controller.sources.instance(instanceId);
    if (instance == null) return null;
    try {
      return controller.sources.definitionFor(instance);
    } on FormatException {
      return null;
    }
  }

  String _subtitle(SourceInstance instance) {
    final account = controller.sources.account(instance.accountId);
    if (account == null) return '';
    return account.displayName ?? account.identity ?? account.service;
  }
}

class _EmptySources extends StatelessWidget {
  const _EmptySources({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: FilledButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add_rounded),
        label: Text(context.l10n.addSource),
      ),
    ),
  );
}

IconData _sourceIcon(String definitionId) => switch (definitionId) {
  'builtin.bit.school' => Icons.account_balance_outlined,
  'builtin.bit.lexue' => Icons.menu_book_outlined,
  'builtin.bit.eclass' => Icons.forum_outlined,
  'builtin.icourse163.mooc' => Icons.play_circle_outline,
  'builtin.bit.physics-lab' => Icons.science_outlined,
  _ => Icons.extension_outlined,
};
