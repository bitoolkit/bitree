import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../ui/design.dart';
import '../atlas.dart';
import '../place.dart';
import 'floor_image.dart';

/// Camera requests remain separate from selecting an object on the map.
class WencuiMapController extends ChangeNotifier {
  Rect? _focus;

  void show(Rect? bounds) {
    _focus = bounds;
    notifyListeners();
  }
}

IconData wencuiFeatureIcon(WencuiFeatureKind kind) => switch (kind) {
  WencuiFeatureKind.room => Icons.meeting_room_outlined,
  WencuiFeatureKind.stairs => Icons.stairs_outlined,
  WencuiFeatureKind.lift => Icons.elevator_outlined,
  WencuiFeatureKind.entrance => Icons.door_front_door_outlined,
  WencuiFeatureKind.restroom => Icons.wc_rounded,
};

class WencuiFloorMap extends StatefulWidget {
  const WencuiFloorMap({
    super.key,
    required this.floor,
    required this.atlas,
    required this.controller,
    required this.selected,
    required this.wing,
    required this.onSelected,
    required this.onWingSelected,
    required this.facilities,
  });
  final int floor;
  final WencuiAtlas atlas;
  final WencuiMapController controller;
  final WencuiFeature? selected;
  final WencuiWing? wing;
  final ValueChanged<WencuiFeature> onSelected;
  final ValueChanged<WencuiWing> onWingSelected;
  final Set<WencuiFeatureKind> facilities;
  @override
  State<WencuiFloorMap> createState() => _WencuiFloorMapState();
}

class _WencuiFloorMapState extends State<WencuiFloorMap>
    with SingleTickerProviderStateMixin {
  final _transform = TransformationController();
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  Animation<Matrix4>? _matrix;
  Size? _viewport;
  int? _shownFloor;
  bool _fitScheduled = false;
  WencuiFeature? _hover;
  static const _imageSize = wencuiFloorSize;

  List<WencuiFeature> get _features => widget.atlas.onFloor(widget.floor);
  List<WencuiFeature> get _facilities => [
    for (final feature in _features)
      if (widget.facilities.contains(feature.kind)) feature,
  ];

  bool get _overview =>
      _viewport != null &&
      _transform.value.getMaxScaleOnAxis() <=
          math.min(
                _viewport!.width / _imageSize.width,
                _viewport!.height / _imageSize.height,
              ) *
              2;

  WencuiWing? _wingAt(Offset position) {
    final point = Offset(
      position.dx / _imageSize.width,
      position.dy / _imageSize.height,
    );
    final candidates =
        [
          for (final wing in WencuiWing.values)
            if (wing.hasFloor(widget.floor))
              if (widget.atlas.wingBounds(widget.floor, wing)
                  case final bounds?)
                if (bounds.contains(point) ||
                    (Offset(
                                      bounds.center.dx * _imageSize.width,
                                      bounds.center.dy * _imageSize.height,
                                    ) -
                                    position)
                                .distance *
                            _transform.value.getMaxScaleOnAxis() <=
                        22)
                  (wing: wing, bounds: bounds),
        ]..sort((a, b) {
          double distance(Rect bounds) =>
              (Offset(
                        bounds.center.dx * _imageSize.width,
                        bounds.center.dy * _imageSize.height,
                      ) -
                      position)
                  .distanceSquared;
          return distance(a.bounds).compareTo(distance(b.bounds));
        });
    return candidates.firstOrNull?.wing;
  }

  @override
  void initState() {
    super.initState();
    _animation.addListener(() => _transform.value = _matrix!.value);
    widget.controller.addListener(_scheduleFit);
  }

  @override
  void didUpdateWidget(WencuiFloorMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_scheduleFit);
      widget.controller.addListener(_scheduleFit);
      _scheduleFit();
    }
    if (oldWidget.floor != widget.floor) _hover = null;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_scheduleFit);
    _animation.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _scheduleFit({bool animate = true}) {
    if (_fitScheduled) return;
    _fitScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitScheduled = false;
      if (mounted && _viewport != null) _fit(animate: animate);
    });
  }

  void _move(Matrix4 matrix, {bool animate = true}) {
    _animation.stop();
    if (!animate || MediaQuery.disableAnimationsOf(context)) {
      _transform.value = matrix;
      return;
    }
    _matrix = Matrix4Tween(
      begin: _transform.value,
      end: matrix,
    ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(_animation);
    _animation.forward(from: 0);
  }

  void _fit({bool whole = false, bool animate = true}) {
    final viewport = _viewport!;
    final bounds = whole ? null : widget.controller._focus;
    final rect = bounds == null
        ? Offset.zero & _imageSize
        : Rect.fromLTRB(
            bounds.left * _imageSize.width,
            bounds.top * _imageSize.height,
            bounds.right * _imageSize.width,
            bounds.bottom * _imageSize.height,
          ).inflate(52);
    final scale =
        (math.min(viewport.width / rect.width, viewport.height / rect.height) *
                .93)
            .clamp(.05, 8.0);
    _move(
      Matrix4.identity()
        ..translateByDouble(
          viewport.width / 2 - rect.center.dx * scale,
          viewport.height / 2 - rect.center.dy * scale,
          0,
          1,
        )
        ..scaleByDouble(scale, scale, scale, 1),
      animate: animate,
    );
  }

  void _zoom(double factor) {
    final center = _viewport!.center(Offset.zero);
    final scene = _transform.toScene(center);
    final scale = (_transform.value.getMaxScaleOnAxis() * factor).clamp(
      .05,
      8.0,
    );
    _move(
      Matrix4.identity()
        ..translateByDouble(
          center.dx - scene.dx * scale,
          center.dy - scene.dy * scale,
          0,
          1,
        )
        ..scaleByDouble(scale, scale, scale, 1),
    );
  }

  WencuiFeature? _featureAt(Offset position) {
    final point = Offset(
      position.dx / _imageSize.width,
      position.dy / _imageSize.height,
    );
    final scale = _transform.value.getMaxScaleOnAxis();
    final markers =
        _facilities
            .where(
              (feature) =>
                  (Offset(
                                feature.anchor.dx * _imageSize.width,
                                feature.anchor.dy * _imageSize.height,
                              ) -
                              position)
                          .distance *
                      scale <=
                  22,
            )
            .toList()
          ..sort((a, b) {
            double distance(WencuiFeature feature) =>
                (Offset(
                          feature.anchor.dx * _imageSize.width,
                          feature.anchor.dy * _imageSize.height,
                        ) -
                        position)
                    .distanceSquared;
            return distance(a).compareTo(distance(b));
          });
    if (markers.isNotEmpty) return markers.first;
    return _features
        .where(
          (feature) =>
              (feature.kind == WencuiFeatureKind.room ||
                  widget.facilities.contains(feature.kind)) &&
              feature.path.contains(point),
        )
        .firstOrNull;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final l10n = context.l10n;
      final viewport = constraints.biggest;
      if (viewport != _viewport || widget.floor != _shownFloor) {
        final previousViewport = _viewport;
        final changedFloor = widget.floor != _shownFloor;
        _viewport = viewport;
        _shownFloor = widget.floor;
        if (previousViewport == null || changedFloor) {
          _scheduleFit(animate: previousViewport != null);
        } else if (!_fitScheduled) {
          final shift =
              viewport.center(Offset.zero) -
              previousViewport.center(Offset.zero);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _move(
                Matrix4.translationValues(shift.dx, shift.dy, 0)
                  ..multiply(_transform.value),
                animate: false,
              );
            }
          });
        }
      }
      final scheme = Theme.of(context).colorScheme;
      return ClipRect(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _transform,
                constrained: false,
                minScale: .05,
                maxScale: 8,
                boundaryMargin: const EdgeInsets.all(double.infinity),
                onInteractionStart: (_) => _animation.stop(),
                child: MouseRegion(
                  cursor: _hover == null
                      ? SystemMouseCursors.grab
                      : SystemMouseCursors.click,
                  onHover: (event) {
                    final feature = _featureAt(event.localPosition);
                    if (feature != _hover) setState(() => _hover = feature);
                  },
                  onExit: (_) => setState(() => _hover = null),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) {
                      if (_overview) {
                        final wing = _wingAt(details.localPosition);
                        if (wing != null) {
                          widget.onWingSelected(wing);
                          return;
                        }
                      }
                      final feature = _featureAt(details.localPosition);
                      if (feature != null) widget.onSelected(feature);
                    },
                    child: SizedBox(
                      width: _imageSize.width,
                      height: _imageSize.height,
                      child: AnimatedBuilder(
                        animation: _transform,
                        builder: (context, _) => CustomPaint(
                          foregroundPainter: _MapFeatures(
                            features: _features,
                            selected: widget.selected,
                            hover: _hover,
                            scale: _transform.value.getMaxScaleOnAxis(),
                            accent: scheme.primary,
                            surface: scheme.surfaceContainerLowest,
                            foreground: scheme.onSurface,
                            facilities: widget.facilities,
                            onSelected: widget.onSelected,
                            l10n: l10n,
                          ),
                          child: WencuiFloorImage(floor: widget.floor),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _transform,
                builder: (context, _) {
                  if (!_overview) {
                    return const SizedBox.shrink();
                  }
                  return Stack(
                    children: [
                      for (final wing in WencuiWing.values)
                        if (wing.hasFloor(widget.floor))
                          if (widget.atlas.wingLabelPosition(widget.floor, wing)
                              case final position?)
                            _wingButton(wing, position, viewport),
                    ],
                  );
                },
              ),
            ),
            Positioned(
              left: 12,
              top: 8,
              child: Material(
                color: scheme.surfaceContainerLow,
                borderRadius: AppCorners.compact,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Text(l10n.mapLegend),
                ),
              ),
            ),
            if (_hover != null)
              Positioned(
                right: 12,
                top: 8,
                child: Material(
                  color: scheme.surfaceContainerLow,
                  borderRadius: AppCorners.compact,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(localizedWencuiFeatureTitle(l10n, _hover!)),
                  ),
                ),
              ),
            Positioned(
              right: 12,
              bottom: 12,
              child: Material(
                color: scheme.surfaceContainerLow,
                borderRadius: AppCorners.control,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: l10n.zoomOut,
                      onPressed: () => _zoom(1 / 1.5),
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    IconButton(
                      tooltip: l10n.zoomIn,
                      onPressed: () => _zoom(1.5),
                      icon: const Icon(Icons.add_rounded),
                    ),
                    IconButton(
                      tooltip: l10n.fitFloor,
                      onPressed: () => _fit(whole: true),
                      icon: const Icon(Icons.fit_screen_rounded),
                    ),
                    if (widget.controller._focus != null)
                      IconButton(
                        tooltip: l10n.returnToSelection,
                        onPressed: _fit,
                        icon: const Icon(Icons.my_location_rounded),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _wingButton(WencuiWing wing, Offset position, Size viewport) {
    final l10n = context.l10n;
    final center = MatrixUtils.transformPoint(
      _transform.value,
      Offset(position.dx * _imageSize.width, position.dy * _imageSize.height),
    );
    if (!(Offset.zero & viewport).contains(center)) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      left: (center.dx - 14).clamp(0, viewport.width - 28),
      top: (center.dy - 14).clamp(0, viewport.height - 28),
      width: 28,
      height: 28,
      child: Semantics(
        key: ValueKey('wencui-wing-${wing.letter}'),
        label: l10n.enlargeWing(localizedWencuiWing(l10n, wing)),
        button: true,
        onTap: () => widget.onWingSelected(wing),
        child: Material(
          color: widget.wing == wing
              ? scheme.primaryContainer
              : scheme.surfaceContainerLowest,
          elevation: 1,
          borderRadius: AppCorners.compact,
          child: InkWell(
            onTap: () => widget.onWingSelected(wing),
            borderRadius: AppCorners.compact,
            child: Center(
              child: Text(
                wing.letter,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapFeatures extends CustomPainter {
  _MapFeatures({
    required this.features,
    required this.selected,
    required this.hover,
    required this.scale,
    required this.accent,
    required this.surface,
    required this.foreground,
    required this.facilities,
    required this.onSelected,
    required this.l10n,
  });
  final List<WencuiFeature> features;
  final WencuiFeature? selected;
  final WencuiFeature? hover;
  final double scale;
  final Color accent;
  final Color surface;
  final Color foreground;
  final Set<WencuiFeatureKind> facilities;
  final ValueChanged<WencuiFeature> onSelected;
  final AppLocalizations l10n;

  @override
  void paint(Canvas canvas, Size size) {
    for (final feature in features) {
      final path = feature.path.transform(
        Matrix4.diagonal3Values(size.width, size.height, 1).storage,
      );
      if (feature == selected || feature == hover) {
        canvas.drawPath(
          path,
          Paint()
            ..color = accent.withValues(alpha: feature == selected ? .25 : .12),
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5 / scale,
        );
      }
      if (facilities.contains(feature.kind)) {
        final point = Offset(
          feature.anchor.dx * size.width,
          feature.anchor.dy * size.height,
        );
        final radius = 13 / scale;
        canvas.drawCircle(point, radius, Paint()..color = surface);
        canvas.drawCircle(
          point,
          radius,
          Paint()
            ..color = accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5 / scale,
        );
        final icon = wencuiFeatureIcon(feature.kind);
        final text = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(icon.codePoint),
            style: TextStyle(
              fontFamily: icon.fontFamily,
              fontSize: 16 / scale,
              color: foreground,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(canvas, point - Offset(text.width / 2, text.height / 2));
        text.dispose();
      }
    }
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder =>
      (size) => [
        for (final feature in features)
          if (feature.kind == WencuiFeatureKind.room ||
              facilities.contains(feature.kind))
            CustomPainterSemantics(
              rect: (feature.kind == WencuiFeatureKind.room
                  ? Rect.fromLTRB(
                      feature.bounds.left * size.width,
                      feature.bounds.top * size.height,
                      feature.bounds.right * size.width,
                      feature.bounds.bottom * size.height,
                    )
                  : Rect.fromCenter(
                      center: Offset(
                        feature.anchor.dx * size.width,
                        feature.anchor.dy * size.height,
                      ),
                      width: 44 / scale,
                      height: 44 / scale,
                    )),
              properties: SemanticsProperties(
                label: l10n.featureSemantics(
                  localizedWencuiFeatureLabel(l10n, feature),
                  feature.floor,
                ),
                button: true,
                selected: feature == selected,
                textDirection: TextDirection.ltr,
                onTap: () => onSelected(feature),
              ),
            ),
      ];
  @override
  bool shouldRepaint(_MapFeatures old) =>
      old.features != features ||
      old.selected != selected ||
      old.hover != hover ||
      old.scale != scale ||
      old.accent != accent ||
      old.surface != surface ||
      old.foreground != foreground ||
      old.l10n != l10n ||
      !setEquals(old.facilities, facilities);
  @override
  bool shouldRebuildSemantics(_MapFeatures old) =>
      old.features != features ||
      old.selected != selected ||
      old.scale != scale ||
      old.l10n != l10n ||
      !setEquals(old.facilities, facilities);
}
