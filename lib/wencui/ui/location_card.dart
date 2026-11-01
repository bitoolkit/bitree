import 'package:flutter/material.dart';

import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../ui/design.dart';
import '../atlas.dart';
import '../place.dart';
import 'floor_image.dart';

/// A room's location and map entry form a single action in course details.
class WencuiLocationCard extends StatelessWidget {
  const WencuiLocationCard({
    super.key,
    required this.place,
    required this.onTap,
  });

  final WencuiPlace place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final floor = place.floor ?? place.wing.firstFloor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: AppCorners.control,
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                SizedBox(
                  width: 114,
                  height: 76,
                  child: ExcludeSemantics(
                    child: ClipRRect(
                      borderRadius: AppCorners.compact,
                      child: FutureBuilder<WencuiAtlas>(
                        future: WencuiAtlas.load(),
                        builder: (context, snapshot) {
                          final room = snapshot.data?.room(place.label);
                          final bounds =
                              room?.bounds ??
                              snapshot.data?.wingBounds(floor, place.wing);
                          return _RoomPreview(
                            floor: floor,
                            bounds: bounds,
                            room: room,
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.wencuiLocation(place.label),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        localizedWencuiWingFloor(l10n, place.wing, floor),
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 7),
                      Text(
                        l10n.viewClassroomLocation,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoomPreview extends StatelessWidget {
  const _RoomPreview({required this.floor, this.bounds, this.room});

  final int floor;
  final Rect? bounds;
  final WencuiFeature? room;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: wencuiFloorSize.aspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          return Stack(
            fit: StackFit.expand,
            children: [
              FittedBox(
                fit: BoxFit.contain,
                child: SizedBox.fromSize(
                  size: wencuiFloorSize,
                  child: WencuiFloorImage(floor: floor),
                ),
              ),
              if (bounds case final target?)
                Positioned.fromRect(
                  rect: Rect.fromLTRB(
                    target.left * size.width,
                    target.top * size.height,
                    target.right * size.width,
                    target.bottom * size.height,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: .25),
                      border: Border.all(color: scheme.primary),
                    ),
                  ),
                ),
              if (room case final target?)
                Positioned.fromRect(
                  rect: Rect.fromCenter(
                    center: Offset(
                      target.anchor.dx * size.width,
                      target.anchor.dy * size.height,
                    ),
                    width: 10,
                    height: 10,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.primary,
                      border: Border.all(color: scheme.surface, width: 2),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
