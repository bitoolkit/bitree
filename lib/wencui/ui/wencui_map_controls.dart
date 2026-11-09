import 'package:flutter/material.dart';

import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../schedule/model.dart';
import '../../ui/app_dialog.dart';
import '../../ui/app_menu_anchor.dart';
import '../../ui/design.dart';
import '../../ui/external_link.dart';
import '../../ui/selection_controls.dart';
import '../atlas.dart';
import '../place.dart';
import 'floor_map.dart';

void showWencuiMapInfo(BuildContext context) => showAppDialog<void>(
  context: context,
  builder: (dialogContext) {
    final l10n = dialogContext.l10n;
    return AlertDialog(
      scrollable: true,
      title: Text(l10n.mapInfoTitle),
      content: Text(l10n.mapInfoBody),
      actions: [
        TextButton(
          onPressed: () => openExternalLink(
            dialogContext,
            Uri.parse(
              'https://github.com/Zebedee2021/BIT-Nav-2026/tree/main/wencui',
            ),
            failureTitle: l10n.openMapSourceFailed,
          ),
          child: Text(l10n.mapSource),
        ),
        TextButton(
          onPressed: () => openExternalLink(
            dialogContext,
            Uri.parse(
              'https://wencuigis.info.bit.edu.cn/3dbuilding/#/building2',
            ),
            failureTitle: l10n.openSchoolNavigationFailed,
          ),
          child: Text(l10n.school3dNavigation),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(l10n.close),
        ),
      ],
    );
  },
);

class WencuiMapSearchBar extends StatelessWidget {
  const WencuiMapSearchBar({
    super.key,
    required this.searchController,
    required this.narrow,
    required this.hasCourses,
    required this.onSubmitted,
    required this.suggestionsBuilder,
    required this.onShowCourses,
  });

  final SearchController searchController;
  final bool narrow;
  final bool hasCourses;
  final ValueChanged<String> onSubmitted;
  final Iterable<Widget> Function(SearchController) suggestionsBuilder;
  final VoidCallback onShowCourses;

  @override
  Widget build(BuildContext context) => SearchAnchor(
    searchController: searchController,
    isFullScreen: narrow,
    viewShape: narrow ? const RoundedRectangleBorder() : null,
    viewHintText: context.l10n.wencuiCourseSearchHint,
    viewOnSubmitted: onSubmitted,
    suggestionsBuilder: (_, search) => suggestionsBuilder(search),
    builder: (_, controller) => SearchBar(
      readOnly: true,
      hintText: context.l10n.wencuiSearchHint,
      onTap: controller.openView,
      leading: const Icon(Icons.search_rounded),
      trailing: [
        if (hasCourses)
          IconButton(
            tooltip: context.l10n.myWencuiCourses,
            onPressed: onShowCourses,
            icon: const Icon(Icons.school_outlined),
          ),
      ],
    ),
  );
}

class WencuiMapFloorControl extends StatelessWidget {
  const WencuiMapFloorControl({
    super.key,
    required this.currentFloor,
    required this.menuController,
    required this.onFloorChanged,
  });

  final int currentFloor;
  final MenuController menuController;
  final ValueChanged<int> onFloorChanged;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    elevation: 1,
    borderRadius: AppCorners.control,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: context.l10n.upperFloor,
          onPressed: currentFloor == 10
              ? null
              : () => onFloorChanged(currentFloor + 1),
          icon: const Icon(Icons.keyboard_arrow_up_rounded),
        ),
        AppMenuAnchor(
          controller: menuController,
          menuChildren: [
            SizedBox(
              width: 240,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var row = 0; row < 2; row++)
                    Row(
                      children: [
                        for (var column = 1; column <= 5; column++)
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                backgroundColor:
                                    row * 5 + column == currentFloor
                                    ? Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                    : null,
                              ),
                              onPressed: () {
                                menuController.close();
                                onFloorChanged(row * 5 + column);
                              },
                              child: Text('${row * 5 + column}'),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
          builder: (context, menu, isOpen) => TextButton(
            onPressed: () => isOpen ? menu.close() : menu.open(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(
              context.l10n.currentFloor(currentFloor),
              semanticsLabel: context.l10n.selectFloorSemantics(currentFloor),
            ),
          ),
        ),
        IconButton(
          tooltip: context.l10n.lowerFloor,
          onPressed: currentFloor == 1
              ? null
              : () => onFloorChanged(currentFloor - 1),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
        ),
      ],
    ),
  );
}

class WencuiMapDetails extends StatelessWidget {
  const WencuiMapDetails({
    super.key,
    required this.place,
    required this.selected,
    required this.course,
    required this.floor,
    required this.facilities,
    required this.roomIsMarked,
    required this.onClear,
    required this.onToggleFacility,
    required this.onEntrance,
    required this.onReturnToRoom,
  });

  final WencuiPlace? place;
  final WencuiFeature? selected;
  final Course? course;
  final int floor;
  final Set<WencuiFeatureKind> facilities;
  final bool roomIsMarked;
  final VoidCallback onClear;
  final ValueChanged<WencuiFeatureKind> onToggleFacility;
  final VoidCallback onEntrance;
  final VoidCallback onReturnToRoom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place == null
                        ? selected == null
                              ? l10n.tapBuildingOrSearch
                              : localizedWencuiFeatureLabel(l10n, selected!)
                        : localizedWencuiPlace(l10n, place!),
                    style: theme.textTheme.titleLarge,
                  ),
                  if (course != null) ...[
                    const SizedBox(height: 3),
                    Text(course!.name, style: theme.textTheme.bodyMedium),
                  ],
                  if (place != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      _placeDetails(l10n, place!),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            if (place != null || selected != null)
              IconButton(
                tooltip: l10n.clearDestination,
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              ),
          ],
        ),
        if (place?.room != null && !roomIsMarked) ...[
          const SizedBox(height: 6),
          Text(
            l10n.roomNotMarked(
              place!.label,
              localizedWencuiWing(l10n, place!.wing),
            ),
            style: theme.textTheme.bodySmall,
          ),
        ],
        if (selected != null && selected!.kind != WencuiFeatureKind.room) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                wencuiFeatureIcon(
                  selected!.kind,
                  restroomGender: selected!.restroomGender,
                ),
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.selectedFeature(
                    localizedWencuiFeatureTitle(l10n, selected!),
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final (kind, label) in [
              (WencuiFeatureKind.stairs, l10n.stairs),
              (WencuiFeatureKind.lift, l10n.lift),
              (WencuiFeatureKind.restroom, l10n.restroom),
            ])
              AppSelectionButton.compact(
                selected: facilities.contains(kind),
                onPressed: () => onToggleFacility(kind),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: AppSpacing.xs,
                  children: [
                    Icon(wencuiFeatureIcon(kind), size: 18),
                    Text(label),
                  ],
                ),
              ),
            if (place?.wing.firstFloor == 1)
              TextButton.icon(
                onPressed: onEntrance,
                icon: const Icon(Icons.door_front_door_outlined, size: 18),
                label: Text(l10n.firstFloorEntrance),
              ),
            if (place != null)
              TextButton.icon(
                onPressed: onReturnToRoom,
                icon: const Icon(Icons.my_location_rounded, size: 18),
                label: Text(
                  place!.room == null ? l10n.backToBuilding : l10n.backToRoom,
                ),
              ),
          ],
        ),
      ],
    );
  }

  String _placeDetails(AppLocalizations l10n, WencuiPlace place) {
    final details = place.floor == null
        ? localizedWencuiWingFloorRange(l10n, place.wing)
        : localizedWencuiWingFloor(l10n, place.wing, place.floor!);
    if (place.floor == null || floor == place.floor) return details;
    return l10n.viewingFloor(details, floor);
  }
}
