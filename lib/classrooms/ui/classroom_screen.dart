import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/controller.dart';
import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../schedule/model.dart';
import '../../school/ui/school_screen.dart';
import '../../school/ui/school_verification_sheet.dart';
import '../../ui/app_dropdown_field.dart';
import '../../ui/app_page.dart';
import '../../ui/campus_time_builder.dart';
import '../../ui/design.dart';
import '../../ui/dialog_layout.dart';
import '../../ui/sheet_layout.dart';
import '../../wencui/place.dart';
import '../../wencui/ui/wencui_map_screen.dart';
import '../controller.dart';
import '../model.dart';
import 'classroom_time_field.dart';

enum _DateChoice { today, tomorrow, other }

class ClassroomScreen extends StatefulWidget {
  const ClassroomScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ClassroomScreen> createState() => _ClassroomScreenState();
}

class _ClassroomScreenState extends State<ClassroomScreen> {
  late final _queryState = ClassroomController(
    repository: widget.controller.classrooms,
    school: widget.controller.school,
    verify: (request) => verifySchoolLogin(context, request),
    signIn: () async =>
        mounted && await openSchoolLogin(context, widget.controller) == true,
    date: campusNow(),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_queryState.load());
    });
  }

  @override
  void dispose() {
    _queryState.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      builder: appPickerDialogBuilder,
      initialDate: _queryState.date,
      firstDate: DateTime(_queryState.date.year - 1),
      lastDate: DateTime(_queryState.date.year + 1, 12, 31),
    );
    if (date != null && mounted) _queryState.selectDate(date);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _queryState,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) => CampusTimeBuilder(
    active: true,
    builder: (context, now) => AppRoutePage(
      title: context.l10n.emptyClassroomQuery,
      maxWidth: 960,
      actions: [
        IconButton(
          tooltip: context.l10n.refresh,
          onPressed: () => _queryState.load(refresh: true),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: _buildQuery(now),
            ),
          ),
          ..._buildResults(now),
        ],
      ),
    ),
  );

  Widget _buildQuery(DateTime now) {
    final directory = _queryState.directory;
    if (directory == null) {
      return _queryState.busy
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          : OutlinedButton.icon(
              onPressed: () => _queryState.load(refresh: true),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.l10n.loadBuildings),
            );
    }
    if (directory.campuses.isEmpty) {
      return _QueryState(
        message: context.l10n.noQueryableCampuses,
        action: context.l10n.reloadAction,
        onPressed: () => _queryState.load(refresh: true),
      );
    }

    final today = calendarDate(now);
    final tomorrow = today.add(const Duration(days: 1));
    final dateChoice = _queryState.date == today
        ? _DateChoice.today
        : _queryState.date == tomorrow
        ? _DateChoice.tomorrow
        : _DateChoice.other;
    final style = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(fontSize: 13);
    final l10n = context.l10n;

    return _QueryFields(
      children: [
        AppDropdownField<String>(
          label: l10n.campus,
          value: _queryState.campusCode!,
          textStyle: style,
          entries: [
            for (final campus in directory.campuses)
              DropdownMenuEntry(value: campus.code, label: campus.name),
          ],
          onChanged: _queryState.selectCampus,
        ),
        AppDropdownField<_DateChoice>(
          label: l10n.date,
          value: dateChoice,
          textStyle: style,
          entries: [
            DropdownMenuEntry(
              value: _DateChoice.today,
              label: l10n.todayDate('${today.month}/${today.day}'),
            ),
            DropdownMenuEntry(
              value: _DateChoice.tomorrow,
              label: l10n.tomorrowDate('${tomorrow.month}/${tomorrow.day}'),
            ),
            DropdownMenuEntry(
              value: _DateChoice.other,
              label: _queryState.date.year == now.year
                  ? '${_queryState.date.month}/${_queryState.date.day} '
                        '${localizedShortWeekday(l10n, _queryState.date.weekday)}'
                  : dateText(_queryState.date),
              labelWidget: Text(l10n.otherDate),
            ),
          ],
          onChanged: (value) {
            switch (value) {
              case _DateChoice.today:
                _queryState.selectDate(today);
              case _DateChoice.tomorrow:
                _queryState.selectDate(tomorrow);
              case _DateChoice.other:
                unawaited(_pickDate());
            }
          },
        ),
        AppDropdownField<String?>(
          label: l10n.building,
          value: _queryState.buildingFilter,
          textStyle: style,
          entries: [
            DropdownMenuEntry(value: null, label: l10n.allBuildings),
            if (_queryState.buildings.any((building) => building.isWenCui))
              DropdownMenuEntry(
                value: wenCuiBuildingFilter,
                label: l10n.wencuiBuildingAll,
              ),
            for (final building in _queryState.buildings)
              DropdownMenuEntry(
                value: buildingFilterKey(building),
                label: building.name,
              ),
          ],
          onChanged: (value) => _queryState.selectBuilding(value),
        ),
        ClassroomTimeField(
          value: _queryState.period,
          date: _queryState.date,
          now: now,
          onChanged: (value) => _queryState.selectPeriod(value),
        ),
      ],
    );
  }

  List<Widget> _buildResults(DateTime now) {
    if (_queryState.directory == null ||
        _queryState.directory!.campuses.isEmpty) {
      return const [];
    }
    final period = _queryState.period;
    final groups = _queryState.results;
    final count = groups.fold(0, (total, group) => total + group.rooms.length);
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final current = _queryState.date == calendarDate(now)
        ? currentClassroomSection(now)
        : null;

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      period == null
                          ? l10n.classroomFreeTime
                          : l10n.roomsMatchingPeriod,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _queryState.busy
                          ? l10n.querying
                          : !_queryState.hasResult
                          ? ''
                          : l10n.roomCount(count),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                period == null
                    ? l10n.showsFreePeriods
                    : l10n.freeThroughoutPeriod(period.localizedTime(l10n)),
                style: theme.textTheme.bodySmall,
              ),
              if (_queryState.busy) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(minHeight: appProgressHeight),
              ],
              if (!_queryState.busy && !_queryState.hasResult)
                _QueryState(
                  message: widget.controller.school.username == null
                      ? l10n.loginToQuery
                      : l10n.queryIncomplete,
                  action: l10n.queryAgain,
                  onPressed: _queryState.query,
                )
              else if (!_queryState.busy && groups.isEmpty)
                _QueryState(
                  message: _queryState.buildings.isEmpty
                      ? l10n.noBuildingInfo
                      : period != null
                      ? l10n.noFreeClassrooms
                      : l10n.noFreePeriods,
                  action: _queryState.buildings.isEmpty
                      ? l10n.reloadBuildings
                      : period != null
                      ? l10n.viewAnyPeriod
                      : _queryState.buildingFilter != null
                      ? l10n.viewAllBuildings
                      : l10n.changeDate,
                  onPressed: () {
                    if (_queryState.buildings.isEmpty) {
                      unawaited(_queryState.load(refresh: true));
                    } else if (period != null) {
                      _queryState.selectPeriod(null);
                    } else if (_queryState.buildingFilter != null) {
                      _queryState.selectBuilding(null);
                    } else {
                      unawaited(_pickDate());
                    }
                  },
                ),
            ],
          ),
        ),
      ),
      for (final group in groups) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
            child: Text(group.building.name, style: theme.textTheme.bodySmall),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.builder(
            itemCount: group.rooms.length,
            itemBuilder: (context, index) {
              final room = group.rooms[index];
              return DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(room.name),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        for (final free in room.freePeriods)
                          Text(
                            free.localizedTime(l10n),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  (period != null
                                      ? free.includes(period)
                                      : current != null &&
                                            free.contains(current))
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                  onTap: () => _showRoom(
                    context,
                    widget.controller,
                    group.building,
                    room,
                    _queryState.date,
                  ),
                ),
              );
            },
          ),
        ),
      ],
      if (groups.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Text(
              context.l10n.freeMeansNoClass,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ),
    ];
  }
}

class _QueryFields extends StatelessWidget {
  const _QueryFields({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final minimumWidth = MediaQuery.textScalerOf(context).scale(13) * 8 + 36;
      final columns = constraints.maxWidth >= 720 * scale
          ? 4
          : constraints.maxWidth >= minimumWidth * 2 + 8
          ? 2
          : 1;
      final width = (constraints.maxWidth - 8 * (columns - 1)) / columns;
      return Wrap(
        spacing: 8,
        runSpacing: 12,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class _QueryState extends StatelessWidget {
  const _QueryState({
    required this.message,
    required this.action,
    required this.onPressed,
  });

  final String message;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message),
        const SizedBox(height: 8),
        TextButton(onPressed: onPressed, child: Text(action)),
      ],
    ),
  );
}

Future<void> _showRoom(
  BuildContext context,
  AppController controller,
  SchoolBuilding building,
  ClassroomOccupancy room,
  DateTime date,
) => showAppSheet<void>(
  context: context,
  builder: (sheetContext) {
    final l10n = sheetContext.l10n;
    return SheetLayout(
      header: SheetHeader(
        title: Text('${building.name} ${room.name}'),
        actions: const [SheetCloseButton()],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${dateText(date)} '
            '${localizedShortWeekday(l10n, date.weekday)}',
            style: Theme.of(sheetContext).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          for (final block in room.periods)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(block.period.localizedTime(l10n)),
              subtitle: Text(block.period.localizedSection(l10n)),
              trailing: Text(
                block.busy ? l10n.busyStatus : l10n.freeStatus,
                style: TextStyle(
                  color: block.busy
                      ? Theme.of(sheetContext).colorScheme.onSurfaceVariant
                      : Theme.of(sheetContext).colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
      actions: WencuiPlace.parse('${building.name} ${room.name}') == null
          ? null
          : SheetActionBar.actions(
              children: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => WencuiMapScreen(
                          controller: controller,
                          initialRoom: '${building.name} ${room.name}',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: Text(l10n.wencuiMap),
                ),
              ],
            ),
    );
  },
);
