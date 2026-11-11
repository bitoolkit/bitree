import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../schedule/controller.dart';
import '../../schedule/location.dart';
import '../../schedule/model.dart';
import '../../ui/app_page.dart';
import '../../ui/design.dart';
import '../../ui/sheet_layout.dart';
import '../atlas.dart';
import '../place.dart';
import 'floor_map.dart';
import 'wencui_map_controls.dart';

class WencuiMapScreen extends StatefulWidget {
  const WencuiMapScreen({
    super.key,
    required this.timetable,
    this.initialRoom = '',
    this.initialCourse,
    this.initialOverview = false,
  });
  final TimetableController timetable;
  final String initialRoom;
  final Course? initialCourse;
  final bool initialOverview;

  @override
  State<WencuiMapScreen> createState() => _WencuiMapScreenState();
}

class _WencuiMapScreenState extends State<WencuiMapScreen> {
  final _search = SearchController();
  final _camera = WencuiMapController();
  final _floorMenu = MenuController();
  final _facilities = <WencuiFeatureKind>{};
  late final _loading = WencuiAtlas.load();
  WencuiPlace? _place;
  WencuiFeature? _selected;
  Course? _course;
  int _floor = 1;

  WencuiWing? get _wing => _selected?.wing ?? _place?.wing;

  @override
  void initState() {
    super.initState();
    _course = widget.initialCourse;
    _place = WencuiPlace.parse(_course?.room ?? widget.initialRoom);
    _floor = _place?.floor ?? _place?.wing.firstFloor ?? 1;
    _loading.then(
      (atlas) {
        if (!mounted) return;
        setState(() => _selected = atlas.room(_place?.label ?? ''));
        if (!widget.initialOverview) {
          _camera.show(
            _selected?.bounds ??
                (_place == null
                    ? null
                    : atlas.wingBounds(_floor, _place!.wing)),
          );
        }
      },
      onError: (Object error, StackTrace stack) {
        FlutterError.reportError(
          FlutterErrorDetails(exception: error, stack: stack, library: '文萃地图'),
        );
      },
    );
  }

  @override
  void dispose() {
    _search.dispose();
    _camera.dispose();
    super.dispose();
  }

  List<({Course course, WencuiPlace place})> get _courses {
    final seen = <String>{};
    return [
      for (final course in widget.timetable.schedule?.courses ?? <Course>[])
        if (WencuiPlace.parse(course.room, campus: course.campus)
            case final place?)
          if (seen.add('${course.name}\u0000${place.label}'))
            (course: course, place: place),
    ]..sort((a, b) {
      final day = (a.course.weekday ?? 8).compareTo(b.course.weekday ?? 8);
      return day != 0
          ? day
          : (a.course.startSection ?? 14).compareTo(
              b.course.startSection ?? 14,
            );
    });
  }

  void _selectPlace(WencuiPlace place, WencuiAtlas atlas, {Course? course}) {
    if (_search.isOpen) _search.closeView('');
    setState(() {
      _place = place;
      _course = course;
      _selected = atlas.room(place.label);
      _floor =
          place.floor ??
          (place.wing.hasFloor(_floor) ? _floor : place.wing.firstFloor);
      _facilities.clear();
    });
    _camera.show(_selected?.bounds ?? atlas.wingBounds(_floor, place.wing));
  }

  void _selectFeature(WencuiFeature feature) => setState(() {
    _selected = feature;
    _floor = feature.floor;
    if (feature.kind == WencuiFeatureKind.room) {
      _place = WencuiPlace.parse(feature.label);
      _course = _courses
          .where((item) => item.place.label == feature.label)
          .firstOrNull
          ?.course;
    }
    // A map tap selects without moving the camera. Inspecting facilities keeps
    // the destination so the user can return directly to the classroom.
  });

  void _changeFloor(int floor, WencuiAtlas atlas) {
    final wing = _wing;
    setState(() {
      _floor = floor;
      _selected = _place?.floor == floor ? atlas.room(_place!.label) : null;
    });
    _camera.show(wing == null ? null : atlas.wingBounds(floor, wing));
  }

  void _returnToRoom(WencuiAtlas atlas) {
    final place = _place!;
    setState(() {
      _floor = place.floor ?? place.wing.firstFloor;
      _selected = atlas.room(place.label);
    });
    _camera.show(_selected?.bounds ?? atlas.wingBounds(_floor, place.wing));
  }

  void _toggleFacility(WencuiFeatureKind kind, WencuiAtlas atlas) {
    final enabled = !_facilities.contains(kind);
    setState(() {
      if (enabled) {
        _facilities.add(kind);
      } else {
        _facilities.remove(kind);
        if (_selected?.kind == kind) _selected = null;
      }
    });
    if (enabled) {
      _camera.show(_wing == null ? null : atlas.wingBounds(_floor, _wing!));
    }
  }

  void _showCourses(WencuiAtlas atlas) => showAppSheet<void>(
    context: context,
    builder: (sheetContext) {
      final l10n = sheetContext.l10n;
      return SheetLayout(
        header: SheetHeader(
          title: Text(l10n.myWencuiCourses),
          actions: const [SheetCloseButton()],
        ),
        contentPadding: appSheetListPadding,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (:course, :place) in _courses)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(sheetContext)
                      .colorScheme
                      .primaryContainer,
                  child: Text(place.wing.letter),
                ),
                title: Text(course.name),
                subtitle: Text(
                  [
                    localizedWencuiPlace(l10n, place),
                    if (course.weekday case final weekday?)
                      localizedShortWeekday(l10n, weekday),
                    localizedCourseSection(l10n, course),
                  ].join(' · '),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _selectPlace(place, atlas, course: course);
                },
              ),
          ],
        ),
      );
    },
  );

  Iterable<Widget> _suggestions(WencuiAtlas atlas, SearchController search) {
    final l10n = context.l10n;
    final query = normalizeCampusLocation(search.text);
    final place = WencuiPlace.parse(search.text);
    final results = <Widget>[
      if (place != null)
        ListTile(
          leading: const Icon(Icons.location_on_outlined),
          title: Text(localizedWencuiPlace(l10n, place)),
          subtitle: Text(
            [
              place.floor == null
                  ? localizedWencuiWingFloorRange(l10n, place.wing)
                  : localizedWencuiWingFloor(l10n, place.wing, place.floor!),
              if (place.room != null && atlas.room(place.label) == null)
                l10n.viewBuildingBounds,
            ].join(' · '),
          ),
          onTap: () => _selectPlace(place, atlas),
        ),
      for (final (:course, :place) in _courses)
        if (query.isEmpty ||
            normalizeCampusLocation('${course.name}${course.room}')
                .contains(query))
          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: Text(course.name),
            subtitle: Text(
              '${localizedWencuiPlace(l10n, place)} · '
              '${localizedCourseSection(l10n, course)}',
            ),
            onTap: () => _selectPlace(place, atlas, course: course),
          ),
      if (query.isNotEmpty)
        for (final feature in atlas.onFloor(_floor))
          if (feature.kind != WencuiFeatureKind.room &&
              normalizeCampusLocation(
                '${feature.title} '
                '${localizedWencuiFeatureTitle(l10n, feature)} $_floor层',
              ).contains(query))
            ListTile(
              leading: Icon(
                wencuiFeatureIcon(
                  feature.kind,
                  restroomGender: feature.restroomGender,
                ),
              ),
              title: Text(localizedWencuiFeatureLabel(l10n, feature)),
              subtitle: Text(l10n.currentFloor(_floor)),
              onTap: () {
                _search.closeView('');
                _facilities.add(feature.kind);
                _selectFeature(feature);
                _camera.show(feature.bounds);
              },
            ),
      for (final wing in WencuiWing.values)
        if (place?.wing != wing &&
            (query.isEmpty ||
                normalizeCampusLocation('文萃楼${wing.letter}栋').contains(query)))
          ListTile(
            leading: const Icon(Icons.apartment_rounded),
            title: Text(localizedWencuiWing(l10n, wing)),
            subtitle: Text(localizedWencuiWingFloorRange(l10n, wing)),
            onTap: () => _selectPlace(WencuiPlace(wing), atlas),
          ),
    ];
    return results.isEmpty
        ? [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l10n.noMapResults),
            ),
          ]
        : results;
  }

  Widget _searchBar(bool narrow, WencuiAtlas atlas) => WencuiMapSearchBar(
    searchController: _search,
    narrow: narrow,
    hasCourses: _courses.isNotEmpty,
    onSubmitted: (query) {
      final place = WencuiPlace.parse(query);
      if (place != null) _selectPlace(place, atlas);
    },
    suggestionsBuilder: (search) => _suggestions(atlas, search),
    onShowCourses: () => _showCourses(atlas),
  );

  Widget _floorControl(WencuiAtlas atlas) => WencuiMapFloorControl(
    currentFloor: _floor,
    menuController: _floorMenu,
    onFloorChanged: (floor) => _changeFloor(floor, atlas),
  );

  Widget _details(WencuiAtlas atlas) {
    final place = _place;
    return WencuiMapDetails(
      place: place,
      selected: _selected,
      course: _course,
      floor: _floor,
      facilities: _facilities,
      roomIsMarked:
          place == null ||
          place.room == null ||
          atlas.room(place.label) != null,
      onClear: () {
        setState(() {
          _place = null;
          _selected = null;
          _course = null;
          _facilities.clear();
        });
        _camera.show(null);
      },
      onToggleFacility: (kind) => _toggleFacility(kind, atlas),
      onEntrance: () {
        setState(() {
          _floor = 1;
          _selected = null;
          _facilities.add(WencuiFeatureKind.entrance);
        });
        _camera.show(atlas.wingBounds(1, place!.wing));
      },
      onReturnToRoom: () => _returnToRoom(atlas),
    );
  }

  Widget _content(WencuiAtlas atlas) => LayoutBuilder(
    builder: (context, constraints) {
      final narrow = constraints.maxWidth < 760;
      final details = Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: _details(atlas),
        ),
      );
      final map = Stack(
        children: [
          Positioned.fill(
            child: WencuiFloorMap(
              floor: _floor,
              atlas: atlas,
              controller: _camera,
              selected: _selected?.floor == _floor ? _selected : null,
              wing: _wing,
              facilities: Set.of(_facilities),
              onSelected: _selectFeature,
              onWingSelected: (wing) => _selectPlace(WencuiPlace(wing), atlas),
            ),
          ),
          Positioned(right: 12, top: 8, child: _floorControl(atlas)),
        ],
      );
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: _searchBar(narrow, atlas),
          ),
          Expanded(
            child: narrow
                ? Column(
                    children: [
                      Expanded(child: map),
                      const Divider(height: 1),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: math.min(250, constraints.maxHeight * .34),
                        ),
                        child: details,
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 300, child: details),
                      const VerticalDivider(width: 1),
                      Expanded(child: map),
                    ],
                  ),
          ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) => AppRoutePage(
    title: context.l10n.wencuiMap,
    actions: [
      IconButton(
        tooltip: context.l10n.mapInfoTitle,
        onPressed: () => showWencuiMapInfo(context),
        icon: const Icon(Icons.info_outline_rounded),
      ),
    ],
    child: ListenableBuilder(
      listenable: widget.timetable,
      builder: (_, _) => FutureBuilder<WencuiAtlas>(
        future: _loading,
        builder: (context, snapshot) => snapshot.hasData
            ? _content(snapshot.requireData)
            : snapshot.hasError
            ? Center(child: Text(context.l10n.mapLoadFailed))
            : const Center(child: CircularProgressIndicator()),
      ),
    ),
  );
}
