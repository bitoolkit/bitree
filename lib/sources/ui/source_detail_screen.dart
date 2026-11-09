import 'package:flutter/material.dart';

import '../../app/controller.dart';
import '../../extensions/lua_source.dart';
import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../schedule/model.dart';
import '../../ui/app_notice.dart';
import '../../ui/app_page.dart';
import '../../ui/section_label.dart';
import '../course_selection.dart';
import '../source.dart';

class SourceDetailScreen extends StatefulWidget {
  const SourceDetailScreen({
    super.key,
    required this.controller,
    required this.instanceId,
  });

  final AppController controller;
  final String instanceId;

  @override
  State<SourceDetailScreen> createState() => _SourceDetailScreenState();
}

class _SourceDetailScreenState extends State<SourceDetailScreen> {
  final _textFields = <String, TextEditingController>{};
  final _toggles = <String, bool>{};
  final _choices = <String, Object?>{};
  bool _discovering = false;
  String? _error;

  SourceInstance? get _instance =>
      widget.controller.sources.instance(widget.instanceId);

  SourceDefinition? get _definition {
    final instance = _instance;
    if (instance == null) return null;
    try {
      return widget.controller.sources.definitionFor(instance);
    } on FormatException {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    for (final controller in _textFields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _loadSettings() {
    final definition = _definition;
    final instance = _instance;
    if (definition == null || instance == null) return;
    for (final field in definition.settings) {
      final value = instance.settings[field.key] ?? field.defaultValue;
      if (field.type == SourceFieldType.toggle) {
        _toggles[field.key] = value == true;
      } else if (field.type == SourceFieldType.choice) {
        _choices[field.key] = value;
      } else {
        _textFields[field.key] = TextEditingController(
          text: value?.toString() ?? '',
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    final instance = _instance;
    final definition = _definition;
    if (instance == null || definition == null) return;
    final values = <String, Object?>{};
    try {
      for (final field in definition.settings) {
        if (field.type == SourceFieldType.toggle) {
          values[field.key] = _toggles[field.key] ?? false;
        } else if (field.type == SourceFieldType.choice) {
          values[field.key] = _choices[field.key];
        } else {
          final text = _textFields[field.key]?.text.trim() ?? '';
          if (text.isEmpty) {
            values[field.key] = null;
          } else if (field.type == SourceFieldType.integer) {
            values[field.key] = int.parse(text);
          } else if (field.type == SourceFieldType.number) {
            values[field.key] = double.parse(text);
          } else {
            values[field.key] = text;
          }
        }
      }
      await widget.controller.sources.setSettings(instance.id, values);
      if (mounted) {
        showAppNotice(context, context.l10n.settingsSaved);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    }
  }

  Future<void> _discoverCourses() async {
    final instance = _instance;
    if (instance == null) return;
    setState(() {
      _discovering = true;
      _error = null;
    });
    try {
      final result = await widget.controller.sourceHost.courses(
        instance,
        context: LuaOperationContext(config: instance.settings),
      );
      await widget.controller.sources.mergeDiscoveredCourses(
        instance.id,
        result.items,
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _discovering = false);
    }
  }

  Future<void> _addManualCourse() async {
    final id = TextEditingController();
    final name = TextEditingController();
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSectionHeader(context.l10n.addManualCourse),
            TextField(
              controller: id,
              autofocus: true,
              decoration: InputDecoration(
                labelText: context.l10n.courseInputHint,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: name,
              decoration: InputDecoration(
                labelText: context.l10n.courseName,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                if (id.text.trim().isEmpty || name.text.trim().isEmpty) return;
                Navigator.pop(sheetContext, true);
              },
              child: Text(context.l10n.add),
            ),
          ],
        ),
      ),
    );
    if (added != true || !mounted) {
      id.dispose();
      name.dispose();
      return;
    }
    await widget.controller.sources.addManualCourse(
      widget.instanceId,
      PlatformCourse(
        remoteId: id.text.trim(),
        name: name.text.trim(),
        manual: true,
      ),
    );
    id.dispose();
    name.dispose();
  }

  Future<void> _linkLocalCourses(PlatformCourse course) async {
    final localCourses = widget.controller.timetable.schedule?.courses ?? [];
    if (localCourses.isEmpty) {
      showAppNotice(context, context.l10n.noLocalCourses);
      return;
    }
    final selection = widget.controller.sources.selection(widget.instanceId);
    final selected = <String>{};
    for (final local in localCourses) {
      if (selection.remoteIdsForLocal(local.id).contains(course.remoteId)) {
        selected.add(local.id);
      }
    }
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setState) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              AppSectionHeader(context.l10n.linkLocalCourses),
              for (final local in localCourses)
                CheckboxListTile(
                  value: selected.contains(local.id),
                  title: Text(local.name),
                  subtitle: Text(_courseTime(local, context.l10n)),
                  onChanged: (value) => setState(() {
                    if (value == true) {
                      selected.add(local.id);
                    } else {
                      selected.remove(local.id);
                    }
                  }),
                ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(sheetContext, selected),
                child: Text(context.l10n.save),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    for (final local in localCourses) {
      if (result.contains(local.id)) {
        await widget.controller.sources.linkCourse(
          widget.instanceId,
          localCourseId: local.id,
          remoteId: course.remoteId,
        );
      } else if (selection
          .remoteIdsForLocal(local.id)
          .contains(course.remoteId)) {
        await widget.controller.sources.unlinkCourse(
          widget.instanceId,
          localCourseId: local.id,
          remoteId: course.remoteId,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller.sources,
    builder: (context, _) {
      final instance = _instance;
      final definition = _definition;
      final l10n = context.l10n;
      if (instance == null || definition == null) {
        return AppRoutePage(
          title: l10n.dataSourcesTitle,
          child: Center(child: Text(l10n.sourceUnavailable)),
        );
      }
      final selection = widget.controller.sources.selection(instance.id);
      return AppRoutePage(
        title: definition.name.resolve(
          Localizations.localeOf(context).languageCode,
        ),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            onPressed: _discovering ? null : _discoverCourses,
            icon: _discovering
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
          ),
        ],
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.enabled),
              value: instance.enabled,
              onChanged: (value) =>
                  widget.controller.sources.setEnabled(instance.id, value),
            ),
            _ImplementationField(
              controller: widget.controller,
              instance: instance,
            ),
            if (definition.operations.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                definition.operations
                    .map((operation) => operation.wireName)
                    .join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (definition.settings.isNotEmpty) ...[
              const SizedBox(height: 20),
              AppSectionHeader(l10n.sourceSettings),
              for (final field in definition.settings) _field(field, context),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _saveSettings,
                  child: Text(l10n.save),
                ),
              ),
            ],
            const SizedBox(height: 20),
            AppSectionHeader(l10n.sourceCourses),
            if (selection.courses.isEmpty)
              Text(
                _discovering ? l10n.discoveringCourses : l10n.noCourses,
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              for (final course in selection.courses)
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(course.name),
                  subtitle: course.manual
                      ? Text(l10n.manualCourse)
                      : course.remoteId == course.name
                      ? null
                      : Text(course.remoteId),
                  value: course.selected,
                  onChanged: (value) => widget.controller.sources
                      .setCourseSelected(instance.id, course.remoteId, value),
                  secondary: IconButton(
                    tooltip: l10n.linkLocalCourses,
                    onPressed: () => _linkLocalCourses(course),
                    icon: const Icon(Icons.link_rounded),
                  ),
                ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _addManualCourse,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l10n.addManualCourse),
                ),
                OutlinedButton.icon(
                  onPressed: _discovering ? null : _discoverCourses,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l10n.discoverCourses),
                ),
              ],
            ),
            if (_error case final error?) ...[
              const SizedBox(height: 20),
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

  Widget _field(SourceField field, BuildContext context) {
    final label = field.label.resolve(
      Localizations.localeOf(context).languageCode,
    );
    switch (field.type) {
      case SourceFieldType.toggle:
        return SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          value: _toggles[field.key] ?? false,
          onChanged: (value) => setState(() => _toggles[field.key] = value),
        );
      case SourceFieldType.choice:
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: DropdownButtonFormField<Object?>(
            initialValue: _choices[field.key],
            decoration: InputDecoration(labelText: label),
            items: [
              for (final option in field.options)
                DropdownMenuItem(
                  value: option.value,
                  child: Text(
                    option.label.resolve(
                      Localizations.localeOf(context).languageCode,
                    ),
                  ),
                ),
            ],
            onChanged: (value) => setState(() => _choices[field.key] = value),
          ),
        );
      default:
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: TextField(
            controller: _textFields[field.key],
            obscureText: field.type == SourceFieldType.secret,
            keyboardType:
                field.type == SourceFieldType.integer ||
                    field.type == SourceFieldType.number
                ? TextInputType.number
                : TextInputType.text,
            decoration: InputDecoration(labelText: label),
          ),
        );
    }
  }

  String _courseTime(Course course, AppLocalizations l10n) {
    if (!course.isScheduled) return l10n.sectionPending;
    return '${localizedWeekday(l10n, course.weekday ?? 1)} · '
        '${localizedCourseSection(l10n, course)} · '
        '${localizedWeeks(l10n, course.weeks)}';
  }
}

class _ImplementationField extends StatelessWidget {
  const _ImplementationField({
    required this.controller,
    required this.instance,
  });

  final AppController controller;
  final SourceInstance instance;

  @override
  Widget build(BuildContext context) {
    final definitions = controller.sources.catalog.definitions.where(
      (definition) =>
          definition.id == instance.definitionId ||
          definition.extendsId == instance.definitionId,
    );
    final values = definitions.toList();
    if (values.length < 2) return const SizedBox.shrink();
    return DropdownButtonFormField<String?>(
      initialValue: instance.implementationId,
      decoration: InputDecoration(
        labelText: context.l10n.sourceImplementation,
      ),
      items: [
        DropdownMenuItem(
          value: null,
          child: Text(context.l10n.sourceBuiltinImplementation),
        ),
        for (final definition in values)
          if (definition.extendsId != null)
            DropdownMenuItem(
              value: definition.id,
              child: Text(
                definition.name.resolve(
                  Localizations.localeOf(context).languageCode,
                ),
              ),
            ),
      ],
      onChanged: (value) => controller.sources.setImplementation(
        instance.id,
        value,
      ),
    );
  }
}
