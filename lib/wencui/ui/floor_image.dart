import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

const wencuiFloorSize = Size(1500, 1000);

/// The source plans all share this aspect ratio and normalized coordinates.
class WencuiFloorImage extends StatelessWidget {
  const WencuiFloorImage({super.key, required this.floor});

  final int floor;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/wencui/$floor.jpg',
      fit: BoxFit.contain,
      width: wencuiFloorSize.width,
      height: wencuiFloorSize.height,
      semanticLabel: context.l10n.floorPlanSemantics(floor),
    );
    if (Theme.of(context).brightness == Brightness.light) return image;
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        -.75,
        0,
        0,
        0,
        220,
        0,
        -.75,
        0,
        0,
        220,
        0,
        0,
        -.75,
        0,
        220,
        0,
        0,
        0,
        1,
        0,
      ]),
      child: image,
    );
  }
}
