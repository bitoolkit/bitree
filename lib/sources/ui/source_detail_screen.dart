import 'package:flutter/material.dart';

import '../../app/controller.dart';
import '../../extensions/ui/extension_sheet.dart';
import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../schedule/model.dart';
import '../../sync/controller.dart';
import '../../sync/ui/sync.dart';
import '../../ui/app_dialog.dart';
import '../../ui/app_menu_anchor.dart';
import '../../ui/app_notice.dart';
import '../../ui/app_page.dart';
import '../../ui/section_label.dart';
import '../../ui/sheet_layout.dart';
import '../course_selection.dart';
import '../runtime.dart';
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

enum _InstallSource { folder, url }

typedef _ImplementationChoice = ({String? id, _InstallSource? install});

class _SourceDetailScreenState extends State<SourceDetailScreen> {
  final _textFields = <String, TextEditingController>{};
  final _toggles = <String, bool>{};
  final _choices = <String, Object?>{};
  String? _fieldsDefinitionId;
  bool _discovering = false;
  bool _syncing = false;
  String? _error;

  AppController get _app => widget.controller;

  SourceInstance? get _instance => _app.sources.instance(widget.instanceId);

  SourceDefinition? get _definition {
    final instance = _instance;
    if (instance == null) return null;
    try {
      return _app.sources.definitionFor(instance);
    } on FormatException {
      return null;
    }
  }

  @override
  void dispose() {
    for (final controller in _textFields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Settings fields follow the effective definition, which changes with the
  /// chosen implementation.
  void _loadSettings(SourceDefinition definition, SourceInstance instance) {
    if (_fieldsDefinitionId == definition.id) return;
    _fieldsDefinitionId = definition.id;
    final previous = _textFields.values.toList();
    if (previous.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final controller in previous) {
          controller.dispose();
        }
      });
    }
    _textFields.clear();
    _toggles.clear();
    _choices.clear();
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
      await _app.sources.setSettings(instance.id, values);
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
      final result = await _app.sourceHost.courses(
        instance,
        context: SourceOperationContext(config: instance.settings),
      );
      await _app.sources.mergeDiscoveredCourses(instance.id, result.items);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _discovering = false);
    }
  }

  /// Built-in platforms share the app's sync round, including sign-in and
  /// progress. Extension sources sync here.
  Future<void> _syncNow(SourceInstance instance) async {
    setState(() => _error = null);
    final target = syncTargetForDefinition(instance.definitionId);
    if (target != null) {
      await startSync(context, _app, targets: {target});
      return;
    }
    setState(() => _syncing = true);
    try {
      final result = await _app.sourceSync.synchronize(instance);
      if (!mounted) return;
      if (result.failures.isEmpty) {
        showAppNotice(
          context,
          context.l10n.syncedDdlCount(result.deadlineCount),
        );
      } else {
        setState(
          () => _error = [
            for (final failure in result.failures)
              '${failure.course}：${failure.error}',
          ].join('\n'),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _chooseImplementation(SourceInstance instance) async {
    final l10n = context.l10n;
    final language = Localizations.localeOf(context).languageCode;
    final builtInId = _app.extensions.bundledImplementationFor(
      instance.definitionId,
    );
    final implementations = _app.sources.catalog.definitions
        .where(
          (definition) =>
              definition.extendsId == instance.definitionId ||
              definition.extendsId == instance.implementationId ||
              definition.extendsId == builtInId,
        )
        .toList();
    Widget option(
      BuildContext sheetContext,
      String title,
      String? id, {
      String? subtitle,
    }) {
      final selected = instance.implementationId == id;
      return ListTile(
        selected: selected,
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: selected ? const Icon(Icons.check_rounded) : null,
        onTap: () => Navigator.pop(sheetContext, (id: id, install: null)),
      );
    }

    final choice = await showAppSheet<_ImplementationChoice>(
      context: context,
      builder: (sheetContext) => SheetLayout(
        header: SheetHeader(
          title: Text(l10n.sourceImplementation),
          actions: const [SheetCloseButton()],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            option(
              sheetContext,
              builtInId == null
                  ? l10n.sourceBuiltinImplementation
                  : l10n.sourceBundledImplementation,
              builtInId,
            ),
            for (final definition in implementations)
              option(
                sheetContext,
                definition.name.resolve(language),
                definition.id,
                subtitle:
                    '${l10n.extensionPackageVersion} ${definition.version}',
              ),
            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: Text(l10n.installExtensionFromFolder),
              onTap: () => Navigator.pop(
                sheetContext,
                (id: null, install: _InstallSource.folder),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: Text(l10n.installExtensionFromUrl),
              onTap: () => Navigator.pop(
                sheetContext,
                (id: null, install: _InstallSource.url),
              ),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice.install case final source?) {
      switch (source) {
        case _InstallSource.folder:
          await installExtension(context, _app);
        case _InstallSource.url:
          await installExtensionFromUrl(context, _app);
      }
      return;
    } else if (choice.id != instance.implementationId) {
      await _app.sources.setImplementation(instance.id, choice.id);
    }
  }

  Future<void> _addManualCourse() async {
    final instance = _instance;
    if (instance == null) return;
    final input = TextEditingController();
    PlatformCourse? course;
    var resolving = false;
    String? error;
    course = await showAppSheet<PlatformCourse>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SheetLayout(
          header: SheetHeader(
            title: Text(context.l10n.addManualCourse),
            actions: const [SheetCloseButton()],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: input,
                autofocus: true,
                enabled: !resolving,
                decoration: InputDecoration(
                  labelText: context.l10n.courseInputHint,
                ),
              ),
              if (error case final error?) ...[
                const SizedBox(height: 8),
                Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
          actions: SheetActionBar.primary(
            primary: FilledButton(
              onPressed: resolving
                  ? null
                  : () async {
                      final value = input.text.trim();
                      if (value.isEmpty) return;
                      setSheetState(() {
                        resolving = true;
                        error = null;
                      });
                      try {
                        final resolved = await _app.sourceHost.resolveCourse(
                          instance,
                          query: {'input': value},
                        );
                        if (sheetContext.mounted) {
                          Navigator.pop(sheetContext, resolved);
                        }
                      } catch (failure) {
                        if (sheetContext.mounted) {
                          setSheetState(() {
                            resolving = false;
                            error = failure.toString();
                          });
                        }
                      }
                    },
              child: Text(context.l10n.add),
            ),
          ),
        ),
      ),
    );
    input.dispose();
    if (course == null || !mounted) return;
    await _app.sources.addManualCourse(widget.instanceId, course);
  }

  Future<void> _removeManualCourse(PlatformCourse course) async {
    final l10n = context.l10n;
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.removeManualCourseQuestion(course.name),
      body: l10n.removeManualCourseBody,
      confirmLabel: l10n.remove,
      destructive: true,
    );
    if (!confirmed) return;
    await _app.sources.removeManualCourse(widget.instanceId, course.remoteId);
  }

  Future<void> _linkLocalCourses(PlatformCourse course) async {
    final localCourses = _app.timetable.schedule?.courses ?? [];
    if (localCourses.isEmpty) {
      showAppNotice(context, context.l10n.noLocalCourses);
      return;
    }
    final selection = _app.sources.selection(widget.instanceId);
    final selected = <String>{};
    for (final local in localCourses) {
      if (selection.remoteIdsForLocal(local.id).contains(course.remoteId)) {
        selected.add(local.id);
      }
    }
    final result = await showAppSheet<Set<String>>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setState) => SheetLayout(
          header: SheetHeader(
            title: Text(context.l10n.linkLocalCourses),
            actions: const [SheetCloseButton()],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
            ],
          ),
          actions: SheetActionBar.primary(
            primary: FilledButton(
              onPressed: () => Navigator.pop(sheetContext, selected),
              child: Text(context.l10n.save),
            ),
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    for (final local in localCourses) {
      if (result.contains(local.id)) {
        await _app.sources.linkCourse(
          widget.instanceId,
          localCourseId: local.id,
          remoteId: course.remoteId,
        );
      } else if (selection
          .remoteIdsForLocal(local.id)
          .contains(course.remoteId)) {
        await _app.sources.unlinkCourse(
          widget.instanceId,
          localCourseId: local.id,
          remoteId: course.remoteId,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_app.sources, _app.sync, _app.timetable]),
    builder: (context, _) {
      final instance = _instance;
      final definition = _definition;
      final base = instance == null
          ? null
          : _app.sources.catalog[instance.definitionId];
      final l10n = context.l10n;
      if (instance == null || definition == null || base == null) {
        return AppRoutePage(
          title: l10n.dataSourcesTitle,
          child: Center(child: Text(l10n.sourceUnavailable)),
        );
      }
      _loadSettings(definition, instance);
      final language = Localizations.localeOf(context).languageCode;
      final theme = Theme.of(context);
      final target = syncTargetForDefinition(instance.definitionId);
      final syncing =
          _syncing || (target != null && _app.sync.isRunning(target));
      final busy = syncing || _discovering;
      final selection = _app.sources.selection(instance.id);
      final implementationId = instance.implementationId;
      final localNames = {
        for (final schedule in _app.timetable.schedules)
          for (final course in schedule.courses) course.id: course.name,
      };
      return AppRoutePage(
        title: base.name.resolve(language),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.enabled),
              subtitle: instance.enabled ? null : Text(l10n.sourceDisabledHint),
              value: instance.enabled,
              onChanged: (value) => _app.sources.setEnabled(instance.id, value),
            ),
            if (target != null ||
                definition.supports(SourceOperation.deadlinesRead))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: FilledButton.icon(
                  onPressed: instance.enabled && !busy
                      ? () => _syncNow(instance)
                      : null,
                  icon: syncing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded),
                  label: Text(l10n.sourceSyncNow),
                ),
              ),
            if (_error case final error?) ...[
              const SizedBox(height: 16),
              SelectableText(
                error,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            if (base.builtin) ...[
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.sourceImplementation),
                subtitle: Text(
                  implementationId == null
                      ? l10n.sourceBuiltinImplementation
                      : definition.name.resolve(language),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _chooseImplementation(instance),
              ),
            ],
            if (definition.settings.isNotEmpty) ...[
              const SizedBox(height: 24),
              AppSectionHeader(l10n.sourceSettings),
              for (final field in definition.settings) _field(field, context),
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton.tonal(
                  onPressed: _saveSettings,
                  child: Text(l10n.save),
                ),
              ),
            ],
            if (definition.supports(SourceOperation.coursesList)) ...[
              const SizedBox(height: 24),
              AppSectionHeader(
                l10n.sourceCourses,
                trailing: IconButton(
                  tooltip: l10n.discoverCourses,
                  visualDensity: VisualDensity.compact,
                  onPressed: instance.enabled && !busy
                      ? _discoverCourses
                      : null,
                  icon: _discovering
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                ),
              ),
              if (selection.courses.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    _discovering ? l10n.discoveringCourses : l10n.noCourses,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                for (final course in selection.courses)
                  _courseTile(instance, selection, course, localNames),
              if (definition.supports(SourceOperation.coursesResolve))
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: instance.enabled ? _addManualCourse : null,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(l10n.addManualCourse),
                  ),
                ),
            ],
          ],
        ),
      );
    },
  );

  Widget _courseTile(
    SourceInstance instance,
    SourceCourseSelection selection,
    PlatformCourse course,
    Map<String, String> localNames,
  ) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final linked = [
      for (final id in selection.localIdsForRemote(course.remoteId))
        ?localNames[id],
    ];
    final details = [
      if (course.manual) l10n.manualCourse,
      if (linked.isNotEmpty)
        l10n.courseLinkedTo(linked.join(l10n.listSeparator)),
    ];
    void toggle() => _app.sources.setCourseSelected(
      instance.id,
      course.remoteId,
      !course.selected,
    );
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Checkbox(value: course.selected, onChanged: (_) => toggle()),
      title: Text(course.name),
      subtitle: details.isEmpty ? null : Text(details.join(' · ')),
      onTap: toggle,
      trailing: AppMenuAnchor(
        menuChildren: [
          AppMenuItemButton(
            leadingIcon: const Icon(Icons.link_rounded),
            onPressed: () => _linkLocalCourses(course),
            child: Text(l10n.linkLocalCourses),
          ),
          if (course.manual && !course.discovered)
            AppMenuItemButton(
              leadingIcon: Icon(
                Icons.remove_circle_outline_rounded,
                color: scheme.error,
              ),
              style: TextButton.styleFrom(foregroundColor: scheme.error),
              onPressed: () => _removeManualCourse(course),
              child: Text(l10n.remove),
            ),
        ],
        builder: (context, menu, isOpen) => IconButton(
          tooltip: l10n.more,
          onPressed: () => isOpen ? menu.close() : menu.open(),
          icon: const Icon(Icons.more_horiz_rounded),
        ),
      ),
    );
  }

  Widget _field(SourceField field, BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    final label = field.label.resolve(language);
    final key = ValueKey('$_fieldsDefinitionId/${field.key}');
    switch (field.type) {
      case SourceFieldType.toggle:
        return SwitchListTile.adaptive(
          key: key,
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          value: _toggles[field.key] ?? false,
          onChanged: (value) => setState(() => _toggles[field.key] = value),
        );
      case SourceFieldType.choice:
        return Padding(
          key: key,
          padding: const EdgeInsets.only(top: 8),
          child: DropdownButtonFormField<Object?>(
            initialValue: _choices[field.key],
            decoration: InputDecoration(labelText: label),
            items: [
              for (final option in field.options)
                DropdownMenuItem(
                  value: option.value,
                  child: Text(option.label.resolve(language)),
                ),
            ],
            onChanged: (value) => setState(() => _choices[field.key] = value),
          ),
        );
      default:
        return Padding(
          key: key,
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
