import 'dart:convert';
import 'dart:ui';

import 'package:flutter/services.dart';

import 'place.dart';

enum WencuiFeatureKind { room, stairs, lift, entrance, restroom }

enum WencuiRestroomGender { male, female, both }

class WencuiFeature {
  WencuiFeature({
    required this.floor,
    required this.label,
    required this.kind,
    required this.wing,
    required this.anchor,
    required this.outline,
    this.restroomGender,
  });

  final int floor;
  final String label;
  final WencuiFeatureKind kind;
  final WencuiWing? wing;
  final Offset anchor;
  final List<Offset> outline;
  final WencuiRestroomGender? restroomGender;

  String get title => kind == WencuiFeatureKind.room
      ? label
      : '${wing == null ? '$floor层' : wing!.name} $label';

  late final bounds = outline.fold<Rect>(
    Rect.fromPoints(outline.first, outline.first),
    (rect, point) => rect.expandToInclude(Rect.fromPoints(point, point)),
  );

  late final path = Path()..addPolygon(outline, true);
}

class WencuiAtlas {
  WencuiAtlas._(this.features);
  final List<WencuiFeature> features;

  // One immutable offline index, shared by every entry into the map.
  static final Future<WencuiAtlas> _loaded = _read();
  static Future<WencuiAtlas> load() => _loaded;

  static Future<WencuiAtlas> _read() async {
    final rows = jsonDecode(
      await rootBundle.loadString('assets/wencui/places.json'),
    ) as List;
    return WencuiAtlas._([
      for (final row in rows.cast<Map<String, dynamic>>())
        WencuiFeature(
          floor: row['floor'] as int,
          label: row['label'] as String,
          kind: WencuiFeatureKind.values.byName(row['kind'] as String),
          restroomGender: row['restroomGender'] == null
              ? null
              : WencuiRestroomGender.values.byName(
                  row['restroomGender'] as String,
                ),
          wing: row['wing'] == null
              ? null
              : WencuiWing.values.firstWhere(
                  (wing) => wing.letter == row['wing'],
                ),
          anchor: Offset(
            (row['anchor'][0] as num).toDouble(),
            (row['anchor'][1] as num).toDouble(),
          ),
          outline: [
            for (final point in row['outline'] as List)
              Offset(
                (point[0] as num).toDouble(),
                (point[1] as num).toDouble(),
              ),
          ],
        ),
    ]);
  }

  WencuiFeature? room(String label) => features
      .where(
        (feature) =>
            feature.kind == WencuiFeatureKind.room && feature.label == label,
      )
      .firstOrNull;

  List<WencuiFeature> onFloor(int floor) => [
    for (final feature in features)
      if (feature.floor == floor) feature,
  ];

  Rect? _wingMemberBounds(int floor, WencuiWing wing) {
    final members = features.where(
      (feature) => feature.floor == floor && feature.wing == wing,
    );
    if (members.isEmpty) return null;
    return members
        .map((feature) => feature.bounds)
        .reduce((a, b) => a.expandToInclude(b));
  }

  Offset? wingLabelPosition(int floor, WencuiWing wing) {
    final bounds = _wingMemberBounds(floor, wing);
    if (bounds == null) return null;
    // Each L-shaped wing bends near its corresponding corner. Keep the label
    // inside the wing's own extent, before nearby stairs/lifts expand the view.
    final inset = bounds.deflate(.04);
    return switch (wing) {
      WencuiWing.m => inset.topRight,
      WencuiWing.b => inset.topLeft,
      WencuiWing.g => inset.bottomLeft,
      WencuiWing.h => inset.bottomRight,
      _ => wingBounds(floor, wing)?.center,
    };
  }

  Rect? wingBounds(int floor, WencuiWing wing) {
    final bounds = _wingMemberBounds(floor, wing);
    if (bounds == null) return null;
    // Include surrounding stairs/lifts in the view, without implying a route
    // across a wall or a connection between wings.
    return features
        .where(
          (feature) =>
              feature.floor == floor &&
              (feature.kind == WencuiFeatureKind.stairs ||
                  feature.kind == WencuiFeatureKind.lift) &&
              bounds.inflate(.10).contains(feature.anchor),
        )
        .fold<Rect>(
          bounds,
          (rect, feature) => rect.expandToInclude(feature.bounds),
        );
  }
}
